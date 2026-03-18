# Extended Min Interpreter Architecture

## Scope
`extended-min.min64x4` is a complete Min language runtime in one assembly file:
- command-line and RAM entry handling
- source loading (`use` import support)
- tokenization
- parsing and execution
- function/variable storage
- error reporting with source line reconstruction
- typed compile-time constants (`int`/`char`/`long` plus tokenizer-only `string` aliases), resolved during tokenization
- explicit cast syntax (`char(expr)`, `int(expr)`, `long(expr)`) for width control

This document describes how that runtime works internally.

## Top-Level Execution Flow
Entry point: `extended_min_start`.

Pipeline:
1. Initialize stack and parse command line (`_SkipSpace`).
2. `Loader` reads source text into memory (`0x8000+`), including recursive `use "..."` files.
3. `Tokenizer` compiles source text into a compact token stream appended after source text.
4. Runtime state is initialized (`z_nextcall`, `z_nextvar`, `z_sp`, `z_pc`, flags).
5. `Block` executes the tokenized program.
6. Control returns to OS prompt.

Error path:
- Runtime errors jump to `Error`, which re-runs `Tokenizer` up to the failing token address (`g_stop`) to recover exact source position.
- `SourceError` prints filename, error text, line number, and line excerpt, then exits to prompt.

## Memory Model
From comments and constants in this file:

- `0x1000..0x3f7f`: interpreter code + global state
- `0x3f80..0x3fff`: long-lhs spill stack
- `0x8000..0xd9ff`: source text (`file`) with tokenized stream appended after loaded text
- `0xda00..0xdfff`: expression/variable runtime data stack (`firstsp..endsp`)
- `0xe000..0xe2ff`: call dictionary (`firstcall`, 3-byte entries)
- `0xe300..0xebff`: variable dictionary (`firstvar`, 9-byte entries)
- `0xec00..0xecff`: source-vector page (`firstsrc`), used for up to 5 fixed 22-byte entries
- `0xed00`: page-aligned source-vector guard (`endsrc`)
- `0xff00..0xffff`: CPU fast page + hardware stack (managed by CPU push/pop and subroutine calls)

Zero page (`MIN_ZERO_PAGE`, `0x0030..0x007f`) holds nearly all hot interpreter state (`z_pc`, `z_sp`, `z_type`, `z_cnt`, pointers, math registers), plus:
- a tiny `getVar` hot cache (`z_vcache_*`)
- function-call parser cursors (`z_fun_argpc`, `z_fun_parpc`)

OS zero-page interface block (`ZERO_PAGE_OS`) uses the pointer layout:
- `z_PtrA` at `0x0080`
- `z_PtrB` at `0x0083`
- `z_PtrC` at `0x0086` (reserved OS pointer slot)
- `z_PtrD` at `0x0089`

## Core Runtime Data Structures
Call dictionary entry (3 bytes, newest-first lookup):
1. `call_id`
2. `pc_lsb`
3. `pc_msb`

Variable dictionary entry (9 bytes, newest-first lookup):
1. `var_id`
2. `sub` (scope marker; `0xff` used for global)
3. `type` (`1=char`, `2=int`, `4=long`)
4. `cnt_lsb`
5. `cnt_msb`
6. `ptr_lsb`
7. `ptr_msb`
8. `max_lsb`
9. `max_msb`

Source vector entry (22 bytes):
1. source pointer LSB
2. source pointer MSB
3. filename bytes (null-terminated, fixed entry budget)

Expression result contract (global state):
- `z_sp`/`z_spi`: pointer to expression payload in stack memory
- `z_cnt`: number of elements
- `z_type`: element type (`char`, `int`, or `long`)
- payload is contiguous and null-terminated for byte-oriented string usage

## Loader and Import Resolution
`Loader` supports two modes:
- `min <file>`: load named file via `LoadFileTo`
- `min`: interpret text already in RAM at `0x8000`

`LoadFileTo` uses `_FindFile` + bank-aware `OS_FlashA` to copy file bytes to `z_PtrD`.
On successful load, it explicitly writes a trailing `\0` byte in RAM before returning.
The loader now treats `firstsp` (`0xda00`) as the exclusive source/token upper bound and aborts with `Out of RAM` if imported source would cross into the runtime stack.

Import resolution:
- Loader performs a raw scan for `use "..."` and appends each file into source memory.
- Max imported-source tracking is implemented via source-vector pointer progression.
- `Tokenizer` later skips `use` lines so imports affect loading, not runtime statements.
- Tokenization walks the source-vector from newest to oldest entry, so imported modules are tokenized before their importers.
- Tokenizer output is guarded against `firstsp` / `source_top` to avoid source/token stream overwrite of the runtime stack.

