-- This is a Confluence Storage Format custom writer for pandoc.
-- It produces output that is very similar to that of pandoc's HTML writer.
--
-- Invoke with: pandoc -t csf.lua
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua sample.lua' will
-- produce informative error messages if your code contains
-- syntax errors.


--- Character escaping ---

local function escape(s, in_attribute)
	return s:gsub("[<>&\"']",
		function(x)
			if x == '<' then
				return '&lt;'
			elseif x == '>' then
				return '&gt;'
			elseif x == '&' then
				return '&amp;'
			elseif x == '"' and in_attribute then
				return '&quot;'
			elseif x == "'" and in_attribute then
				return '&#39;'
			else
				return x
			end
		end)
end

local function cdataEscape(s)
	return s:gsub(']]>', ']]]]><![CDATA[>')
end

local function regexEscape(s)
	return s:gsub('[\\*+?|{[()^$.]', '\\%1')
end


--- Helper functions ---

local Buffer = {}
function Buffer:new()
	local result = { buffer = {} }
    setmetatable(result, { __index = self })
    return result
end
function Buffer:add(line)
	table.insert(self.buffer, line)
end
function Buffer:to_string()
	return table.concat(self.buffer, '\n')
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
	local attr_table = {}
	for x,y in pairs(attr) do
		if y and y ~= "" then
			table.insert(attr_table, ' ' .. x .. '="' .. escape(y,true) .. '"')
		end
	end
	return table.concat(attr_table)
end

local function contains(table, value)
	for _, val in pairs(table) do
		if val == value then
			return true
		end
	end
	return false
end

function table.firstMatch(table, values)
	for _, v in ipairs(table) do
		if contains(values, v) then
			return v
		end
	end
	return nil
end

function string.split(str)
	local words = {}
	for word in str:gmatch("%w+") do table.insert(words, word) end
	return words
end

function string.starts(str, start)
   return string.sub(str, 1, string.len(start)) == start
end

function string.ends(str, theEnd)
   return (theEnd == '') or (string.sub(str, -string.len(theEnd)) == theEnd)
end


--- Global variables

local supported_colors = {
	'red',
	'yellow',
	'green',
	'grey',
	'blue'
}

local supported_info_types = {
	'info',    -- grey
	'tip',     -- green
	'note',    -- yellow
	'warning', -- red
}

-- https://confluence.atlassian.com/doc/code-block-macro-139390.html#CodeBlockMacro-Parameters
local supported_langs = {
	'actionscript3',
	'bash',
	'csharp',
	'c#',
	'coldfusion',
	'cpp',
	'css',
	'delphi',
	'diff',
	'erlang',
	'groovy',
	'html',
	'xml',
	'java',
	'javafx',
	'javascript',
	'none',
	'perl',
	'php',
	'powershell',
	'python',
	'ruby',
	'scala',
	'sql',
	'vb',
}


--- Render functions ---

-- Table to store footnotes, so they can be included at the end.
local notes = {}

local function toc(metadata)
	if metadata == true then
		metadata = {}
	end
	local title = metadata['title']
	local params = {}
	params['minLevel'] = metadata['min-level']
	params['maxLevel'] = metadata['max-level']

	local buf = Buffer:new()
	if title then
		local n = params['minLevel'] and tonumber(params['minLevel']) or 1
		buf:add('<h' .. n .. '>' .. escape(title) .. '</h' .. n .. '>')
		params['exclude'] = regexEscape(title)
	end
	buf:add('<p>')
	buf:add('  <ac:structured-macro ac:name="toc">')
	for key,val in pairs(params) do
		buf:add('    <ac:parameter ac:name="' .. escape(key,true) .. '">' .. escape(val) .. '</ac:parameter>')
	end
	buf:add('  </ac:structured-macro>')
	buf:add('</p>')
	return buf:to_string()
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
	local buf = Buffer:new()
	if metadata['toc'] then
		buf:add(toc(metadata['toc']))
	end
	buf:add(body)
	if #notes > 0 then
		buf:add('<ol class="footnotes">')
		for _,note in pairs(notes) do
			buf:add(note)
		end
		buf:add('</ol>')
	end
	return buf:to_string() .. '\n'
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
	return escape(s)
