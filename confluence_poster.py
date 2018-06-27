#! python3

"""
https://docs.atlassian.com/confluence/REST/latest/
https://developer.atlassian.com/confdev/confluence-server-rest-api/confluence-rest-api-examples
"""

import argparse
import json
import os
import sys
import urllib.parse
from typing import List, Optional, Tuple

import requests

from authenticate import authenticate


def main() -> None:
	usage = (
		'\n{0} --baseurl BASEURL [--user USER] ([--space SPACE] --title TITLE | --pageid PAGEID) [--new-title NEW_TITLE] ([--file FILE] | --text TEXT)'
		'\n{0} --baseurl BASEURL [--user USER] ([--space SPACE] --new-title NEW_TITLE ([--file FILE] | --text TEXT)'
		'\n{0} (-h | --help)'
	)
	parser = argparse.ArgumentParser(usage=usage.format(os.path.basename(sys.argv[0])))
	parser.add_argument("--baseurl", required=True,
	                    help='Conflunce base URL. Format: https://example.com/confluence')
	parser.add_argument("--user", default=None,
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

	confluence = Confluence(args.baseurl, args.user)

	if args.text is not None:
		content = args.text
	else:
		content = args.file.read()

	confluence.post_page(args.pageid, args.space, args.title, args.new_title, content)


class Confluence:

	KEYRING_SERVICE_NAME = 'confluence_poster'


	def __init__(self, baseUrl: str, username: str = None):
		self.BASE_URL: str = baseUrl
		self.CREDENTIALS: Tuple[str, str] = authenticate(Confluence.KEYRING_SERVICE_NAME, username)


	def delete_password(self) -> None:
		import authenticate
		authenticate.delete_password(Confluence.KEYRING_SERVICE_NAME, self.CREDENTIALS[0])


	def post_page(self, pageid: Optional[int], spaceKey: Optional[str], title: Optional[str], newTitle: str, content: str) -> Optional[dict]:
		"""
		Required arguments:
		- To edit page by id: pageid
		- To edit page by title: spaceKey, title
		- To create page: spaceKey, newTitle
		"""
		try:

			if pageid is not None:
				info = self.get_page_info(pageid)
				return self.edit_page(info, newTitle, content)
			elif spaceKey is not None and title is not None:
				res = self.find_pages_by_title(spaceKey, title)
				if len(res) == 0:
					print('No pages are found in space `{0}` with title: `{1}`'.format(spaceKey, title))
					if title == newTitle:
						sys.stdout.write('Do you want to create it? [y/N]: ')
						sys.stdout.flush()
						if sys.stdin.readline().rstrip('\n').lower() == 'y':
							return self.create_page(spaceKey, title, content)
					return None
				elif len(res) == 1:
					info = res[0]
					return self.edit_page(info, newTitle, content)
				else: # len(res) > 1:
					raise Exception('Multiple pages are found in space `{0}` with title: `{1}`'.format(spaceKey, title))
			elif spaceKey is not None and newTitle is not None:
				return self.create_page(spaceKey, newTitle, content)

		except requests.exceptions.HTTPError as ex:
			if ex.response.status_code == 401:
				self.delete_password()
			raise ex


	def find_pages_by_title(self, spaceKey: str, title: str)  -> List[dict]:
		url = '{0}/rest/api/content?{1}'.format(self.BASE_URL, urllib.parse.urlencode({
			'spaceKey': spaceKey,
			'title': title,
			'expand': 'version,ancestors,space',
		}))
		r = requests.get(url, auth=self.CREDENTIALS)
		r.raise_for_status()
		return r.json()['results']


	def get_page_info(self, pageid: int) -> dict:
		url = '{0}/rest/api/content/{1}?{2}'.format(self.BASE_URL, pageid, urllib.parse.urlencode({
			'expand': 'version,ancestors,space',
		}))
		r = requests.get(url, auth=self.CREDENTIALS)
		r.raise_for_status()
		return r.json()


	def create_page(self, spaceKey: str, title: str, content: str) -> dict:
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
		print('To create: a page in space `{0}` with title `{1}`'.format(spaceKey, title))
		input("Press Enter to continue...")

		url = '{0}/rest/api/content/'.format(self.BASE_URL)
		r = requests.post(url, data=json.dumps(data), auth=self.CREDENTIALS, headers={'Content-Type': 'application/json'})
		r.raise_for_status()

		info = r.json()
		print("Created: {0} (version {1})".format(info['_links']['webui'], info['version']['number']))
		return info


	def edit_page(self, info: dict, title: Optional[str], content: str) -> dict:
		pageid: str = info['id']
		ver = int(info['version']['number']) + 1
		if title is None:
			title = info['title']

		# https://answers.atlassian.com/questions/5278993/updating-a-confluence-page-with-rest-api-problem-with-ancestors
		allAncestors = info['ancestors']
		ancestors = [{'id' : allAncestors[-1]['id']}] if len(allAncestors) != 0 else []

		data = {
			'id': pageid,
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

		url = '{base}/rest/api/content/{pageid}'.format(base=self.BASE_URL, pageid=pageid)
		r = requests.put(url, data=json.dumps(data), auth=self.CREDENTIALS, headers={'Content-Type': 'application/json'})
		r.raise_for_status()

		info = r.json()
		print("Edited: {0} (version {1})".format(info['_links']['webui'], info['version']['number']))
		return info


if __name__ == "__main__":
	main()
