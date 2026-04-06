# Extended Min Agent Guide

This directory contains the `Extended Min` interpreter for the Minimal 64x4 TTL computer.

The main source file is:

- `extended-min.min64x4`

The architecture and language behavior are described in:

- `ARCHITECTURE.md`

Any agent working in this directory should read `ARCHITECTURE.md` before making non-trivial changes.

## What This Codebase Is

`extended-min.min64x4` is a full interpreter in one assembly file. It includes:

- command-line entry
- source loading with `use "..."` import support
- tokenization
- parsing
- runtime evaluation
- function and variable dictionaries
- source-aware error reporting
- compile-time numeric and string constants
- `long` support
- explicit cast support

This is not a small library. Most changes affect multiple phases of the interpreter.

## Key Directories

- `extended-min.min64x4`: the interpreter implementation
- `ARCHITECTURE.md`: required reference for runtime structure and memory model
- `lib/`: Min/XMin helper libraries used by interpreted programs
- `software/`: sample programs
- `tests/`: regression and feature tests
- `skills/compile-min-64x4/`: repo-local BespokeASM compile helper skill
- `skills/optimize-size/`: local tooling and workflow for branch/jump size optimization

Important file-extension convention:

- `*.min`: intended to remain compatible with original Min where practical
- `*.xmin`: Extended Min only

## Development Priorities

Priority order for this codebase:

1. correctness on hardware
2. memory-map safety
3. interpreter size
4. runtime speed
5. tokenizer speed

Do not trade correctness or memory safety for a small optimization.

## Build and Validation

This code is assembled with BespokeASM, not the original Minimal 64 assembler.

Typical compile command in order to produce the Intel Hex formatted byte code to transfer the Minimal 64x4 via it's `receive` command:

```bash
bespokeasm compile -c /path/to/slu4-minimal-64x4.yaml -n -p -t intel_hex extended-min.min64x4
```

In order to build Extended Min to take advatange of accerator cards tyhat have been designed for the Minimal 64x4, use:

```bash
bespokeasm compile -c /path/to/slu4-minimal-64x4.yaml -n -p -t intel_hex -D USE_ACCELERATOR extended-min.min64x4
```

If available, use the local compile helper workflow instead of hand-rolling commands.