## Tokenizer Architecture
`Tokenizer` is a single-pass compiler from source text to compact tokens.

Important behavior:
- Removes comments (`#...`) and irrelevant whitespace.
- Converts indentation into single-byte markers.
- Encodes numbers and operators into compact token forms.
- Interns identifiers into an item table so runtime uses IDs, not names.
- Constants extension: recognizes typed constant declarations and resolves constant uses into literal tokens during tokenization.

Token forms:
- `0xff`: end marker
- `0xe0..0xfe`: indentation markers
- `0xd0 <lsb> <msb>`: 16-bit integer constant
- `0xd1 <b0> <b1> <b2> <b3>`: 32-bit long constant
- relational/operator tokens:
  - `<`=`0xd2`, `==`=`0xd3`, `!=`=`0xd4`, `<=`=`0xd5`, `>=`=`0xd6`, `>`=`0xd7`
  - `not`=`0xd9`, `and`=`0xda`, `or`=`0xdb`, `xor`=`0xdc`
  - `<<`=`0xdd`, `>>`=`0xde`
- keyword single-byte statement tokens:
  - `if/elif/else/while/break/def/return/char/int/long/call/print/serial/output` -> `'I','F','E','W','B','D','R','1','2','4','C','P','Q','O'`
- identifiers:
  - variables emit `'V' <id>`
  - function names emit `'S' <id>`
- fast assignment forms:
  - `+=` -> `'a'`
  - `-=` -> `'s'`

Tokenizer constraints:
- identifier length max is 13 characters
- indentation must be even-space aligned and <= 30 levels
- var and call IDs are capped below `0xe0` to avoid collision with indent token range
- commas, semicolons, and colons are treated as optional separators and omitted from token output

Typed-constant rules (tokenizer-time):
- Declaration forms:
  - `int Name := <numeric-literal | const-name>`
  - `long Name := <numeric-literal | const-name>`
  - `char Name := <numeric-rhs | string-literal | string-const-name>`
  - `string Name := <string-literal | string-const-name>`
- Numeric `const-name` RHS must reference a previously declared numeric constant (no forward references).
- String `const-name` RHS must reference a previously declared string constant (no forward references).
- Scope:
  - declarations at top level are global and visible after declaration
  - declarations inside a function are function-local and visible only within that function after declaration
  - local constants may shadow global constants
- Resolution:
  - constant identifier use is replaced at tokenization time
  - numeric constants emit `0xd0 <lsb> <msb>` or `0xd1 <b0> <b1> <b2> <b3>` according to stored width
  - string constants emit the same quoted token bytes as inline source string literals
- Numeric literal policy is consistent across tokenizer literal handling and constant-declaration parsing:
  - hex literals use lowercase `0x` prefix only
  - hex digits may be `0-9`, `a-f`, or `A-F`
  - bare `0x` is valid and means zero
  - parsing accumulates into an internal wider buffer, then current callers reject values above the requested width
  - unary minus remains expression syntax outside literal parsing
- No runtime constant table is used; constants do not consume var-dictionary entries.
- During tokenization, numeric constant metadata is stored in the call-dictionary region (`0xe000..0xe2ff`) and string constant metadata is stored in the var-dictionary region (`0xe300..0xebff`) before runtime dictionary initialization.
- `string` is not a runtime type token. It is recognized only by the constant-declaration prelude and expands to char-string literal payload at substitution sites.

Explicit cast syntax is implemented:
- Use cast-function syntax, not operator variants:
  - `char(expr)` truncates to the low 8 bits
  - `int(expr)` truncates to the low 16 bits
  - `long(expr)` widens narrower scalar values to 32 bits
- Rationale:
  - `==` is already consumed as relational equality tokenization.
  - `@` already has variable-address declaration semantics (`type id @ expr`).
  - function-style cast avoids introducing new assignment operators and keeps parser changes localized.

## Parser and Evaluator
The interpreter is recursive-descent over token stream (`z_pc`):

- `Factor`:
  - constants, variables, references (`&`), string literals, function calls, parenthesized expressions
  - built-in cast forms `char(expr)`, `int(expr)`, and `long(expr)`
  - array/slice-like element extraction via `[ ... ]` and optional `|`
