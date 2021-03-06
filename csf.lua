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
			elseif x == '"' then
				return '&quot;'
			elseif x == "'" then
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


--- For debugging ---

-- Usage:
--     function MyFunc1(x, y, ...)
--         printargs('MyFunc1', args, x, y)
--     end
-- or
--     function MyFunc2(x, y)
--         printargs('MyFunc2', {}, x, y)
--     end
local function printargs(func, restargs, ...)
	local buf = {}
	for _,v in ipairs(arg) do
		if type(v) == "table" then
			table.insert(buf, "'" .. attributes(v) .. "'")
		else
			table.insert(buf, "'" .. tostring(v) .. "'")
		end
	end
	for _,v in ipairs(restargs) do
		table.insert(buf, "'" .. tostring(v) .. "'")
	end
	print(func .. '(' .. table.concat(buf, ', ') .. ')')
end


--- Global variables

local supported_colors = {
	'red',
	'yellow',
	'green',
	'grey',
	'blue'
}

local function getColorFromClasses(classes)
	for _, class in ipairs(classes) do
		if contains(supported_colors, class) then return class end
	end
	return nil
end

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
	local buffer = {}
	local function add(s)
		table.insert(buffer, s)
	end

	local params = {}
	params['minLevel'] = metadata['toc-min-level']
	params['maxLevel'] = metadata['toc-depth']

	if metadata['toc-title'] then
		local n = (params['minLevel'] or '1')
		add('<h' .. n .. '>' .. metadata['toc-title'] .. '</h' .. n .. '>')
		params['exclude'] = regexEscape(metadata['toc-title'])
	end
	add('<p>')
	add('  <ac:structured-macro ac:name="toc">')
	for key,val in pairs(params) do
		add('    <ac:parameter ac:name="' .. escape(key,true) .. '">' .. escape(val) .. '</ac:parameter>')
	end
	add('  </ac:structured-macro>')
	add('</p>')

	return table.concat(buffer, '\n')
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
	local buffer = {}
	local function add(s)
		table.insert(buffer, s)
	end
	if metadata['toc-title'] or metadata['toc-min-level'] or metadata['toc-depth'] then
		add(toc(metadata))
	end
	add(body)
	if #notes > 0 then
		add('<ol class="footnotes">')
		for _,note in pairs(notes) do
			add(note)
		end
		add('</ol>')
	end
	return table.concat(buffer,'\n') .. '\n'
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


local function InternalLink(s, src, tit, attr)
	local buffer = {}
	local function add(s)
		table.insert(buffer, s)
	end
	add('<ac:link ac:anchor="' .. escape(src:sub(2),true) .. '">')
	if attr['content-title'] then
		add('  <ri:page ri:content-title="' .. escape(attr['content-title'],true) .. '" ri:space-key="' .. escape(attr['space-key'],true) .. '"/>')
	end
	add('  <ac:plain-text-link-body><![CDATA[' .. cdataEscape(s) .. ']]></ac:plain-text-link-body>')
	add('</ac:link>')
	return table.concat(buffer, '\n')
end

function Link(s, src, tit, attr)
	if src:byte(1) == string.byte('#') then
		return InternalLink(s, src, tit, attr)
	end
	
	if tit and tit ~= '' then
		return '<a href="' .. escape(src,true) .. '" title="' .. escape(tit,true) .. '">' .. s .. '</a>'
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

function Image(s, src, tit, attr)
	return '<ac:image ac:alt="' .. s .. '">\
  ' .. innerImageTag(src, attr) .. '\
</ac:image>'
end

function CaptionedImage(src, tit, caption, attr)
	return '<ac:image ac:align="center" ac:border="true" ac:title="' .. escape(caption,true) .. '">\
  ' .. innerImageTag(src, attr) .. '\
</ac:image>\
<p style="text-align: center;">' .. escape(caption) .. '</p>'
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

	local buffer = {}
	local function add(s)
		table.insert(buffer, s)
	end
	add('<ac:structured-macro ac:name="code">')
	for key, val in pairs(params) do
		add('  <ac:parameter ac:name="' .. escape(key,true) .. '">' .. escape(val) .. '</ac:parameter>')
	end
	add('  <ac:plain-text-body><![CDATA[' .. cdataEscape(s) .. ']]></ac:plain-text-body>')
	add('</ac:structured-macro>')
	return table.concat(buffer, '\n')
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
	return '<a id="fnref' .. num .. '" href="#fn' .. num ..
			'"><sup>' .. num .. '</sup></a>'
end

function Cite(s, cs)
	local ids = {}
	for _,cit in ipairs(cs) do
		table.insert(ids, cit.citationId)
	end
	return "<span class=\"cite\" data-citation-ids=\"" .. table.concat(ids, ",") ..
			"\">" .. s .. "</span>"
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

-- Native Div blocks: http://pandoc.org/MANUAL.html#extension-native_divs
function Div(s, attr)
	return "<div" .. attributes(attr) .. ">" .. s .. "</div>"
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


function StatusMacro(s, attr)
	local buffer = {}
	local function add(s)
		table.insert(buffer, s)
	end

	local classes = attr['class']:split()
	local color = getColorFromClasses(classes)
	local subtle = contains(classes, "subtle")

	add('<ac:structured-macro ac:name="status">')
	if color then
		add('  <ac:parameter ac:name="colour">' .. color .. '</ac:parameter>')
	end
	add('  <ac:parameter ac:name="title">' .. s .. '</ac:parameter>')
	add('  <ac:parameter ac:name="subtle">' .. tostring(subtle) .. '</ac:parameter>')
	add('</ac:structured-macro>')
	return table.concat(buffer, '\n')
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
	local buffer = {}
	for _, item in pairs(items) do
		table.insert(buffer, "<li>" .. item .. "</li>")
	end
	return "<ul>\n" .. table.concat(buffer, "\n") .. "\n</ul>"
end

function OrderedList(items)
	local buffer = {}
	for _, item in pairs(items) do
		table.insert(buffer, "<li>" .. item .. "</li>")
	end
	return "<ol>\n" .. table.concat(buffer, "\n") .. "\n</ol>"
end

-- Revisit association list STackValue instance.
function DefinitionList(items)
	local buffer = {}
	for _,item in pairs(items) do
		for k, v in pairs(item) do
			table.insert(buffer,"<dt>" .. k .. "</dt>\n<dd>" ..
					table.concat(v,"</dd>\n<dd>") .. "</dd>")
		end
	end
	return "<dl>\n" .. table.concat(buffer, "\n") .. "\n</dl>"
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
function html_align(align)
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
	local buffer = {}
	local function add(s)
		table.insert(buffer, s)
	end

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

		add('<' .. tag .. attributes(attrs) .. '>' .. text .. '</' .. tag .. '>')
	end

	if caption and caption ~= "" then
		add("<p>" .. caption .. "</p>") -- <caption/> is not supported in CSF.
	end
	add("<table>")
	add("<tbody>")
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
		add('<tr>')
		for i,c in pairs(headers) do
			addCell('th', i, c)
		end
		add('</tr>')
	end
	for _, row in pairs(rows) do
		add('<tr>')
		for i,c in pairs(row) do
			addCell('td', i, c)
		end
		add('</tr>')
	end
	add("</tbody>")
	add('</table>')
	return table.concat(buffer,'\n')
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