Repo-local compile helper:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4 -- -D USE_ACCELERATOR
```

That helper fetches the Minimal 64x4 BespokeASM config from the BespokeASM GitHub repo into `/tmp` and avoids depending on host-specific absolute paths.

Both of these builds should compile after meaningful changes:

- default build
- `USE_ACCELERATOR` build

Runtime execution cannot normally be done in a generic local environment. `xmin` runs on the Minimal 64x4 hardware. Compile validation is necessary but not sufficient.

## What To Read Before Editing

For any non-trivial work, read these first:

1. `ARCHITECTURE.md`
2. the relevant routine in `extended-min.min64x4`
3. the closest matching tests in `tests/`

If touching lookup speed, read:

- `getVar`
- `getCall`
- zero-page cache state

If touching expression behavior, read:

- `Factor`
- `Term`
- `BaseExpr`
- `RelExpr`
- `Expr`
- `CompExpr`

If touching constants or tokenization, read:

- `Tokenizer`
- `ConstLinePrelude`
- `TryConstDecl`
- `ConstSubstitute`

## Memory Map Rules

The current memory model is intentional and tightly constrained.

At time of writing:

- `MIN_INTERPRETER`: `0x1000..0x3fff`
- `MIN_LHS_SPILL`: `0xed00..0xed7f`
- source + token stream: `0x8000..0xcfff`
- tokenizer items dict / runtime stack (shared): `0xd000..0xdfff`

Rules:

- do not use unnamed zero-page scratch addresses
- keep interpreter-owned hot state in named zero-page symbols only
- if you change memory constants, update `ARCHITECTURE.md`
- if you change memory zones, make BespokeASM enforce them with explicit memzones
- do not allow code growth to silently consume reserved spill or runtime space

The long lhs spill stack is relocated after the source vector at `0xed00..0xed7f`. It is deliberately separate from the main runtime stack.

## Zero Page Rules

Zero page is scarce and high-value.

Use it for:

- hot runtime state
- math registers
- lookup caches
- runtime parser cursors

Do not spend zero page primarily on tokenizer-only state unless there is a strong, measured reason.

If expanding `MIN_ZERO_PAGE`, consider the effect on user-accessible zero-page memory for `@`-based programs.

## Performance Guidance

For runtime speed, the best current opportunities are usually:

- `getVar`
- `getCall`
- cache hit paths
- long-expression helper paths
- stack traffic reduction

Tokenizer-only speed work is lower priority unless it also improves size or maintainability.

When making instruction-level optimizations:

- prefer semantically exact replacements only
- examples that are often valid:
  - `LDI` -> `STB` to `MIB`
  - `LDB` -> `STB` to `MBB`
  - `LDZ` -> `STZ` to `MZZ`
  - `LDZ/LDB` + `CPI` to `CIZ/CIB` only when `A` is dead after the compare

Never replace a load/compare sequence with a compare-immediate form unless you have verified that the loaded value is not needed afterward.

## Branch and Size Optimization

This interpreter benefits heavily from branch-form tuning.

Use:

- `skills/optimize-size/SKILL.md`

Important rules:

- fast branches and jumps are layout-sensitive
- do not assume a fast branch remains valid after unrelated edits
- validate both default and `USE_ACCELERATOR` builds
- respect the `xxFF` fast-branch safety rule

If large layout changes are made, rerun the optimize-size workflow rather than manually tweaking a few fast branches and assuming the result is stable.

## Skills

This repository includes repo-local Codex skills under `skills/`.

Available local skills:

- `compile-min-64x4`
  - path: `skills/compile-min-64x4/SKILL.md`
  - use when compiling `*.min64x4` sources in this repo
- `optimize-size`
  - path: `skills/optimize-size/SKILL.md`
  - use when recovering branch/jump size and fast-branch locality after layout drift

How to tell Codex about these skills in practice:

- keep this `AGENTS.md` file in the repo root
- list each repo-local skill here by name and path
- ask for the skill by name in the prompt, for example:
  - `use the compile-min-64x4 skill`
  - `run the optimize-size skill on extended-min.min64x4`

When the task clearly matches one of these skills, Codex should open the corresponding `SKILL.md` and follow it.

## Error Path Caveat

Runtime error reporting re-runs the tokenizer up to `g_stop` to reconstruct source position.

That means tokenizer changes can affect:

- compile-time behavior
- runtime error line mapping
- source excerpts shown in errors

If you touch tokenizer logic, test at least one intentional failure case as well as passing cases.

## Lookup and Cache Caveat

`getVar` already has a small hot cache.

When changing variable or call lookup:

- keep cache invalidation coherent with dictionary growth
- be careful with scope-sensitive keys
- verify shadowing behavior
- verify repeated lookup in loops

## Constants and `string`

`string` is tokenizer-only syntax for constant declarations. It is not a runtime type token.

Be careful not to accidentally treat `string` as a normal runtime declaration keyword.

Const handling is split between:

- line-head detection
- const declaration parsing
- const substitution during tokenization

Changes here are easy to break in subtle ways.

## Recommended Test Strategy

Because runtime validation happens on hardware, use layered testing:

### Always

- compile default build
- compile `USE_ACCELERATOR` build

### For general regressions

Run a short smoke set such as:

- `tests/m2varcon.xmin`
- `tests/m2ctrlfl.xmin`
- `tests/m2augasg.xmin`
- `tests/m1cmplng.xmin`
- `tests/arrslice.xmin`

### For constants and string work

- `tests/p2consts.xmin`
- `tests/p3strngs.xmin`

### For long and expression work

- `tests/p4longs1.xmin`
- `tests/p5opsctl.xmin`
- `tests/p6muldiv.xmin`
- `tests/m1arithm.xmin`

### For call/lookup/runtime speed work

- `tests/p4longs1.xmin`
- `tests/p5opsctl.xmin`
- `tests/m2varcon.xmin`

## Hardware Benchmarking

If measuring runtime performance on hardware, use the timer card through:

- `../timer/software/timerlib.min`

and the timer card documentation:

- `../timer/README.md`

Use timer-based benchmarks instead of subjective timing. Record:

- benchmark name
- loop count
- raw timer value
- interpreter revision

## Editing Guidance

- Prefer small, isolated changes.
- Update comments when changing memory layout or invariants.
- Preserve ASCII.
- Keep labels and symbol names consistent with existing style.
- If a fix changes semantics, add or update a focused test in `tests/`.
- If a change is structural, update `ARCHITECTURE.md`.

## When In Doubt

If unsure, prefer:

- clearer state ownership
- named scratch storage over anonymous addresses
- explicit memzone enforcement
- tests that isolate the exact path being changed

This codebase rewards careful local reasoning more than broad refactors.

## Minimal 64x4 Assembly Programming Guide

General tips and techniques for writing tight, efficient assembly for the slu4 Minimal 64x4 TTL computer. These apply to any Minimal 64x4 project, not just Extended Min.

### Instruction Selection — Compound Instructions Save Bytes and Cycles

The Minimal 64x4 ISA has many compound instructions that replace common multi-instruction sequences. Always prefer the compound form. Each typically saves 1-2 bytes and 1-2 clock cycles.

**Load/store consolidations (save 1 byte each):**
- `LDI imm STT zp` → `MIT imm,zp`
- `LDI imm STR addr` → `MIR imm,addr`
- `LDI imm STZ zp` → `MIZ imm,zp` (same size but check context)
- `LDI imm STB addr` → `MIB imm,addr`
- `LDZ a STZ b` → `MZZ a,b` (only when A is dead after)
- `LDB a STB b` → `MBB a,b` (only when A is dead after)
- `LDZ a STB b` → `MZB a,b` (only when A is dead after)
- `LDB a STZ b` → `MBZ a,b` (only when A is dead after)

**Compare consolidations (save 1 byte each):**
- `LDT zp CPI imm` → `CIT imm,zp` (only when A is dead after — CIT sets A to the *difference*, not the loaded value)
- `LDB addr CPI imm` → `CIB imm,addr` (same A caveat)
- `LDB a CPB b` → `CBB b,a` (note operand reversal: `CBB addr1,addr2` computes `A = *addr2 - *addr1`)

**CRITICAL: The A register caveat.** `CIT`, `CIB`, `CBB`, and all `Mxx` compound moves set A to a value different from the original `LDx` sequence. If subsequent code uses A (e.g., a `CPI` chain, `STx`, `PHS`, `ADI`, or any ALU operation), the replacement is **unsafe**. Always verify A is dead or overwritten before the next use. Common traps:
- `LDB x CPI 3 FEQ label` followed by `CPI 1` — the second `CPI` needs A = *x, not A = *x - 3
- `LDB x CPI '-' FNE label` followed by `STR y` — the `STR` needs A = *x to store the loaded value

**Arithmetic consolidations:**
- `LDZ x ADI 1 STZ x` → `INZ x` (saves 4 bytes — increment zero-page byte in place)
- `LDB x ADI 1 STB x` → `INB x` (saves 4 bytes — increment absolute-address byte)
- `LDI imm ADW addr` → `AIW imm,addr` (saves 1 byte, 1 cycle)
- `LDZ a XRZ b STZ b` → `LDZ a XR.Z b` (saves 2 bytes — XOR and store back)
- `LDZ a ORZ b STZ b` → `LDZ a OR.Z b` (saves 2 bytes)
- `LDZ a ANZ b STZ b` → `LDZ a AN.Z b` (saves 2 bytes)
- `PLS XRZ b STZ b` → `PLS XR.Z b` (saves 2 bytes — works with PLS source too)
- `MIZ 1,x CLZ x+1` → `MIV 1,x` (saves 1 byte, 2 cycles — set 16-bit word to small constant)

**Immediate word operations:**
- `MIB lo,addr MIB hi,addr+1` → `MIW word,addr` (for non-zero-page targets)
- `MIB lo,zp MIB hi,zp+1` → `MIV word,zp` (for zero-page targets — **MIV only works with zero page**)

### Zero Page Is Your Most Valuable Resource

Zero-page variables (0x00-0xFF) use 2-byte instructions instead of 3-byte absolute-address instructions. Every variable moved to zero page saves 1 byte per reference and typically 1 clock cycle per access.

**Prioritize zero page for:**
- Frequently accessed pointers (stack pointers, scan cursors, write pointers)
- Math/temp registers used in hot loops
- Any 2-byte pointer used with indirect addressing (`LDT`/`STT` vs `LDR`/`STR`)

**The indirect addressing payoff is especially large:**
- `LDR addr` (3 bytes) → `LDT zp` (2 bytes) — load through pointer
- `STR addr` (3 bytes) → `STT zp` (2 bytes) — store through pointer
- `INW addr` (3 bytes) → `INV zp` (2 bytes) — increment pointer
- `DEW addr` (3 bytes) → `DEV zp` (2 bytes) — decrement pointer

A pointer variable used 20 times with `LDT`/`STT`/`INV` saves 20 bytes by being in zero page vs absolute memory.

**Do not use MIV for non-zero-page targets.** `MIV` is "Move immediate word to zero-page word." Using it with an absolute address causes a BespokeASM error or silent corruption. Use `MIW` for non-zero-page targets.

### Fast Branches vs Long Branches

The Minimal 64x4 has two branch forms:
- **Fast branches** (`FEQ`, `FNE`, `FCC`, `FCS`, `FPA`, etc.) — 2 bytes, target must be on the same 256-byte page
- **Long branches** (`BEQ`, `BNE`, `BCC`, `BCS`, `JPA`, etc.) — 3 bytes, any target address

Fast branches save 1 byte and are slightly faster. But they break when code layout shifts and the target crosses a page boundary. The assembler catches this at compile time.

**Rules:**
- Use fast branches when the target is close (within the same function/block)
- After adding or removing code, fast branches anywhere in the file may break — always recompile both build variants
- When fixing a broken fast branch, convert it to the long form (e.g., `FEQ` → `BEQ`). This adds 1 byte, which may cascade into more breaks nearby
- For systematic optimization after large changes, use the optimize-size workflow rather than manual tweaking
- A single fast→long conversion can cascade: the extra byte shifts all subsequent addresses, potentially breaking more fast branches
- Do not assume a fast branch is valid just because it compiled before — any edit anywhere in the file can shift addresses

**Mapping (fast → long):** `FEQ`↔`BEQ`, `FNE`↔`BNE`, `FCC`↔`BCC`, `FCS`↔`BCS`, `FPA`↔`JPA`, `FGT`↔`BGT`, `FLE`↔`BLE`, `FPL`↔`BPL`, `FMI`↔`BMI`

### Memory Layout and Shared Regions

On the Minimal 64x4, RAM is shared across the OS, user programs, and hardware-mapped I/O. Key principles:

- **Memory zones are hard boundaries.** Use BespokeASM's `#create_memzone` to enforce them. If code exceeds a zone, the assembler errors immediately — this is preferable to silent overflow.
- **Regions that are never used simultaneously can share addresses.** For example, a tokenizer-only dictionary and a runtime data stack can occupy the same memory if tokenization completes before runtime begins.
- **Self-modifying code uses operand labels** (`@label` syntax). The assembler manages the address patching. This is common for indirect memory copy loops (`MBB @src,@dst`).
- **The CPU stack (0xFF00-0xFFFF)** is small. Deep nesting of `JPS`/`PHS` can overflow it. Guard recursive or deeply-nested call paths with depth limits.