- `Term`: `*` and `/`
- `BaseExpr`: unary minus, `+`, `-`
- `RelExpr`: `<`, `==`, `!=`, `<=`, `>=`, `>`
- `Expr`: `not`, `and`, `or`, `xor`, `<<`, `>>`
- `CompExpr`: concatenation `_` with type checking
- `TypedCompExpr`: enforces requested type, including scalar cast rules

Explicit cast handling:
- `Factor` recognizes `char(expr)`, `int(expr)`, and `long(expr)` as built-in cast forms.
- `char(expr)` truncates to byte, `int(expr)` truncates to word, and `long(expr)` widens narrower scalar values to a 32-bit long.
- Current long operator support includes:
  - unary `-`
  - `+`, `-`
  - `*`, `/`
  - `not`
  - `and`, `or`, `xor`
  - `<<`, `>>`
  - relational comparisons `<`, `==`, `!=`, `<=`, `>=`, `>`
- Mixed-width scalar expressions widen to `long` when either operand is `long`.

Math helpers:
- `int_mul`, `int_div`, `int_lsl`, `int_lsr`, `int_tostr`
- `PrintLongZC` for signed decimal `print(long)`
- long helper group for add/sub/mul/div/neg/not/bitwise/shift/compare operations

Expression-stack invariants:
- every expression leaves a normalized descriptor in (`z_sp`, `z_cnt`, `z_type`)
- `char` payloads are byte arrays; `int` payloads are 2-byte little-endian elements; `long` payloads are 4-byte little-endian elements
- byte-oriented payloads are null-terminated to support direct string printing

CPU Stack Conventions (Milestone 4):
- The CPU hardware stack (managed by `PHS`/`PLS` and `JPS`/`RTS`) is used for saving intermediate expression results during mixed-width arithmetic evaluation.
- **16-bit temporary save/restore convention:**
  - Push order: LSB first, then MSB
  - After push, stack layout (growing downward): `[MSB, LSB]` with MSB on top
  - Pop order: MSB first, then LSB (reverse of push, due to LIFO)
  - Example: `LDZ z_A+0 PHS LDZ z_A+1 PHS` to save; `PLS STZ z_A+1 PLS STZ z_A+0` to restore
- **32-bit temporary save/restore convention:**
  - Push order: byte 0 (LSB), byte 1, byte 2, byte 3 (MSB)
  - After push, stack layout (growing downward): `[byte3, byte2, byte1, byte0]` with byte 3 on top
  - Pop order: byte 3, byte 2, byte 1, byte 0
  - Example: `LDZ z_E+0 PHS LDZ z_E+1 PHS LDZ z_E+2 PHS LDZ z_E+3 PHS` to save
  - Example: `PLS STZ z_E+3 PLS STZ z_E+2 PLS STZ z_E+1 PLS STZ z_E+0` to restore
- **JPS/RTS interaction:**
  - Functions that pop values directly from the CPU stack (like `PopIntLhsHiLoToLongE`) must account for the return address being pushed by `JPS` before the function body executes.
  - Such functions must either: (1) save/restore the return address around their pops, or (2) be inlined rather than called via `JPS`.
- **Expression storage:**
  - All expression results are stored on the expression stack (zero-page `z_sp` region), not the CPU stack.
  - The CPU stack is only used for temporary saves during complex expression evaluation (e.g., when evaluating `a + f(b)` where `a` must be saved while `f(b)` executes).

## Statements and Control Flow
Dispatch:
- `Statement` handles block-level keywords (`if`, `while`, `def`) and delegates other forms to `SimpleLine`.
- `SimpleLine` handles assignments, `break`, function call, `return`, declarations, `call`, `print`, `serial`, `output`.

Blocks:
- `Block` creates scope by saving/restoring `z_nextvar` and stack pointers.
- `FastBlock` is function-specific and skips extra save/restore because call frame already owns that responsibility.
- `if` and `while` truthiness now use width-aware scalar evaluation, so raw `long` conditions are valid.

Halting flags (`z_halt` bits):
- bit 0: block-end detected (indent decrease)
- bit 1: `break`
- bit 2: `return`

## Functions, Parameters, and Return
Definition:
- `DefStmt` registers function ID and body PC into call dictionary.
- Valid only at top-level (not nested and not indented).

