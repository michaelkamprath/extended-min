# Extended Min for Sublime Text

Syntax highlighting, comment toggling, and auto-indent for Extended Min (`*.xmin`) files.

The `ExtendedMin` package contains:

- `ExtendedMin.sublime-syntax`: highlighting for keywords, types, casts, built-ins, `:=` constants, declarations, function definitions and parameters (including `&` by-reference), strings and escapes (`\n \r \t \e \0`), decimal and hex numbers, `$(...)` hex byte blobs, `@` address bindings, `[a|b]` slices, `_` concatenation, and `#` comments
- `Comments.tmPreferences`: `#` for Toggle Comment (Cmd+/)
- `Indentation Rules.tmPreferences`: indent after `if` / `elif` / `else` / `while` / `def` lines
- `ExtendedMin.sublime-settings`: spaces instead of tabs, indent width 2
- `syntax_test_xmin.xmin`: a Sublime syntax test; open it and run Tools > Build to check the definition

## Install

Run these commands from the repository root. Each one links the package into Sublime Text's `Packages` folder, so later changes in the repo take effect directly.

macOS:

```bash
ln -s "$PWD/editors/sublime-text/ExtendedMin" \
  "$HOME/Library/Application Support/Sublime Text/Packages/ExtendedMin"
```

Linux:

```bash
ln -s "$PWD/editors/sublime-text/ExtendedMin" \
  "$HOME/.config/sublime-text/Packages/ExtendedMin"
```

Windows (PowerShell; creating a symbolic link needs Developer Mode or an administrator shell):

```powershell
New-Item -ItemType SymbolicLink `
  -Path "$env:APPDATA\Sublime Text\Packages\ExtendedMin" `
  -Target "$PWD\editors\sublime-text\ExtendedMin"
```

You can copy the `ExtendedMin` folder to the same location instead, but a copy does not pick up later changes. Sublime Text menu Preferences > Browse Packages... opens the `Packages` folder.

Sublime Text loads the package without a restart. `*.xmin` files open as Extended Min; for other files, choose View > Syntax > Extended Min. To check the definition, open `syntax_test_xmin.xmin` and run Tools > Build.

To uninstall, delete `Packages/ExtendedMin`. Deleting the link leaves the repo files in place.

## Scopes

Scope names follow Sublime's Python syntax where Extended Min has an equivalent, so Python-oriented color schemes color most of the language. Every kind of punctuation has its own scope. All scopes end in `.xmin`.

| Construct | Scope |
|---|---|
| `#` comment / its `#` | `comment.line.number-sign` / `punctuation.definition.comment` |
| `"..."` / its quotes | `string.quoted.double` / `punctuation.definition.string.begin`, `.end` |
| `\n \r \t \e \0 \"` | `constant.character.escape` |
| unterminated string | `invalid.illegal.unclosed-string` |
| `123` / `0x1F` / its `0x` | `constant.numeric.integer.decimal` / `constant.numeric.integer.hexadecimal` / `punctuation.definition.numeric.base` |
| `use` | `keyword.control.import` |
| `if` / `elif` / `else` | `keyword.control.conditional.if` / `.elseif` / `.else` |
| `while` | `keyword.control.loop.while` |
| `break` / `return` / `call` | `keyword.control.flow.break` / `.return` / `.call` |
| `:` ending `if`/`elif`/`else` / `while` / `def` | `punctuation.section.block.conditional` / `punctuation.section.block.loop` / `punctuation.section.function.begin` |
| `def` / function name | `keyword.declaration.function` / `entity.name.function` |
| parameter `(` `)` / `,` | `punctuation.section.parameters.begin`, `.end` / `punctuation.separator.parameters` |
| parameter type / `&` / name | `support.type` / `storage.modifier.reference` / `variable.parameter` |
| declaration type / declared name | `storage.type` / `variable.other.declaration` |
| constant name in `char Name := ...` / `:=` | `variable.other.constant` / `keyword.operator.assignment.constant` |
| initializer `,` (`int v = 1, 2`) | `punctuation.separator.sequence` |
| cast `int(...)` type | `support.type` |
| built-in (`print`, `len`, `append`, ...) | `support.function.builtin` |
| called function name | `variable.function` |
| call `(` `)` / `,` | `punctuation.section.arguments.begin`, `.end` / `punctuation.separator.arguments` |
| grouping `(` `)` | `punctuation.section.group.begin`, `.end` |
| `[` `]` / slice `\|` | `punctuation.section.brackets.begin`, `.end` / `punctuation.separator.slice` |
| `;` | `punctuation.terminator.statement` |
| `$(` ... `)` blob: `$` / `(` `)` / `,` | `storage.type.string` / `punctuation.section.blob.begin`, `.end` / `punctuation.separator.blob` |
| non-hex blob value | `invalid.illegal.blob-value` |
| `not and or xor` | `keyword.operator.logical` |
| `=` / `+=` `-=` | `keyword.operator.assignment` / `keyword.operator.assignment.augmented` |
| `== != < <= > >=` / `<< >>` / `+ - * /` | `keyword.operator.comparison` / `keyword.operator.bitwise` / `keyword.operator.arithmetic` |
| `_` / `@` / `&` in expressions | `keyword.operator.concatenation` / `keyword.operator.address` / `keyword.operator.reference` |
| other identifiers | `variable.other` |

The keyword set mirrors the interpreter's tokenizer keyword table (`extended-min.min64x4`). Update this syntax when keywords are added there.