### Calling Conventions and the CPU Stack

The CPU stack is used for both `JPS`/`RTS` return addresses and `PHS`/`PLS` temporary saves. Key points:

- `JPS` pushes a 2-byte return address. `RTS` pops it. Subroutine calls must be balanced.
- Parameters are typically passed via `PHS` before `JPS` and read inside the subroutine with `LDS offset`. The offset accounts for the return address pushed by `JPS`.
- Return values are often stored back into the same stack slots with `STS offset`, then popped by the caller with `PLS`.
- **Save/restore order matters.** Push LSB first, then MSB. Pop MSB first, then LSB (LIFO).
- When saving state across a subroutine call (e.g., saving a pointer before calling a function that might clobber it), ensure the push count matches the pop count exactly. An imbalance corrupts all subsequent return addresses.

### Avoiding Common Bugs

**Off-by-one in structure offsets.** When navigating multi-byte record structures with `AIV`/`SIV`, carefully count byte offsets. A wrong offset writes to the wrong field — this may appear to work for some types (e.g., writing 1 to a type-1 field) while silently corrupting adjacent fields.

**Forgetting to restore z_sp.** If you temporarily set `z_sp` to point at a different memory location (e.g., to write data into a buffer), you must save and restore it. Otherwise, all subsequent expression evaluations and variable allocations use the wrong stack position, causing cascading corruption.