Call:
- `FunctionCall`:
  - creates call frame (stack/scope snapshots)
  - enforces a guarded call-depth ceiling (`call_depth_max`) before frame setup to avoid hard CPU-stack lockups
  - parses callee parameter spec from function definition token stream
  - evaluates caller arguments and binds to callee locals
  - supports by-value and by-reference (`&`) parameters
  - current scalar widths in bound locals are `char=1`, `int=2`, and `long=4`
  - uses dedicated parser cursors (`z_fun_argpc`, `z_fun_parpc`) to switch between caller-argument and callee-parameter streams
  - preserves those cursors on nested calls
  - executes callee via `FastBlock`
  - copies returned payload back to caller stack when `return` is used

Lookup:
- `getCall` searches newest-first with linear scan.
- `getVar` first checks a 1-entry cache keyed by `(var_id, z_sub, z_nextvar)`; on miss it falls back to newest-first linear scan.
- Variable shadowing works across scopes; same-scope variable redeclaration is rejected (`Duplicate variable name`).

## Variable Semantics
Declarations (`char`/`int`/`long`) are handled by `VarDefinition`.

Modes:
- local storage from runtime stack (`z_sp`) with tracked `cnt` and `max`
- absolute-address binding via `@ <expr>` for MMIO or fixed memory
- optional initialization with typed expression enforcement

Assignment (`VarAssignment`):
- full assignment (`=`)
- indexed assignment with bounds checks
- whole-value assignment with rhs-count bounds checks against variable capacity
- optimized `+=` / `-=` for constant RHS token form

Reference and absolute-address interplay:
- `&var` and `&var[...]` produce pointers and set reference metadata (`z_refset`, `z_refcnt`)
- `type name @ <expr>` consumes the computed address as storage pointer
- when used with reference metadata, `@` declarations can inherit element counts from referenced ranges

Constants are separate from variable semantics:
- `:=` declarations are compile-time only and are consumed by the tokenizer.
- They cannot be mutated at runtime because they are not runtime variables.

## Error Handling Strategy
Two-stage reporting:
1. Runtime/parsing detects failure and jumps to `Error` or `SourceError`.
2. `Error` retokenizes to map token PC back to source line and file.

This design keeps normal execution fast while still providing source-level diagnostics.

Notable diagnostics now include:
- `Duplicate constant name` for same-scope constant redefinition.
- `Duplicate variable name` for same-scope variable redeclaration.
- `Value overflow` when a value assigned to `char` does not fit `0..255` (constants and typed assignments).
- `Call stack overflow` when recursion/call depth exceeds the guarded runtime limit.

## Design Notes and Practical Limits
- Core runtime declaration types in this file are `char`, `int`, and `long`.
- `string`-alias constant declarations are tokenizer-only sugar and do not add a runtime type tag.
- Dictionaries are fixed-size memory regions; `getCall` is linear scan, while `getVar` adds a tiny hot cache in front of linear scan.
- Runtime memory checks guard expression-stack overflow and index range errors, and `FunctionCall` guards hardware call-stack depth.
- Import loading is source-text driven (`use "..."`) before interpretation.
- The interpreter is compact and fast because tokenization removes most string parsing from runtime.
- `print(...)` emits char payloads as strings, and int payloads as decimal values joined with `_`.
- `serial(...)` behaves identically to `print(...)` but routes all output to the UART via `OUT`/`_SerialWait` instead of screen output.
- `output(...)` behaves identically to `print(...)` but sends output to both the screen and the UART.
- `call <const_addr>` requires a tokenized integer constant address, making external API calls explicit and low-overhead.
- Multiple function groups are page-aligned with `.align` so fast-branch instructions can remain valid.

## Min Language EBNF Description
The following EBNF is a useful baseline reference for Min syntax.
This section reflects the currently implemented constants syntax.

