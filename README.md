# Credits.rtf
Command line tool to generate "Credits.rtf" (for About page) from xcodeproj



## Usage

```shell
OVERVIEW: A Swift command-line tool to generate Credits.rtf file

USAGE: credits <input> --output <output> [--title-font-size <title-font-size>] [--font-size <font-size>] [--exclude <exclude> ...] [--no-open <no-open>]

ARGUMENTS:
  <input>                 Input file. Supports one of:
                            - .xcodeproj/.pbxproj file
                            - Project direcotry (contains .xcodeproj file)
                            - plain text file with Github repository URLs (one
                          per line)

OPTIONS:
  -o, --output <output>   The output file name.
  -t, --title-font-size <title-font-size>
                          Font size for the title. (default: 16)
  -f, --font-size <font-size>
                          Font size for the content. (default: 12)
  -x, --exclude <exclude> Ignored repositories by name, repeat for multiple.
  -O, --no-open <no-open> Don't automatically open the output file after
                          generation. (default: false)
  -h, --help              Show help information.
```

