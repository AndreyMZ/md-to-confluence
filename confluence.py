"""
https://docs.atlassian.com/confluence/REST/latest/
https://developer.atlassian.com/confdev/confluence-server-rest-api/confluence-rest-api-examples
"""

import sys
import urllib.parse
from enum import Enum
from typing import List, Optional, Tuple, Dict, Union

import requests

from authenticate import authenticate


class Method(Enum):
	GET = "GET"
	POST = "POST"
	PUT = "PUT"


class Confluence:

	KEYRING_SERVICE_NAME = 'confluence_poster'


	def __init__(self, baseUrl: str, username: str = None):
		self.base_url: str = baseUrl
		self.credentials: Tuple[str, str] = authenticate(Confluence.KEYRING_SERVICE_NAME, username)
		self._session = requests.Session()


	def delete_password(self) -> None:
		import authenticate
		authenticate.delete_password(Confluence.KEYRING_SERVICE_NAME, self.credentials[0])


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
		res = self._request(Method.GET, "rest/api/content", query={
			"spaceKey": spaceKey,
			"title": title,
			"expand": "version,ancestors,space",
		})
		return res["results"]


	def get_page_info(self, pageid: int) -> dict:
		info = self._request(Method.GET, "rest/api/content/{0}".format(urlencode(pageid)), query={
			"expand": "version,ancestors,space",
		})
		return info


	def create_page(self, spaceKey: str, title: str, content: str) -> dict:
		print("To create: a page in space `{0}` with title `{1}`".format(spaceKey, title))
		input("Press Enter to continue...")

		info = self._request(Method.POST, "rest/api/content/", {"expand": "version,ancestors,space"}, {
			"type": "page",
			"space": {"key": spaceKey},
			"title": title,
			"body": {
				"storage": {
					"representation": "storage",
					"value": content,
				}
			}
		})

		print("Created: {0} (version {1})".format(info["_links"]["webui"], info["version"]["number"]))
		return info


	def edit_page(self, info: dict, title: Optional[str], content: str) -> dict:
		print('Page to edit: {0} (version {1})'.format(info['_links']['webui'], info['version']['number']))
		input("Press Enter to continue...")
		
		pageid: str = info["id"]
		ver = int(info["version"]["number"]) + 1
		if title is None:
			title = info["title"]

		# https://answers.atlassian.com/questions/5278993/updating-a-confluence-page-with-rest-api-problem-with-ancestors
		allAncestors = info['ancestors']
		ancestors = [{'id' : allAncestors[-1]['id']}] if len(allAncestors) != 0 else []

		info = self._request(Method.PUT, "rest/api/content/{0}".format(urlencode(pageid)), data={
			"id": pageid,
			"type": "page",
			"title": title,
			"version": {"number": ver},
			"ancestors": ancestors,
			"body": {
				"storage": {
					"representation": "storage",
					"value": content,
				}
			}
		})

		print("Edited: {0} (version {1})".format(info['_links']['webui'], info['version']['number']))
		return info


	def _request(self, method: Method, path: str, query: Optional[Dict[str, str]] = None, data: Optional[dict] = None) -> dict:
		r = self._session.request(method.value, "{0}/{1}".format(self.base_url, path),
		                          params=query,
		                          json=data,
		                          auth = self.credentials,
		                          headers = {'Content-Type': 'application/json'})
		r.raise_for_status()
		return r.json()


def urlencode(value: Union[str, int]) -> str:
	if isinstance(value, int):
		return str(value)
	else:
		return urllib.parse.quote(value, safe="")
