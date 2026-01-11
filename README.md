# ngworder

Simple CLI to extract NG words from Japanese text using a plain text rules file.

## Install
```
gem build ngworder.gemspec
gem install ./ngworder-0.1.0.gem
```

## Usage
```
ngworder target.md
ngworder --rule=NGWORDS.txt target.md
ngworder --rg target.md
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
path/to/file:line:col  match  NG:<rule>
```

## Performance
- `--rg` prefilters literal rules with ripgrep (optional). Regex rules still scan normally.
- If `rg` is missing, ngworder falls back to Ruby scanning.
- Install `rg` (ripgrep): https://github.com/BurntSushi/ripgrep#installation

## License
MIT