end

function Space()
	return " "
end

function SoftBreak()
	return "\n"
end

function LineBreak()
	return "<br/>\n"
end

-- Blocksep is used to separate block elements.
function Blocksep()
	return "\n\n"
end

function Emph(s)
	return "<em>" .. s .. "</em>"
end

function Strong(s)
	return "<strong>" .. s .. "</strong>"
end

function Subscript(s)
	return "<sub>" .. s .. "</sub>"
end

function Superscript(s)
	return "<sup>" .. s .. "</sup>"
end

function SmallCaps(s)
	return '<span style="font-variant: small-caps;">' .. s .. '</span>'
end

function Strikeout(s)
	return '<del>' .. s .. '</del>'
end


local function innerLinkTags(s, attr)
	local buf = Buffer:new()
	local page  = attr['content-title']
	local space = attr['space-key']
	if page and space then
		buf:add('  <ri:page ri:content-title="' .. escape(page,true) .. '"'
				       .. ' ri:space-key="' .. escape(space,true) .. '"/>')
	elseif page then
		buf:add('  <ri:page ri:content-title="' .. escape(page,true) .. '"/>')
	elseif space then
		buf:add('  <ri:space ri:space-key="' .. escape(space,true) .. '"/>')
	end
	if s ~= "" then
		buf:add('  <ac:link-body>' .. s .. '</ac:link-body>')
	end
	return buf:to_string()
end

function Link(s, src, title, attr)
	if src:byte(1) == string.byte('#') then
		return '<ac:link ac:anchor="' .. escape(src:sub(2),true) .. '">\n' .. innerLinkTags(s, attr) .. '\n</ac:link>'
	elseif attr['content-title'] or attr['space-key'] then
		return '<ac:link>\n' .. innerLinkTags(s, attr) .. '\n</ac:link>'
	elseif title and title ~= "" then
		return '<a href="' .. escape(src,true) .. '" title="' .. escape(title,true) .. '">' .. s .. '</a>'
	else
		return '<a href="' .. escape(src,true) .. '">' .. s .. '</a>'
	end
end


local function innerImageTag(src, attr)
	if attr['type'] == 'attachment' then
		return '<ri:attachment ri:filename="' .. escape(src,true) .. '"/>'
	elseif attr['type'] == 'page' then
		return '<ri:page ri:content-title="' .. escape(attr['content-title'],true) .. '" ri:space-key="' .. escape(attr['space-key'],true) .. '"/>'
	else -- if attr['type'] == 'url' then
		return '<ri:url ri:value="' .. escape(src,true) .. '"/>'
	end
end

function Image(s, src, title, attr)
	return '<ac:image ac:alt="' .. s .. '">' .. innerImageTag(src, attr) .. '</ac:image>'
end

function CaptionedImage(src, title, caption, attr)
	return '<ac:image ac:align="center" ac:border="true" ac:title="' .. escape(caption,true) .. '">'
			.. innerImageTag(src, attr)
			.. '</ac:image>'
			.. '<p style="text-align: center;">' .. escape(caption) .. '</p>'
end


function Code(s, attr)
	return "<code" .. attributes(attr) .. ">" .. escape(s) .. "</code>"
end

