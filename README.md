# Extended Min
Adds functionality to the original Min programming language for the [Minimal 64x4 Home Computer by Carsten Herting](https://github.com/slu4coder/Minimal-64x4-Home-Computer/tree/main). Based on Carsten's original work.

Two target machines are supported from parallel sources:

- `extended-min.min64x4` — the original Minimal 64x4
- `extended-min.min64x4r` — the Minimal 64x4 Redux

The two files are kept in sync; the only intended differences are the Redux
instruction-set renames (the A-store family `STZ/STT/STB/STR/STS` is named
`SDZ/SDT/SDB/SDR/SDS` on the Redux), a handful of branch-form differences
required by the Redux fast-branch page rule, and the ISA `#require` pragmas.
Functional changes must be applied to both files.

The primary enhancements to Min in this extended version include:
- Support for various hardware expansion cards made for the Minimal 64x4, notably the [multiplication accelerator](https://github.com/michaelkamprath/minimal-64x4-expansion-cards/tree/main/multiplier)
- Additions of typed compile-time constants to avoid the use of magic numbers and repeated string literals.
- Support for the `long` 32-bit signed integer type.
- Introduction of explicit type casting to avoid silent value truncations.
- Ability to print to not only the screen, but also the UART connection.
- Sized buffer declarations (`char buf[64]`, `int table[N]`) with optional comma-separated initializers.
- Compact hex byte blobs for large `char` data tables.
- Built-in query functions `len()` and `sizeof()` for inspecting variable element counts and buffer capacity.
- Dynamic list operations `append()`, `pop()`, and `empty()` for using sized buffers as lists.


## Installing Extended Min
Extended Min must be built with [the BespokeASM assembler](https://github.com/michaelkamprath/bespokeasm) rather than the Minimal 64x4 assembler. You can use [the compile skill below](#using-the-compile-skill) or directly build Extended Min with this command:

```bash
bespokeasm compile -c /path/to/slu4-minimal-64x4.yaml -n -p -t intel_hex extended-min.min64x4
```

For the Minimal 64x4 Redux, build the Redux source against the Redux instruction-set configuration instead:

```bash
bespokeasm compile -c /path/to/slu4-minimal-64x4-redux.yaml -n -p -t intel_hex extended-min.min64x4r
```

The resulting Intel Hex output is then transferred to the Minimal 64x4 via the UART connection using its `receive` command. Once downloaded to the Minimal 64x4, pay attention to the start and stop address of the downloaded Intel Hex, then save the code to a program file on the Minimal 64x4 with the command `save XXXX YYYYY xmin`, where `XXXX` is the start address (typically hex 1000) and `YYYY` is the stop address (something around hex 3B00). 

Alternatively, use the Intel Hex compilation of [the most recent release of Extended Min](https://github.com/michaelkamprath/extended-min/releases) from the releases in this repository on GitHub. Note that the `acc` variant is intended to be used with the [multiplier accelerator card](https://github.com/michaelkamprath/minimal-64x4-expansion-cards/tree/main/multiplier).

## Skills

This repository includes local Codex skills under [`skills/`](./skills).
They are intended to make common Extended Min workflows reusable and portable within this repo.

Current skills:

- [`skills/compile-min-64x4/`](./skills/compile-min-64x4): compile Minimal 64x4 assembly with a repo-local helper
- [`skills/optimize-size/`](./skills/optimize-size): optimize Extended Min branch/jump layout for size and speed

### Skill requirements

- `bespokeasm` installed and available on `PATH`
- either `curl` or `wget` available on `PATH`

The compile skill fetches the Minimal 64x4 (or Minimal 64x4 Redux, for `*.min64x4r` sources) BespokeASM configuration from the BespokeASM GitHub repository into `/tmp`, so the skills do not depend on host-specific absolute paths.

### Using the compile skill

Read:

- [`skills/compile-min-64x4/SKILL.md`](./skills/compile-min-64x4/SKILL.md)

Direct script usage:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4 -- -D USE_ACCELERATOR
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4r
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4r -- -D USE_ACCELERATOR
```

### Using the `optimize-size` skill

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
Any file ending in `*.min` should be runnable by both Carsten's original Min and this Extended Min, with one exception: if the Min code performs a type change operation (e.g., assign an `int` value to a `char` type), Extended Min will throw an error given its new guards against silent value truncation. If that value truncation is something you do want, introduce the explicit cast operation to the code, and make the file an `*.xmin` type as the original Min does not support type casting.

Any file ending in `*.xmin` is intended to be run in Extended Min only.

# Extended Min language documentation

This section is for writing Extended Min programs with file extensions of `*.xmin`. For interpreter internals and the full grammar, see [`ARCHITECTURE.md`](./ARCHITECTURE.md).

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

- `char` : 8-bit byte value (see [char semantics](#char-values-assignment-and-reads) below)
- `int` : 16-bit signed value (`-32768` to `32767`)
- `long` : 32-bit signed value (`-2147483648` to `2147483647`)

Examples:

```xmin
char c = 65
int n = 1234
long big = 70000
```

### Char values: assignment and reads

A `char` stores one byte. Assignment accepts any value from `-128` to `255` and
stores the low byte; values outside that range raise "Value overflow".
Equality (`==`, `!=`) with a `char` on either side compares the low 8 bits of
both operands, so a stored byte matches whichever notation you prefer —
unsigned decimal, hex, or signed:

```xmin
char c = 224          # stores byte 0xE0; char c = 0xe0 or char c = -32 store the same byte
if c == 224:          # true
if c == 0xe0:         # true
if c == -32:          # true
if c != 225:          # true
```

Ordering (`<`, `<=`, `>`, `>=`), arithmetic, and the `int()` cast treat chars
as signed `-128..127` ("C-style", matching original Min), so `c < 0` is true
for any byte `>= 0x80`, and `int(c)` for the byte `0xE0` yields `-32`. Named
`char` constants (`:=`) accept `0..255` only.

**Chars in arithmetic.** When a `char` appears in an arithmetic expression it
is read as its *signed* value, and the result of any `+`/`-`/`*`/`/` is an
`int`. So arithmetic on high-bit bytes goes negative, and printing the result
shows a decimal number, not a character:

```xmin
char v = 224          # stores byte 0xE0, reads as -32 in arithmetic
print(v)              # prints the CHARACTER for byte 0xE0 (chars print as text)
print(v - 5)          # prints -37  (int result: -32 - 5)
print(int(v))         # prints -32
```

For unsigned byte math, mask the `int` result back to its low byte:

```xmin
print((v - 5) and 0xff)      # prints 219  (224 - 5, as an unsigned byte)
if char(v - 5) == 219:       # true: char() truncates to byte 0xDB,
  print("byte match\n")      # which byte-wise-equals 219
```

Rule of thumb: the byte-wise behavior applies **only to `==` and `!=`**;
everything else sees a signed value.

### Numeric literal widths

- Decimal literals that do not fit a signed 16-bit `int` (`32768` and up)
  automatically become `long` constants.
- Hex literals up to 16 bits (`0x0` through `0xffff`) are `int` bit patterns —
  so addresses (`@ 0xFE00`) and masks keep `int` type; note `0x8000..0xffff`
  read back as negative ints.
- Hex literals wider than 16 bits (e.g. `0x12345678`) become `long` constants.

```xmin
int mask = 0xff         # 255
int mmio = 0xfe00       # int bit pattern (reads as -512)
long big = 40000        # decimal >= 32768 promotes to long
long word = 0x12345678  # hex wider than 16 bits is long
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

Examples:

```xmin
int ScreenBase := 0x0080
long BigValue := 0x12345678
char LetterA := 65
char Banner := "HELLO"
```

Constant rules:

- a constant must be declared before it is used
- `char` constants may hold either a numeric byte value or a string-like byte sequence
- function-local constants are visible only within that function
- string-like `char` constants are stored internally as length-tracked tokenized text, but when used as runtime `char` values they behave as null-terminated byte sequences

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

### Sized buffers

Declare a buffer with a fixed capacity using `[N]`:

```xmin
char buf[64]
int table[10]
```

The size expression `N` is evaluated at runtime, so variables are allowed:

```xmin
int sz = 20
char data[sz]
```

Sized buffers can be combined with an initializer. The buffer capacity is `N`; the initial element count comes from the initializer:

```xmin
char header[16] = 0x44, 0x2a, 0x0e
int lookup[8] = 10, 20, 30
```

For dense binary `char` data, use a compact hex byte blob. The blob can span physical source lines and is tokenized as raw bytes instead of one integer expression per value:

```xmin
char data[8] = $(
  0xc9, 0x1b, 0x2e, 0x2c,
  0x3d, 0x1d, 0x86, 0x30
)
```

Blob values must be hex bytes (`0x00` through `0xff`). Whitespace, comments, physical newlines, and commas are allowed inside the blob. After initialization, `data` is a normal `char` buffer, so indexing, slicing, `len(data)`, and by-reference calls work normally.

The blob expression itself is always a `char` byte sequence. To view the same bytes as `int` or `long` elements, declare the blob as `char` and bind a typed variable to its address with `@ &name`. Multi-byte values are little-endian:

```xmin
char rawWords = $(
  0x34, 0x12,   # 0x1234
  0x78, 0x56    # 0x5678
)
int words[2] @ &rawWords
print(words[0], " ", words[1], "\n")

char rawLongs = $(
  0x78, 0x56, 0x34, 0x12
)
long values[1] @ &rawLongs
```

The typed view aliases the same memory; it does not copy or repack bytes. Keep the raw `char` buffer alive for as long as the typed view is used, and make sure the byte count matches the typed element count.

Writing beyond the initial count but within the declared capacity is valid:

```xmin
char buf[64] = "HI"
buf[10] = 0x41
```

A "Buffer overflow" error is raised if the initializer has more elements than the declared size.

Sized buffers also work with fixed-address bindings:

```xmin
char mmio[8] @ 0xFE00
```

### Comma-separated initializers

Commas may be used as element separators in any variable initializer, as an alternative to the `_` concatenation operator:

```xmin
char rgb = 0x10, 0x20, 0x30
int coords = 100, 200, 300
char msg = "HEL", "LO"
```

Commas and `_` may be mixed freely:

```xmin
int data = 1 _ 2, 3 _ 4
```

In `print()`, `serial()`, `output()`, and function call argument lists, commas remain optional separators between distinct arguments (not concatenation).

### Legacy array allocation

Array-like storage can also be allocated by slicing the variable against itself (the original Min idiom):

```xmin
char text = text[|16]
int nums = nums[|10]
```

The `[N]` sized buffer syntax above is the preferred form for new code.

### Indexing and slicing

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

### Built-in query functions

`len(var)` returns the current element count of a variable:

```xmin
char msg = "Hello"
print(len(msg))             # prints 5

char buf[64] = 1, 2, 3
print(len(buf))             # prints 3 (initialized count)
```

`sizeof(var)` returns the buffer capacity (allocated size) of a variable:

```xmin
char buf[64] = 1, 2, 3
print(sizeof(buf))          # prints 64 (capacity)
print(len(buf))             # prints 3 (current count)
```

A **sized** variable is one declared with `[N]` (e.g., `char buf[64]`). The capacity (`sizeof`) is the declared size `N`, which may be larger than the current element count (`len`). An **unsized** variable has no `[N]` (e.g., `char msg = "Hello"` or `int x = 42`). Its capacity equals its element count, so `sizeof(var) == len(var)`.

### Dynamic list operations

Sized buffers can be used as dynamic lists with `append`, `pop`, and `empty`:

```xmin
int stack[32]
empty(stack)

append(stack, 10)
append(stack, 20)
append(stack, 30)
print(len(stack))           # prints 3

int top = pop(stack)
print(top)                  # prints 30
print(len(stack))           # prints 2

empty(stack)
print(len(stack))           # prints 0
print(sizeof(stack))        # prints 32 (capacity unchanged)
```

- `append(var, expr)` — writes the value at position `len(var)` and increments the count. Raises "Buffer overflow" if the buffer is full.
- `pop(var)` — returns the last element and decrements the count. Raises "Buffer empty" if the count is zero.
- `empty(var)` — sets the count to zero without changing the capacity or stored data.

Indexed assignment (`var[i] = x`) does **not** update the element count. Only `append`, `pop`, `empty`, and whole-value assignment (`var = expr`) modify it.

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
- the current fast `+=` / `-=` optimization is implemented for `char`, `int`, and `long`

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

Note that arithmetic always produces an `int` (or `long`) result, so
`print(c)` prints a character while `print(c + 0)` or `print(c - 5)` prints a
signed decimal number — see
[chars in arithmetic](#char-values-assignment-and-reads).

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
char Hello := "HELLO"

def bump(int n):
  n += Step
  return n

int value = bump(10)
print(Hello)
print("\n")
print(value)
print("\n")
```
