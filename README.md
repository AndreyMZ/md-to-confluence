# Requirements

- [Python 3](https://www.python.org/downloads/)
- Python packages (use `pip install PACKAGE_NAME` or, if you have several versions of python on Windows, `py -3 -m pip install PACKAGE_NAME`):
    - [keyring](http://pythonhosted.org/keyring/)
    - [requests](https://requests.readthedocs.io/en/master/)
    - [pyyaml](pyyaml.org/wiki/PyYAMLDocumentation)
- [Pandoc](http://pandoc.org/installing.html)

# Usage

## MD to Confluence

    usage: md_to_confluence.py [-h] file
    
    positional arguments:
      file        Pandoc markdown file path.
    
    optional arguments:
      -h, --help  show this help message and exit

Input file format: <http://pandoc.org/README.html#pandocs-markdown>

YAML metadata used:

- `title` - new title.

- `author` - is used to guess `user-name` if it is not specified.

- `confluence`

    -  `page-url` is required to edit existing page.
    
        Examples:
        
        - `https://confluence.example.com/display/~azelenchuk/My+existing+page`
        - `https://confluence.example.com/pages/viewpage.action?pageId=12345`
    
    -  `base-url` is required to create new page.
    
         Examples:
         
         - `https://example.com/confluence`
         - `https://confluence.example.com`
         
    -  `user-name` - Confluence login. If it is not specified, it is guessed from first `author` (e.g.: John Smith -> jsmith).
       If `author` is not specified, default is from the environment or password database.
         
    -  `page-version` is not required. 

See examples in the `example/` directory.


## Confluence poster

    confluence_poster.py --baseurl BASEURL [--user USER] ([--space SPACE] --title TITLE | --pageid PAGEID) [--new-title NEW_TITLE] ([--file FILE] | --text TEXT)
    confluence_poster.py --baseurl BASEURL [--user USER] ([--space SPACE] --new-title NEW_TITLE ([--file FILE] | --text TEXT)
    confluence_poster.py (-h | --help)
    
    optional arguments:
      -h, --help            show this help message and exit
      --baseurl BASEURL     Conflunce base URL. Format:
                            https://example.com/confluence
      --user USER           User name to log into Confluence. Default: from the
                            environment or password database.
      --pageid PAGEID       Conflunce page id to edit page.
      --space SPACE         Conflunce space key to create/edit page. Default: the
                            user's home.
      --title TITLE         Conflunce page title to edit page.
      --new-title NEW_TITLE
                            New title to create/edit page. By default title is not
                            changed on edit page.
      --file FILE           Write the content of FILE to the confluence page.
                            Default: STDIN.
      --text TEXT           Write the TEXT in Confluence Storage Format (XHTML-
                            like) to the confluence page.
