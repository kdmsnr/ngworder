# ngworder

Simple CLI to extract NG words from Japanese text using a plain text rules file.

## Install
```
gem install ngworder
```

## Usage
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
