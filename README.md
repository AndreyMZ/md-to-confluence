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

- `author` - is used to guess username if it is not specified.

- `confluence`

    -  `page-url` is required to edit existing page.
    
        Username and port are optional.
    
        Examples:
        
        - `https://jsmith@example.com:443/confluence/display/~jsmith/My+existing+page`
        - `https://jsmith@example.com:443/confluence/pages/viewpage.action?pageId=12345`
    
    -  `base-url` is required to create new page.
    
        Username and port are optional.
    
         Examples:
         
         - `https://confluence.example.com`
         - `https://jsmith@example.com:443/confluence`
         
    -  `page-version` is not required. 

If username is not specified as part of the URL, it is guessed from first `author` (e.g.: John Smith -> jsmith).
If `author` is not specified, default username is from the environment or password database.

New page is created in user's home space, e.g. `~jsmith`.

Password is prompted in console. It is cached in the system keyring service.

See examples in the `example/` directory.

### Example of Sublime Text build system config

`Sublime Text 3\Packages\User\Post to Confluence.sublime-build`

```json
{
	"selector": "text.html.markdown",
	"shell_cmd": "start cmd /C \"py C:\\GIT\\confluence-poster\\md_to_confluence.py \"$file\" & pause\""
}
```


### Limitations

#### Definition list

Definition lists are not supported by Confluense Storage Format (CSF).
The suggestion is here: https://jira.atlassian.com/browse/CONF-1322


### Extra syntax

#### Image link type

CSF supports three types of image links:

1. `url`

		![Fig. 1](http://example.com/fig-1.png)

2. `attachment` (from this page)

		![Fig. 2](fig-2.png){type="attachment"}

3. `page` (attachment from other page)

		![Fig. 3](fig-3.png){type="page", space-key="MYKEY", content-title="My Page Title"}
	
#### Code block attributes

CSF supports the following [code block attibutes](http://pandoc.org/MANUAL.html#extension-fenced_code_attributes):

- Language class - the first defined class. Syntax highlighting is supported for the following languages: https://confluence.atlassian.com/doc/code-block-macro-139390.html#CodeBlockMacro-Parameters
- `.numberLines` class
- `startFrom`
- `title`
- `.collapse` class

E.g.:

    ~~~ {.c .numberLines startFrom=4 title="myfile.c" .collapse}
    int main() {
        return 0;
    }
    ~~~

#### Table cell color

CSF supports the following colors for table cells:

	| color                                  |
	|----------------------------------------|
	| <span class="red">RED FOO</span>       |
	| <span class="yellow">YELLOW BAR</span> |
	| <span class="green">GREEN BAZ</span>   |
	| <span class="grey">GREY QWE</span>     |
	| <span class="blue">BLUE ASD</span>     |


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