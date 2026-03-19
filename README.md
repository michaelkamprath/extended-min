# Extended Min
Adds functionality to the orignal Min programming language for the Minimal 64x4 Home Computer by Carsten Herting. Based on CArsten's original work.

The primary enhancements to Min in this extended version includes:
- Support for various hardware expansion cards made for the Minimal 64x4, notablye the [multiplication accelerator](https://github.com/michaelkamprath/minimal-64x4-expansion-cards/tree/main/multiplier)
- Additions of constants to the language to avoid the use of "magic numbers" or "magic strings" (new `string` constant type).
- Support for the `long` 32-bit signed integer type.
- Introduction of explicit type casting to avoid silent value truncations.
- Ability print to not only the screen, but also the UART connection.


## Installing Extended Min
Extended Min must be built with [the BespokeASM assembler](https://github.com/michaelkamprath/bespokeasm) rather than the Minimal 64x4 assembler. Can use [the compile skill below](#using-the-compile-skill) or directly buil Extended Min with this command:

```bash
bespokeasm compile -c /path/to/slu4-minimal-64x4.yaml -n -p -t intel_hex extended-min.min64x4
```

The resulting Intel Hex output is then transfered to the Minimal 64x4 via the UART connection using its `receive` command. Once downloaded to the Minimal 64x4, pay attention to the start and stop address of the downloaded Intel Hex, then save the code to a program file on the Minimal 64x4 with the command `save XXXX YYYYY xmin`, where `XXXX` is the start address (typically hex 1000) and `YYYY` is the stop adress (something around hex 3B00). 

Alternatively, the Intel Hex compilation of most recent release of Extend Min from the releases in this repository on Github. Note that the `acc` variant is intended to be used with the [multiplier accelerator card](https://github.com/michaelkamprath/minimal-64x4-expansion-cards/tree/main/multiplier).

## Skills

This repository includes local Codex skills under [`skills/`](./skills).
They are intended to make common Extended Min workflows reusable and portable within this repo.

Current skills:

- [`skills/compile-min-64x4/`](./skills/compile-min-64x4): compile Minimal 64x4 assembly with a repo-local helper
- [`skills/optimize-size/`](./skills/optimize-size): optimize Extended Min branch/jump layout for size and speed

### Skill requirements

- `bespokeasm` installed and available on `PATH`
- either `curl` or `wget` available on `PATH`

The compile skill fetches the Minimal 64x4 BespokeASM configuration from the BespokeASM GitHub repository into `/tmp`, so the skills do not depend on host-specific absolute paths.

### Using the compile skill

Read:

- [`skills/compile-min-64x4/SKILL.md`](./skills/compile-min-64x4/SKILL.md)

Direct script usage:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4 -- -D USE_ACCELERATOR
```

### Using the optimize-size skill

Read:

- [`skills/optimize-size/SKILL.md`](./skills/optimize-size/SKILL.md)

Typical usage:

```bash
cp extended-min.min64x4 /tmp/extended-min.candidate.min64x4
skills/optimize-size/scripts/optimize_dual.sh /tmp/extended-min.candidate.min64x4 candidate
skills/optimize-size/scripts/collect_metrics.sh \
  /tmp/extended-min.candidate.min64x4 \
  /tmp/optimize-size.candidate.noacc.pretty \
  /tmp/optimize-size.candidate.acc.pretty
```

The optimize-size skill depends only on the repo-local compile skill and the standard host tools listed above.


## File Extension Convention
Any file ending in `*.min` should be runable by both Carsten's original Min and this Extended Min, which one exception: of the Min code performs a type change operation (e.g., assign an `int` value to a `char` type), Extended Min will throw an error given its new gaurds against silent value truncation. If that value truncation is omething you do want, introduce the explicite cast operation to the code, and make the file an `*.xmin` type as the orignal Min does not support type casting.

Any file ending in `*.xmin` is intende to be run in Extended Min only.

# Extended Min language documentation

This section is for writing Extended Min programs with fil extensions of `*.xmin`. For interpreter internals and the full grammar, see [`ARCHITECTURE.md`](./ARCHITECTURE.md).

## Program structure

Extended Min is line-oriented and indentation-sensitive.
Blocks may use either:

- a newline followed by deeper indentation
- a trailing `:` before that indented block

Examples:

```xmin
if x == 10:
  print("yes\n")
else:
  print("no\n")
```

```xmin
def add(int a, int b):
  return a + b
```

Comments start with `#`.
Multiple simple statements may be written on one line with `;`.

## Types

Extended Min supports three runtime scalar types:

- `char` : 8-bit unsigned value
- `int` : 16-bit signed value
- `long` : 32-bit signed value

Examples:

```xmin
char c = 65
int n = 1234
long big = 70000
```

## Casts
Unlike original Min, Extended Min does not silently narrow values across types.
Use an explicit cast when narrowing or widening intentionally.

Cast syntax is function-style:

- `char(expr)`
- `int(expr)`
- `long(expr)`

Examples:

```xmin
int n = 300
char c = char(n)
long big = long(n)
```

## Constants

Extended Min adds compile-time constants declared with `:=`.
These are resolved during tokenization and do not exist as runtime variables.

Supported constant declaration types:

- `int`
- `char`
- `long`
- `string`

Examples:

```xmin
int ScreenBase := 0x0080
long BigValue := 0x12345678
char LetterA := 65
string Banner := "HELLO"
```

Constant rules:

- a constant must be declared before it is used
- `string` is only a compile-time alias type, not a runtime variable type
- function-local constants are visible only within that function
- `string` constants are stored internally as length-tracked tokenized text, but when used as runtime `char` string values they behave as null-terminated byte sequences

## Variables, arrays, and fixed-address bindings

Normal variable definition:

```xmin
int score = 0
char name = "MIN"
```

Bind a variable to a fixed address with `@`:

```xmin
char io @ 0x00ff
io = 1
```

Allocate array/string-like storage by slicing the variable against itself:

```xmin
char text = text[|16]
int nums = nums[|10]
long bigs = bigs[|4]
```

Indexing and slicing:

```xmin
text[0] = "A"
print(text[0|5])
print(nums[i])
print(bigs[0])
```

Array-style storage works with all three runtime data types:

- `char`
- `int`
- `long`

Slice form is:

```text
var[start|end]
```

where `end` is exclusive.

## Expressions and operators

Arithmetic:

- `+`
- `-`
- `*`
- `/`
- unary `-`

Comparisons:

- `==`
- `!=`
- `<`
- `<=`
- `>`
- `>=`

Bitwise and logical-style operators:

- `not`
- `and`
- `or`
- `xor`
- `<<`
- `>>`

String/array concatenation:

- `_`

Examples:

```xmin
int x = 5 + 3 * 2
if x >= 10:
  print("big\n")

char msg = "HEL" _ "LO"
```

## Assignment forms

Extended Min supports:

- `=`
- `+=`
- `-=`

Examples:

```xmin
count = 10
count += 1
count -= 2
count += -10
```

Indexed assignment is also supported:

```xmin
buf[i] = 65
```

Notes:

- normal indexed and whole-value assignment work with `char`, `int`, and `long`
- the current fast `+=` / `-=` optimization is implemented for `char` and `int`, but not yet for `long`

## Control flow

Supported control-flow statements:

- `if`
- `elif`
- `else`
- `while`
- `break`
- `return`

Examples:

```xmin
while n > 0:
  print(n)
  print("\n")
  n -= 1
```

```xmin
if a == b:
  print("same\n")
elif a < b:
  print("less\n")
else:
  print("greater\n")
```

## Functions

Function definitions use `def`.
Parameters are typed, and may optionally be by-reference with `&`.

Examples:

```xmin
def add(int a, int b):
  return a + b

def clear_byte(char &dst):
  dst = 0
```

Calling a function:

```xmin
int total = add(10, 20)
```

Top-level `def` only:
- functions are defined at top level
- nested function definitions are not supported

## Printing and serial output

Three output functions share the same syntax and argument handling:

- `print(...)` — sends output to the screen
- `serial(...)` — sends output to the UART (serial port)
- `output(...)` — sends output to both the screen and the UART

Examples:

```xmin
print("score = ", score, "\n")
serial("debug: ", value, "\n")
output("log: ", msg, "\n")
```

Behavior:

- `char` payloads print as strings/byte sequences
- `int` values print in decimal
- `long` values print in decimal

## External calls and imports

Import another source file:

```xmin
use "mathlib.xmin"
```

Call a fixed machine-code address:

```xmin
call 0xf033
```

`call` requires an integer constant address.


## Small example

```xmin
int Step := 5
string Hello := "HELLO"

def bump(int n):
  n += Step
  return n

int value = bump(10)
print(Hello)
print("\n")
print(value)
print("\n")
```

