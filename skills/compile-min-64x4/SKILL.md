---
name: compile-min-64x4
description: Compile Extended Min Minimal 64x4 (and 64x4 Redux) assembly with BespokeASM using a repo-local helper that fetches the instruction-set config from GitHub.
---

# Compile Minimal 64x4

Use this skill when you need to compile `*.min64x4` (Minimal 64x4) or
`*.min64x4r` (Minimal 64x4 Redux) sources in this repository. The compile
helper picks the instruction-set config by source extension.

## Requirements

- `bespokeasm` must be installed and available on `PATH`
- either `curl` or `wget` must be available so the helper can fetch the Minimal 64x4 BespokeASM config

The helper fetches the configs from:

- `https://raw.githubusercontent.com/michaelkamprath/bespokeasm/main/examples/slu4-minimal-64x4/slu4-minimal-64x4.yaml`
- `https://raw.githubusercontent.com/michaelkamprath/bespokeasm/main/examples/slu4-minimal-64x4-redux/slu4-minimal-64x4-redux.yaml`

## Helper Scripts

Fetch the latest Minimal 64x4 config only:

```bash
skills/compile-min-64x4/scripts/fetch_min64x4_config.sh
```

Fetch the Minimal 64x4 Redux config only:

```bash
skills/compile-min-64x4/scripts/fetch_min64x4_config.sh --redux
```

Compile a source file (extension selects the config):

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh <source.min64x4|source.min64x4r>
```

Pass extra BespokeASM args after `--`:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh \
  extended-min.min64x4 -- -D USE_ACCELERATOR
```

The helper:

- uses `fetch_min64x4_config.sh` to fetch the matching BespokeASM config into
  `/tmp/slu4-minimal-64x4.yaml` (original) or `/tmp/slu4-minimal-64x4-redux.yaml` (Redux)
- runs `bespokeasm compile -c <cfg> -n -p`
- prints the pretty listing to stdout

## Common Uses

Default builds:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4
skills/compile-min-64x4/scripts/compile_min64x4.sh extended-min.min64x4r
```

Accelerator builds:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh \
  extended-min.min64x4 -- -D USE_ACCELERATOR
skills/compile-min-64x4/scripts/compile_min64x4.sh \
  extended-min.min64x4r -- -D USE_ACCELERATOR
```

Intel HEX build if needed:

```bash
cfg="$(skills/compile-min-64x4/scripts/fetch_min64x4_config.sh)"
bespokeasm compile -c "$cfg" -n -p -t intel_hex extended-min.min64x4
```

Redux Intel HEX build:

```bash
cfg="$(skills/compile-min-64x4/scripts/fetch_min64x4_config.sh --redux)"
bespokeasm compile -c "$cfg" -n -p -t intel_hex extended-min.min64x4r
```

## Validation Expectation

For meaningful interpreter changes, compile both build variants of every
affected target machine:

- default build
- `USE_ACCELERATOR` build

If a change touches shared interpreter logic, compile both
`extended-min.min64x4` and `extended-min.min64x4r`.