-- http://pandoc.org/MANUAL.html#fenced-code-blocks
function CodeBlock(s, attr)
	local classes = string.split(attr['class'])
	local params = {}
	if classes[1] and contains(supported_langs, string.lower(classes[1])) then
		params['language'] = classes[1]
	end
	params['title'] = attr['title']
	if contains(classes, 'numberLines') then
		params['linenumbers'] = 'true'
	end
	params['firstline'] = attr['startFrom']
	if contains(classes, 'collapse') then
		params['collapse'] = 'true'
	end

	local buf = Buffer:new()
	buf:add('<ac:structured-macro ac:name="code">')
	for key, val in pairs(params) do
		buf:add('  <ac:parameter ac:name="' .. escape(key,true) .. '">' .. escape(val) .. '</ac:parameter>')
	end
	buf:add('  <ac:plain-text-body><![CDATA[' .. cdataEscape(s) .. ']]></ac:plain-text-body>')
	buf:add('</ac:structured-macro>')
	return buf:to_string()
end

function InlineMath(s)
	return "\\(" .. escape(s) .. "\\)"
end

function DisplayMath(s)
	return "\\[" .. escape(s) .. "\\]"
end

function Note(s)
	local num = #notes + 1
	-- insert the back reference right before the final closing tag.
	s = string.gsub(s,
		'(.*)</', '%1 <a href="#fnref' .. num ..  '">&#8617;</a></')
	-- add a list item with the note to the note table.
	table.insert(notes, '<li id="fn' .. num .. '">' .. s .. '</li>')
	-- return the footnote reference, linked to the note.
	return '<a id="fnref' .. num .. '" href="#fn' .. num .. '"><sup>' .. num .. '</sup></a>'
end

function Cite(s, cs)
	local ids = {}
	for _,cit in ipairs(cs) do
		table.insert(ids, cit.citationId)
	end
	return '<span class="cite" data-citation-ids="' .. table.concat(ids, ",") .. '">' .. s .. '</span>'
end

function Plain(s)
	return s
end

-- Raw HTML: http://pandoc.org/MANUAL.html#extension-raw_html
function RawInline(lang, tagStr)
	return tagStr
end

function RawBlock(lang, tagStr)
	-- Strip HTML comments, styles, scripts.
	if tagStr:starts('<!--') and tagStr:ends('-->') then
		return ''
	elseif tagStr:starts('<style ') and tagStr:ends('</style>') then
		return ''
	elseif tagStr:starts('<script ') and tagStr:ends('</script>') then
		return ''
	else
		return tagStr
	end
end


local function InfoMacro(type, s, attr)
	local buf = Buffer:new()
	buf:add('<ac:structured-macro ac:name="' .. type .. '">')
	if attr['title'] ~= nil then
		buf:add('  <ac:parameter ac:name="title">' .. attr['title'] .. '</ac:parameter>')
	end
	buf:add('  <ac:rich-text-body>')
	buf:add('    ' .. s)
	buf:add('  </ac:rich-text-body>')
	buf:add('</ac:structured-macro>')
	return buf:to_string()
end


-- Native Div blocks: https://pandoc.org/MANUAL.html#extension-native_divs
-- Fenced Div blocks: https://pandoc.org/MANUAL.html#extension-fenced_divs
function Div(s, attr)
	local info_type = table.firstMatch(attr['class']:split(), supported_info_types)
	if info_type ~= nil then
		return InfoMacro(info_type, s, attr)
	else
		return "<div" .. attributes(attr) .. ">" .. s .. "</div>"
	end
end


local function StatusMacro(s, attr)
	local buf = Buffer:new()

	local classes = attr['class']:split()
	local color = table.firstMatch(classes, supported_colors)
	local subtle = contains(classes, "subtle")

	buf:add('<ac:structured-macro ac:name="status">')
	if color then
		buf:add('  <ac:parameter ac:name="colour">' .. color .. '</ac:parameter>')
	end
	buf:add('  <ac:parameter ac:name="title">' .. s .. '</ac:parameter>')
	buf:add('  <ac:parameter ac:name="subtle">' .. tostring(subtle) .. '</ac:parameter>')
	buf:add('</ac:structured-macro>')
	return buf:to_string()
end