**CIB/CIT in comparison chains.** Never use `CIB` or `CIT` when the loaded value (not the difference) is needed by a subsequent `CPI` in a dispatch chain. Example:
```asm
; WRONG: CIB sets A = *addr - 3, then CPI 1 compares the difference
CIB 3,type FEQ string_path
CPI 1 FNE int_path          ; BUG: A is (type-3), not type

; CORRECT: LDB preserves the loaded value in A for the CPI chain
LDB type CPI 3 FEQ string_path
CPI 1 FNE int_path          ; A is still the original type value
```

**Non-zero-page MIV.** `MIV` is zero-page only. Using it with an absolute address (> 0xFF) causes an assembler error or worse. Use `MIW` for absolute addresses. The assembler error message mentions "exceeds maximum allowed address of 255 in memory zone ZERO_PAGE."

**ADW leaves A undefined.** After `LDI imm ADW addr`, A is implementation-dependent (the ISA says "Undefined"). Do not rely on A's value after `ADW`. Use `AIW imm,addr` instead, which also saves a byte.

### Size Optimization Strategies

When code size is tight:

- **Move error strings into `.align` padding gaps.** The space between code and a `.align` directive is otherwise wasted as padding bytes. Short error strings can fill this gap for free.
- **Share error handlers.** Multiple paths that throw the same error can jump to a single shared handler label instead of each inlining the `LDI`/`PHS`/`JPA Error` sequence.
- **Share subroutine prologues.** If multiple functions start with the same sequence (e.g., parse `(`, check for `V` token, call `getVar`), extract it into a shared subroutine.
- **Use local labels (`.label`) for private branch targets.** They don't pollute the global namespace and make code easier to reorganize.
- **Relocate cold data out of hot code regions.** Dictionary tables, error strings, and initialization-only data can live after the hot loop code. Reserve the tightest address space for the code that must be page-aligned or frequently branched to.
- **Consider sharing memory between non-overlapping uses.** A temp variable used only during tokenization can share an address with runtime-only state, saving both code space (fewer declarations) and zero-page slots.
