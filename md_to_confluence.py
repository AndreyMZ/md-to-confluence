#! python3
import argparse
import getpass
import html
import io
import os
import pathlib
import subprocess
import sys
import tempfile
import textwrap
import urllib.parse
from collections import OrderedDict
from typing import List, Optional

import requests
import yaml

from confluence import Confluence

PROJECT_NAME = "md-to-confluence"
PROJECT_URL = "https://github.com/AndreyMZ/md-to-confluence"

CONFLUENCE = 'confluence'
CONFLUENCE_USER_NAME = 'user-name'
CONFLUENCE_BASE_URL = 'base-url'
CONFLUENCE_PAGE_URL = 'page-url'
CONFLUENCE_PAGE_VERSION = 'page-version'
CONFLUENCE_NOTE_AUTOGEN = 'note-autogen'


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("file", type=str,
	                    help="Pandoc's Markdown file path.")
	args = parser.parse_args()

	file = pathlib.Path(args.file)

	# Read Pandoc markwdown file.
	with file.open('r', encoding='utf_8_sig') as fd:
		lines = fd.readlines()

	# Extract YAML metadata block from Pandoc markdown.
	# http://pandoc.org/README.html#extension-yaml_metadata_block
	metadata_content = ''
	if len(lines) > 0 and lines[0] == '---\n':
		lines.pop(0)
		while True:
			if len(lines) == 0:
				raise Exception('No YAML metadata block end')
			line = lines.pop(0)
			if line in ('...\n', '---\n'):
				metadata_end_line = line
				break
			metadata_content += line
	else:
		raise Exception('No YAML metadata block')
	yaml_preserve_order()
	metadata = yaml.safe_load(metadata_content)

	confluenceMetadata = metadata.get(CONFLUENCE) # type: Optional[dict]
	if confluenceMetadata is None:
		raise Exception('No `{0}` section in YAML metadata block'.format(CONFLUENCE))

	# Parse username, baseUrl, pageId, spaceKey, title from the metadata.
	if CONFLUENCE_PAGE_URL in confluenceMetadata:
		urlstr = confluenceMetadata[CONFLUENCE_PAGE_URL]
		url = urllib.parse.urlsplit(urlstr) # type: urllib.parse.SplitResult
		path = pathlib.PurePosixPath(url.path)
		query = urllib.parse.parse_qs(url.query)
		plen = len(path.parts)

		username = url.username
		if plen >= 4 and path.parts[plen-3] == 'display': # e.g. ['/', 'confluence', 'display', '~jsmith', 'Test+page']
			basePath = str(path.parents[2]).rstrip('/')
			pageId = None
			spaceKey = urllib.parse.unquote_plus(path.parts[plen-2])
			title = urllib.parse.unquote_plus(path.parts[plen-1])
		elif plen >= 3 and path.parts[plen-2] == 'pages' and path.parts[plen-1] == 'viewpage.action': # e.g. ['/', 'confluence', 'pages', 'viewpage.action']
			basePath = str(path.parents[1]).rstrip('/')
			pageId = int(query['pageId'][0])
			spaceKey = None
			title = None
		else:
			raise Exception('Unknown Confluence page URL format: {0}'.format(urlstr))

	elif CONFLUENCE_BASE_URL in confluenceMetadata:
		urlstr = confluenceMetadata[CONFLUENCE_BASE_URL]
		url = urllib.parse.urlsplit(urlstr)  # type: urllib.parse.SplitResult

		username = url.username
		basePath = url.path.rstrip('/')
		pageId = None
		spaceKey = None
		title = None

	else:
		raise Exception('No `{0}` or `{1}` in `{2}` section of YAML metadata block'.format(CONFLUENCE_PAGE_URL, CONFLUENCE_BASE_URL, CONFLUENCE))

	baseUrlWithUsername = urllib.parse.urlunsplit((url.scheme, url.netloc,                    basePath, None, None))
	baseUrl             = urllib.parse.urlunsplit((url.scheme, url.netloc.rpartition("@")[2], basePath, None, None))

	newTitle = metadata.get('title') # type: Optional[str]
	authors = metadata.get('author', []) # type: List[str]

	# Set default user name.
	if username is None:
		if len(authors) > 0:
			author = authors[0]
			firstname, lastname = author.split() # type: str
			username = firstname[0].lower() + lastname.lower()
		else:
			username = getpass.getuser()

	# Set default space key.
	if spaceKey is None:
		spaceKey = '~' + username

	# Convert Pandoc's Markdown file to Confluence Storage Format (CSF) using `pandoc` utility.
	cmd = ["pandoc",
	       "--from=markdown+hard_line_breaks+lists_without_preceding_blankline+compact_definition_lists+smart+autolink_bare_uris",
	       "--to", os.path.join(os.path.dirname(sys.argv[0]), "csf.lua"),
	       str(file)]
	res = subprocess.run(cmd, stdout=subprocess.PIPE)
	content = res.stdout.decode('utf-8')

	if confluenceMetadata.get(CONFLUENCE_NOTE_AUTOGEN, False): # type: bool
		note = textwrap.dedent("""\
			<ac:structured-macro ac:name="info" ac:schema-version="1">
			  <ac:rich-text-body><p>This page is generated automatically from <ac:link><ri:attachment ri:filename="{filename}"/></ac:link> using <a href="{project_url}">{project_name}</a>.</p></ac:rich-text-body>
			</ac:structured-macro>
		""").format(
			filename=html.escape(file.name),
			project_name=html.escape(PROJECT_NAME),
			project_url=html.escape(PROJECT_URL)
		)
		content = note + content

	# Ask username and password.
	confluence = Confluence(baseUrl, username)

	# Request Confluence API to edit or create a page.
	try:
		info = confluence.post_page(pageId, spaceKey, title, newTitle, content)
	except requests.exceptions.HTTPError as ex:
		response = ex.response # type: requests.models.Response
		if response.status_code == 401:
			print('Authentication failed.')
		else:
			print(ex)
			print(response.text)
		return
	else:
		if info is None:
			return

	# Update metadata.
	confluenceMetadata.pop(CONFLUENCE_BASE_URL, None)
	confluenceMetadata[CONFLUENCE_PAGE_URL] = baseUrlWithUsername + info['_links']['webui']
	confluenceMetadata[CONFLUENCE_PAGE_VERSION] = info['version']['number']

	# Rewrite Pandoc markdown file with updated YAML metadata block.
	fd = tempfile.NamedTemporaryFile('w', encoding='utf_8', delete=False, dir=str(file.parent), suffix='.tmp') # type: io.TextIOWrapper
	with fd:
		fd.write('---\n')
		yaml.dump(metadata, fd, default_flow_style=False, allow_unicode=True)
		fd.write(metadata_end_line)
		fd.writelines(lines)
	os.replace(fd.name, str(file)) # src and dst are on the same filesystem

	# Attach source file.
	try:
		confluence.attach_file(info, file, content_type="text/markdown", comment="Source code of this page.")
	except requests.exceptions.HTTPError as ex:
		response = ex.response # type: requests.models.Response
		print(ex)
		print(response.text)


def yaml_preserve_order():
	def dict_constructor(loader: yaml.Loader, node: yaml.MappingNode):
		return OrderedDict(loader.construct_pairs(node))

	def dict_representer(dumper: yaml.Dumper, data: OrderedDict):
		return dumper.represent_dict(data.items())

	yaml.add_constructor(yaml.Loader.DEFAULT_MAPPING_TAG, dict_constructor)
	yaml.add_representer(OrderedDict, dict_representer)


if __name__ == "__main__":
	main()
