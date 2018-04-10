# Requirements

- [Python 3](https://www.python.org/downloads/)
- Python packages (use `pip install -r requirements.txt` or, if you have several versions of python on Windows, `py -3 -m pip install -r requirements.txt`):
    - [keyring](http://pythonhosted.org/keyring/)
    - [requests](https://requests.readthedocs.io/en/master/)
    - [pyyaml](pyyaml.org/wiki/PyYAMLDocumentation)
- [Pandoc](http://pandoc.org/installing.html) >= 2.1.3

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
    
- `toc-title` - title of TOC (Table of Content). Default: no title.

- `toc-min-level` - minimum header level to include in TOC.

- `toc-depth` - maximum header level to include in TOC.

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

#### Table of Content (TOC)

TOC is added if and only if at least one of `toc-*` is specified in the metadata.

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
- red
- yellow
- green
- grey
- blue

Example:

	| color                 |
	|-----------------------|
	| [RED FOO]{.red}       |
	| [YELLOW BAR]{.yellow} |
	| [GREEN BAZ]{.green}   |
	| [GREY QWE]{.grey}     |
	| [BLUE ASD]{.blue}     |

or

	| color                                  |
	|----------------------------------------|
	| <span class="red">RED FOO</span>       |
	| <span class="yellow">YELLOW BAR</span> |
	| <span class="green">GREEN BAZ</span>   |
	| <span class="grey">GREY QWE</span>     |
	| <span class="blue">BLUE ASD</span>     |

#### Status Macro

Confluence Documentation: https://confluence.atlassian.com/doc/status-macro-223222355.html

Example:

    [NO COLOR]{.status}
    [RED FOO]{.status .red}
    [YELLOW BAR]{.status .yellow}
    [GREEN BAZ]{.status .green}
    [GREY QWE]{.status .grey}
    [BLUE ASD]{.status .blue}

    [NO COLOR]{.status .subtle}
    [RED FOO]{.status .subtle .red}
    [YELLOW BAR]{.status .subtle .yellow}
    [GREEN BAZ]{.status .subtle .green}
    [GREY QWE]{.status .subtle .grey}
    [BLUE ASD]{.status .subtle .blue}

You can use the following compatible CSS style for HTML output:

    <style type="text/css">
        /* CSF Status Macro */
        .status {
            background-clip: border-box;
            border-style: solid;
            border-radius: 3px;
            border-width: 1px;
            display: inline-block;
            font-size: 11px;
            font-weight: bold;
            line-height: 1;
            min-width: 76px;
            padding: 3px 5px 2px 5px;
            text-align: center;
            text-decoration: none;
            text-transform: uppercase;
        }

        /* Default style */
        .status        { color: #333333; background-color: #cccccc; border-color: #cccccc; }
        .status.red    { color: #ffffff; background-color: #D04436; border-color: #d04437; }
        .status.yellow { color: #594300; background-color: #ffd351; border-color: #ffd351; }
        .status.green  { color: #ffffff; background-color: #14892c; border-color: #14892c; }
        .status.grey   { color: #333333; background-color: #cccccc; border-color: #cccccc; }
        .status.blue   { color: #ffffff; background-color: #4a6785; border-color: #4a6785; }

        /* Subtle (outline) style */
        .status.subtle        { color: #333333; background-color: #ffffff; border-color: #cccccc; }
        .status.subtle.red    { color: #d04437; background-color: #ffffff; border-color: #f8d3d1; }
        .status.subtle.yellow { color: #594300; background-color: #ffffff; border-color: #ffe28c; }
        .status.subtle.green  { color: #14892c; background-color: #ffffff; border-color: #b2d8b9; }
        .status.subtle.grey   { color: #333333; background-color: #ffffff; border-color: #cccccc; }
        .status.subtle.blue   { color: #4a6785; background-color: #ffffff; border-color: #e4e8ed; }
    </style>


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