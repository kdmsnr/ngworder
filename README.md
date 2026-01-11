# ngworder

Simple CLI to extract NG words from Japanese text using a plain text rules file.

## Install
```
gem install ngworder
```

## Usage
Run the CLI with one or more target files. By default it loads `NGWORDS.txt` from the current directory, prints each match and the full line, and colorizes output only when stdout is a TTY. Use `--rule=PATH` to point to another rules file, `--rg` to speed up literal rules with ripgrep, `--no-line` to suppress the full line output, and `--color=auto|always|never` to control color output.
```
ngworder target.md
ngworder --rule=NGWORDS.txt target.md
ngworder --rg target.md
ngworder --no-line target.md
ngworder --color=auto target.md
ngworder --help
```

## Test
```
rake test
```

## Rules File (NGWORDS.txt)
- One rule per line: `NG_WORD !EXCLUDE1 !EXCLUDE2`
- `#` starts a comment; escape as `\#`
- `!` splits exclusions; escape as `\!`
- `/.../` denotes a Ruby regex; escape `/` as `\/`
- Matching is substring-based; exclusions apply only to the same line

Example:
```
ユーザ !ユーザー
インタフェース
/アーキテクチャー?/
```

## Output
```
path/to/file:line:col  match  # comment
```

## Performance
- `--rg` prefilters literal rules with ripgrep (optional). Regex rules still scan normally.
- If `rg` is missing, ngworder falls back to Ruby scanning.
- Install `rg` (ripgrep): https://github.com/BurntSushi/ripgrep#installation

## License
MIT
