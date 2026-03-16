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

- `MIN_INTERPRETER`: `0x1000..0x3f7f`
- `MIN_LHS_SPILL`: `0x3f80..0x3fff`
- source + token stream: `0x8000..0xd9ff`
- runtime stack: `0xda00..0xdfff`

Rules:

- do not use unnamed zero-page scratch addresses
- keep interpreter-owned hot state in named zero-page symbols only
- if you change memory constants, update `ARCHITECTURE.md`
- if you change memory zones, make BespokeASM enforce them with explicit memzones
- do not allow code growth to silently consume reserved spill or runtime space

The long lhs spill stack is deliberately separate from the main runtime stack. Do not merge or move it casually.

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