-- Native Span blocks: http://pandoc.org/MANUAL.html#extension-native_spans
function Span(s, attr)
	local classes = attr['class']:split()
	if contains(classes, 'status') then
		return StatusMacro(s, attr)
	else
		return "<span" .. attributes(attr) .. ">" .. s .. "</span>"
	end
end


function Para(s)
	return "<p>" .. s .. "</p>"
end


local function Anchor(id)
	return '<ac:structured-macro ac:name="anchor"><ac:parameter ac:name="">' .. escape(id,true) .. '</ac:parameter></ac:structured-macro>'
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
	local id = attr['id']
	attr['id'] = nil
	return  Anchor(id) .. "\n<h" .. lev .. attributes(attr) ..  ">" .. s .. "</h" .. lev .. ">"
end


function BlockQuote(s)
	return "<blockquote>\n" .. s .. "\n</blockquote>"
end

function HorizontalRule()
	return "<hr/>"
end

function BulletList(items)
	local buf = Buffer:new()
	for _, item in pairs(items) do
		buf:add("<li>" .. item .. "</li>")
	end
	return "<ul>\n" .. buf:to_string() .. "\n</ul>"
end

function OrderedList(items)
	local buf = Buffer:new()
	for _, item in pairs(items) do
		buf:add("<li>" .. item .. "</li>")
	end
	return "<ol>\n" .. buf:to_string() .. "\n</ol>"
end

-- Revisit association list STackValue instance.
function DefinitionList(items)
	local buf = Buffer:new()
	for _,item in pairs(items) do
		for k, v in pairs(item) do
			buf:add("<dt>" .. k .. "</dt>\n<dd>" .. table.concat(v, "</dd>\n<dd>") .. "</dd>")
		end
	end
	return "<dl>\n" .. buf:to_string() .. "\n</dl>"
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
local function html_align(align)
	if align == 'AlignLeft' then
		return 'left'
	elseif align == 'AlignRight' then
		return 'right'
	elseif align == 'AlignCenter' then
		return 'center'
	else
		return 'left'
	end
end


-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
	local buf = Buffer:new()

	local function addCell(tag, i, c)
		local attrs = {}

		local align = html_align(aligns[i])
		if align ~= 'left' then
			attrs['style'] = 'text-align: ' .. align .. ';'
		end

		local color, text = c:match('^<p><span class="(%w*)">(.*)</span></p>$')
		if text then
			text = '<p>' .. text .. '</p>'
		else
			color, text = c:match('^<span class="(%w*)">(.*)</span>$')
		end
		
		if color and text and contains(supported_colors, color) then
			attrs['class'] = 'highlight-' .. color
			attrs['data-highlight-colour'] = color
		else
			text = c
		end

		buf:add('<' .. tag .. attributes(attrs) .. '>' .. text .. '</' .. tag .. '>')
	end

	if caption and caption ~= "" then
		buf:add("<p>" .. caption .. "</p>") -- <caption/> is not supported in CSF.
	end
	buf:add("<table>")
	buf:add("<tbody>")
--	if widths and widths[1] ~= 0 then
--		add('<colgroup>')
--		for _, w in pairs(widths) do
--			add('<col width="' .. string.format("%d%%", w * 100) .. '" />')
--		end
--		add('</colgroup>')
--	end
	local empty_header = true
	for _, header in pairs(headers) do
		if header ~= "" then
			empty_header = false
			break
		end
	end
	if not empty_header then
		buf:add('<tr>')
		for i,c in pairs(headers) do
			addCell('th', i, c)
		end
		buf:add('</tr>')
	end
	for _, row in pairs(rows) do
		buf:add('<tr>')
		for i,c in pairs(row) do
			addCell('td', i, c)
		end
		buf:add('</tr>')
	end
	buf:add("</tbody>")
	buf:add('</table>')
	return buf:to_string()
end

function DoubleQuoted(s)
	return '"' .. escape(s) .. '"'
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
function(_, key)
	io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
	return function() return "" end
end
setmetatable(_G, meta)
