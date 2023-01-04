import argparse
import os
import sys

from confluence import Confluence


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

	if args.text is not None:
		content = args.text
	else:
		content = args.file.read()

	confluence = Confluence(args.baseurl, args.user)
	confluence.post_page(args.pageid, args.space, args.title, args.new_title, content)


if __name__ == "__main__":
	main()
