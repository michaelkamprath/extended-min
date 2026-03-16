---
name: compile-min-64x4
description: Compile Extended Min Minimal 64x4 assembly with BespokeASM using a repo-local helper that fetches the instruction-set config from GitHub.
---

# Compile Minimal 64x4

Use this skill when you need to compile `*.min64x4` sources in this repository.

## Requirements

- `bespokeasm` must be installed and available on `PATH`
- either `curl` or `wget` must be available so the helper can fetch the Minimal 64x4 BespokeASM config

The helper fetches the Minimal 64x4 config from:

- `https://raw.githubusercontent.com/michaelkamprath/bespokeasm/main/examples/slu4-minimal-64x4/slu4-minimal-64x4.yaml`

## Helper Script

Use:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh <source.min64x4>
```

Pass extra BespokeASM args after `--`:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh \
  extended-min.min64x4 -- -D USE_ACCELERATOR
```

The helper:

- fetches the Minimal 64x4 BespokeASM config into `/tmp/slu4-minimal-64x4.yaml`
- runs `bespokeasm compile -c <cfg> -n -p`
- prints the pretty listing to stdout

## Common Uses

Default build:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4
```

Accelerator build:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh \
  extended-min.min64x4 -- -D USE_ACCELERATOR
```

Intel HEX build if needed:

```bash
cfg=/tmp/slu4-minimal-64x4.yaml
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4 >/tmp/extended-min.pretty
bespokeasm compile -c "$cfg" -n -p -t intel_hex extended-min.min64x4
```

## Validation Expectation

For meaningful interpreter changes, compile both:

- default build
- `USE_ACCELERATOR` build