```text
---------------------------------------------------------------------------------------
Extended Backus-Naur-Form (EBNF) of MIN written by Carsten Herting (slu4) Mar 17th 2023
---------------------------------------------------------------------------------------

letter      = 'a' | ... | 'z' | 'A' | ... | 'Z'
digit       = '0' | ... | '9'
hexdigit    = digit | 'a' | ... | 'f' | 'A' | ... | 'F'
rel-op      = '==' | '!=' | '<=' | '<' | '>=' | '>'
add-op      = '+'  | '-'
mul-op      = '*'  | '/'
logic-op    = 'and' | 'or' | 'xor' | '>>' | '<<'
type        = 'int' | 'char' | 'long'
const-type  = 'int' | 'char' | 'string' | 'long'
identifier  = letter, { letter | digit }
character   = ? any ASCII character ?
NEWLINE     = '\n'
ENDMARKER   = '\0'
IND++       = ? increase target indentation (start with -1) ?
IND--       = ? decrease target indentation (start with -1) ?
NOIND       = ? check if indentation equals zero ?
EQIND       = ? check if indentation equals target ?

const-num-rhs = constant | identifier                                   (* identifier must name a previously declared numeric constant *)
string-literal = '"', { character }, '"'
const-string-rhs = string-literal | identifier                          (* identifier must name a previously declared string constant *)
const-cast-rhs = ( 'char' | 'int' | 'long' ), '(', const-num-rhs, ')'  (* explicit constant-width control *)
const-rhs   = const-num-rhs | const-cast-rhs | const-string-rhs
const-decl  = const-type, identifier, ':=', const-rhs
cast-func   = ( 'char' | 'int' | 'long' ), '(', expr, ')'              (* explicit width control *)
signed-constant = [ '+' | '-' ], constant

program     = { statement }, ENDMARKER
block       = simple-line
            | NEWLINE, IND++, { statement }, IND--
statement   = { NEWLINE }, EQIND, simple-line
            |   { NEWLINE }, EQIND, 'if', expr, [':'], block,
              { { NEWLINE }, EQIND, 'elif', expr, [':'], block },
              [ { NEWLINE }, EQIND, 'else', [':'], block ]
            | { NEWLINE }, EQIND, 'while', expr, [':'], block
            | { NEWLINE }, NOIND, 'def', identifier, '(', { type, ['&'], identifier, [','] }, ')', [':'], block
            | { NEWLINE }, EQIND, const-decl
            | { NEWLINE }, NOIND, 'use', '"', { character }, '"'          (* import another file*)
simple-line = simple-stmt, [';'], { simple-stmt, [';'] }
simple-stmt = type, identifier, ['@', expr ], ['=', comp-expr ]           (* variable definition *)
            | identifier, ['[', expr, ']'], '=', comp-expr                (* assignment *)
            | identifier, ['[', expr, ']'], '+=', signed-constant         (* fast add *)
            | identifier, ['[', expr, ']'], '-=', signed-constant         (* fast sub *)
            | identifier, '(', { comp-expr, [','] }, ')'                  (* function call *)
            | 'return', [ comp-expr ]
            | 'break'
            | 'call', constant                                             (* external call to fixed address *)
            | 'print', '(', { comp-expr, [','] }, ')'
            | 'serial', '(', { comp-expr, [','] }, ')'
            | 'output', '(', { comp-expr, [','] }, ')'

constant    = '0x', { hexdigit }                                          (* int HEX number; bare 0x means zero *)
            | digit, { digit }                                            (* int DEC number *)
factor      = constant
            | cast-func
            | '(', expr, ')'                                              (* result of braced expression *)
            | 'key', '(', ')'                                             (* MINIMAL 64 uses API function instead *)
            | '"', { character }, '"'                                     (* char string *)
            | ['&'], identifier, ['[', [ expr ], ['|', [ expr ] ], ']']   (* [address of] variable [elements] *)
            | identifier, '(', { comp-expr, [','] }, ')'                  (* return value of function call *)
term        = factor, { mul-op, factor }
base-expr   = ['-'], term, { add-op, term }
rel-expr    = base-expr, { rel-op, base-expr }
expr        = ['not'], rel-expr, { logic-op, rel-expr }
comp-expr   = expr, {'_', expr }                                          (* compound expressions of same data type *)
```

## EBNF vs This Interpreter
The `extended-min.min64x4` implementation differs from the baseline EBNF in a few important places:

- `call` is stricter than the EBNF shorthand implies: runtime requires a tokenized 16-bit integer constant immediately after `call`. General expressions and long constants are rejected.
- `use "file"` is processed by the loader pre-pass and skipped by the tokenizer; it is not executed as a runtime statement token.
- `key()` is not a core keyword in this interpreter file; keyboard/library behavior is expected via imported Min libraries and/or `call` integration.
- Hex constants require lowercase `0x` prefix and accept uppercase or lowercase hex digits.
- Constants behavior is tokenizer-time substitution, so declarations do not exist as runtime statements.
- Long arithmetic now covers add/sub/mul/div/bitwise/shift/compare operations.
- Constants are declaration-order dependent (no forward references) because tokenization is single-pass.
- Function-local constants use function scope (not block scope), with local-first name resolution then global fallback.
- `string` declarations are tokenizer-only aliases for char-string literal token payload and do not exist in runtime type dispatch.
- Cast syntax is `char(expr)` (function-style), not C-style `(char)expr`, and not alternate assignment operators like `==` or `@=`.
