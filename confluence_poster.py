#! python3

"""
https://docs.atlassian.com/confluence/REST/latest/
https://developer.atlassian.com/confdev/confluence-server-rest-api/confluence-rest-api-examples
"""

import argparse
import getpass
import json
import os
import sys
import urllib.parse
from typing import List, Optional

import keyring
import requests

# Globals
KEYRING_SERVICE_NAME = 'confluence_poster'
BASE_URL = None
CREDENTIALS = None


def main() -> None:
	usage = (
		'\n{0} --baseurl BASEURL [--user USER] ([--space SPACE] --title TITLE | --pageid PAGEID) [--new-title NEW_TITLE] ([--file FILE] | --text TEXT)'
		'\n{0} --baseurl BASEURL [--user USER] ([--space SPACE] --new-title NEW_TITLE ([--file FILE] | --text TEXT)'
		'\n{0} (-h | --help)'
	)
	parser = argparse.ArgumentParser(usage=usage.format(os.path.basename(sys.argv[0])))
	parser.add_argument("--baseurl", required=True,
	                    help='Conflunce base URL. Format: https://example.com/confluence')
	parser.add_argument("--user", default=getpass.getuser(),
	                    help="User name to log into Confluence. Default: from the environment or password database.")
	parser.add_argument("--pageid", type=int,
	                    help="Conflunce page id to edit page.")
	parser.add_argument("--space", default=None,
	                    help="Conflunce space key to create/edit page. Default: the user's home.")
	parser.add_argument("--title", default=None,
	                    help="Conflunce page title to edit page.")
	parser.add_argument("--new-title", default=None,
	                    help="New title to create/edit page. By default title is not changed on edit page.")
	group = parser.add_mutually_exclusive_group()
	group.add_argument("--file", type=argparse.FileType('r'), default=sys.stdin,
	                    help="Write the content of FILE to the confluence page. Default: STDIN.")
	group.add_argument("--text",
	                   help="Write the TEXT in Confluence Storage Format (XHTML-like) to the confluence page.")
	args = parser.parse_args()
	if (args.pageid, args.title, args.new_title).count(None) == 3:
		parser.print_usage()
		exit()
	if args.space is None:
		args.space = '~' + args.user

	authenticate(args.baseurl, args.user)

	if args.text is not None:
		content = args.text
	else:
		content = args.file.read()

	post_page(args.pageid, args.space, args.title, args.new_title, content)


def authenticate(baseUrl: str, username: str = None) -> None:
	if username is None:
		username = getpass.getuser()
	passwd = keyring.get_password(KEYRING_SERVICE_NAME, username)
	if passwd is None:
		passwd = getpass.getpass()
		keyring.set_password(KEYRING_SERVICE_NAME, username, passwd)

	global BASE_URL
	global CREDENTIALS
	BASE_URL = baseUrl
	CREDENTIALS = (username, passwd)


def delete_password(username: str = None) -> None:
	if username is None:
		username = getpass.getuser()
	keyring.delete_password(KEYRING_SERVICE_NAME, username)


def post_page(pageid: Optional[int], spaceKey: Optional[str], title: Optional[str], newTitle: str, content: str) -> dict:
	"""
	Required arguments:
	- To edit page by id: pageid
	- To edit page by title: spaceKey, title
	- To create page: spaceKey, newTitle
	"""
	try:

		if pageid is not None:
			info = get_page_info(pageid)
			edit_page(info, newTitle, content)
			return info
		elif spaceKey is not None and title is not None:
			res = find_pages_by_title(spaceKey, title)
			if len(res) == 0:
				raise Exception('No pages are found in space `{0}` with title: `{1}`'.format(spaceKey, title))
			elif len(res) == 1:
				info = res[0]
				edit_page(info, newTitle, content)
				return info
			else: # len(res) > 1:
				raise Exception('Multiple pages are found in space `{0}` with title: `{1}`'.format(spaceKey, title))
		elif spaceKey is not None and newTitle is not None:
			return create_page(spaceKey, newTitle, content)

	except requests.exceptions.HTTPError as ex:
		if ex.response.status_code == 401:
			delete_password(CREDENTIALS[0])
		raise ex


def find_pages_by_title(spaceKey: str, title: str)  -> List[dict]:
	url = '{0}/rest/api/content?{1}'.format(BASE_URL, urllib.parse.urlencode({
		'spaceKey': spaceKey,
		'title': title,
		'expand': 'version,ancestors,space',
	}))
	r = requests.get(url, auth=CREDENTIALS)
	r.raise_for_status()
	return r.json()['results']


def get_page_info(pageid: int) -> dict:
	url = '{0}/rest/api/content/{1}?{2}'.format(BASE_URL, pageid, urllib.parse.urlencode({
		'expand': 'version,ancestors,space',
	}))
	r = requests.get(url, auth=CREDENTIALS)
	r.raise_for_status()
	return r.json()


def create_page(spaceKey: str, title: str, content: str) -> dict:
	data = {
		'type': 'page',
		"space": {"key": spaceKey},
		'title': title,
		'body': {
			'storage': {
				'representation': 'storage',
				'value': str(content),
			}
		}
	}

	# Print info and ask confirmation.
	print('To create: {0}/{1}'.format(spaceKey, title))
	input("Press Enter to continue...")

	url = '{0}/rest/api/content/'.format(BASE_URL)
	r = requests.post(url, data=json.dumps(data), auth=CREDENTIALS, headers={'Content-Type': 'application/json'})
	r.raise_for_status()

	info = r.json()
	print("Created: {0} (version {1})".format(info['_links']['webui'], info['version']['number']))

	return info


def edit_page(info: dict, title: Optional[str], content: str) -> None:
	pageid = int(info['id'])
	ver = int(info['version']['number']) + 1
	if title is None:
		title = info['title']

	ancestors = info['ancestors']
	for anc in ancestors:
		del anc['_links']
		del anc['_expandable']

	data = {
		'id': str(pageid),
		'type': 'page',
		'title': title,
		'version': {'number': ver},
		'ancestors': ancestors,
		'body': {
			'storage': {
				'representation': 'storage',
				'value': str(content),
			}
		}
	}

	# Print info and ask confirmation.
	print('Page to edit: {0} (version {1})'.format(info['_links']['webui'], info['version']['number']))
	input("Press Enter to continue...")

	url = '{base}/rest/api/content/{pageid}'.format(base=BASE_URL, pageid=pageid)
	r = requests.put(url, data=json.dumps(data), auth=CREDENTIALS, headers={'Content-Type': 'application/json'})
	r.raise_for_status()

	info = r.json()
	print("Edited: {0} (version {1})".format(info['_links']['webui'], info['version']['number']))


if __name__ == "__main__":
	main()
