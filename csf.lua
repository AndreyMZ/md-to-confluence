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

-- Character escaping
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

local function split(str)
	local words = {}
	for word in str:gmatch("%w+") do table.insert(words, word) end
	return words
end

local function contains(table, value)
	for key, val in pairs(table) do
		if val == value then
			return true
		end
	end
	return false
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
	return "\n\n"
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
	if metadata["toc"] or variables["toc"] then
		add(toc())
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

local function toc()
	return 'TODO: TOC'
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
	return "<br/>"
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

function Link(s, src, tit, attr)
	if tit and tit ~= '' then
		return '<a href="' .. escape(src,true) .. '" title="' .. escape(tit,true) .. '">' .. s .. '</a>'
	else
		return '<a href="' .. escape(src,true) .. '">' .. s .. '</a>'
	end
end

local function innerImageTag(src, attr)
	local innerTag
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
	return '<ac:image ac:align="center" ac:border="true" ac:title="' .. caption .. '">\
  ' .. innerImageTag(src, attr) .. '\
</ac:image>\
<p style="text-align: center;">' .. escape(caption) .. '</p>'
end

function Code(s, attr)
	return "<code" .. attributes(attr) .. ">" .. escape(s) .. "</code>"
end

function CodeBlock(s, attr)
	-- http://pandoc.org/MANUAL.html#fenced-code-blocks
	local classes = split(attr['class'])
	local params = {}
	params['language'] = classes[1]
	params['title'] = attr['title']
	if contains(classes, 'numberLines') then
		params['linenumbers'] = 'true'
	end
	params['firstline'] = attr['startFrom']
	if contains(classes, 'collapse') then
		params['collapse'] = 'true'
	end

	local paramTags = {}
	for key, val in pairs(params) do
		if val and val ~= "" then
			table.insert(paramTags, '<ac:parameter ac:name="' .. escape(key,true) .. '">' .. escape(val) .. '</ac:parameter>\n')
		end
	end
	return '<ac:structured-macro ac:name="code">\n' .. table.concat(paramTags) .. '<ac:plain-text-body><![CDATA[' .. s .. ']]></ac:plain-text-body>\n</ac:structured-macro>'
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

function Span(s, attr)
	return "<span" .. attributes(attr) .. ">" .. s .. "</span>"
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

function Para(s)
	return "<p>" .. s .. "</p>"
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
	return "<h" .. lev .. attributes(attr) ..  ">" .. s .. "</h" .. lev .. ">"
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
	add("<table>")
	if caption ~= "" then
		add("<caption>" .. caption .. "</caption>")
	end
	if widths and widths[1] ~= 0 then
		for _, w in pairs(widths) do
			add('<col width="' .. string.format("%d%%", w * 100) .. '" />')
		end
	end
	local header_row = {}
	local empty_header = true
	for i, h in pairs(headers) do
		local align = html_align(aligns[i])
		table.insert(header_row,'<th align="' .. align .. '">' .. h .. '</th>')
		empty_header = empty_header and h == ""
	end
	if empty_header then
		head = ""
	else
		add('<tr class="header">')
		for _,h in pairs(header_row) do
			add(h)
		end
		add('</tr>')
	end
	local class = "even"
	for _, row in pairs(rows) do
		class = (class == "even" and "odd") or "even"
		add('<tr class="' .. class .. '">')
		for i,c in pairs(row) do
			add('<td align="' .. html_align(aligns[i]) .. '">' .. c .. '</td>')
		end
		add('</tr>')
	end
	add('</table')
	return table.concat(buffer,'\n')
end

function Div(s, attr)
	return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
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
