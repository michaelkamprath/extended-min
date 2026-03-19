---
name: optimize-size
description: Optimize Extended Min code size and branch speed by maximizing valid local fast branches/jumps while preserving compile correctness in both default and USE_ACCELERATOR builds.
---

# Optimize Size (Fast vs Long Branches/Jumps)

Use this skill when modifying `extended-min.min64x4` and you need to recover size/speed after layout drift.

## Goal

Find the best layout and opcode form mix that:
- compiles in both modes:
  - default
  - `-D USE_ACCELERATOR`
- minimizes bytecode footprint (primary)
- maximizes local/fast branch/jump usage (secondary)
- enforces a safety rule: no `F*` opcode may be placed at an `xxFF` address
- avoids `.align` unless an explicit alignment-budget phase is requested

## Dependency

This skill depends only on the repo-local compile helper:

- [`skills/compile-min-64x4/scripts/compile_min64x4.sh`](../compile-min-64x4/scripts/compile_min64x4.sh)

That helper fetches the Minimal 64x4 BespokeASM config from GitHub and requires:

- `bespokeasm`
- `curl` or `wget`

## Branch/Jumps Mapping

Fast -> Long fallback used by optimizer:
- `FPA -> JPA`
- `FEQ -> BEQ`
- `FNE -> BNE`
- `FCC -> BCC`
- `FCS -> BCS`
- `FGT -> BGT`
- `FLE -> BLE`
- `FPL -> BPL`
- `FMI -> BMI`

## Helper Scripts

All scripts live in `scripts/`:
- `optimize_dual.sh`
  - core top-down convergence algorithm (all-fast, then revert failing lines)
  - validates both default and accelerator builds each iteration
  - rejects any candidate that places `F*` opcodes at `xxFF` addresses in either build
- `collect_metrics.sh`
  - reports `fast/long/align` counts and score tuple
  - extracts `g_stop` from both pretty listings
- `run_candidate.sh`
  - runs optimize + metrics for one candidate file
- `show_align_padding.sh`
  - computes total padding cost from a pretty listing containing `.align`

## Core Workflow

1. Create a candidate copy (never start without backup).
2. Preflight obvious instruction-selection cleanups:
   ```bash
   rg --pcre2 -n -U "LDZ ([A-Za-z0-9_]+)\\+0 STZ ([A-Za-z0-9_]+)\\+0\\n\\s*LDZ \\1\\+1 STZ \\2\\+1" \
     extended-min.min64x4

   rg --pcre2 -n -U "MZZ ([A-Za-z0-9_]+)\\+0,([A-Za-z0-9_]+)\\+0\\n\\s*MZZ \\1\\+1,\\2\\+1" \
     extended-min.min64x4

   rg --pcre2 -n -U "LDZ ([A-Za-z0-9_]+)\\+0 ADV ([A-Za-z0-9_]+)\\+0\\n\\s*LDZ \\1\\+1 AD\\.Z \\2\\+1" \
     extended-min.min64x4

   rg --pcre2 -n -U "LDZ ([A-Za-z0-9_]+)\\+0 SUV ([A-Za-z0-9_]+)\\+0\\n\\s*LDZ \\1\\+1 SU\\.Z \\2\\+1" \
     extended-min.min64x4

   rg --pcre2 -n -U "CLZ ([A-Za-z0-9_]+)\\+0\\n\\s*CLZ \\1\\+1" \
     extended-min.min64x4
   ```
3. Run optimization:
   ```bash
   skills/optimize-size/scripts/optimize_dual.sh <candidate.min64x4> <tag>
   ```
4. Collect metrics:
   ```bash
   skills/optimize-size/scripts/collect_metrics.sh \
     <candidate.min64x4> \
     /tmp/optimize-size.<tag>.noacc.pretty \
     /tmp/optimize-size.<tag>.acc.pretty
   ```
5. Review the score tuple from `collect_metrics.sh`.
6. If you optimized a copy, apply that optimized file back to `extended-min.min64x4`.

## Score Strategy (Deterministic)

Lexicographic order, lower is better:
1. `max(g_stop_noacc, g_stop_acc)`
2. `g_stop_noacc + g_stop_acc`
3. `long_count`
4. `-fast_count`

This prioritizes smallest binary size across both build modes, then fastest branch mix.

## Layout Strategy

- Preserve the existing source layout during routine optimize-size passes.
- Keep toggle-sensitive optional code (for `USE_ACCELERATOR`) at the tail.
- Do not spend time on string-layout sweeps as part of the standard workflow.

## Optional Alignment-Budget Phase

Only if requested:
- start from best no-align candidate
- add `.align` only between functions
- keep global align padding budget (for example `<= 100` bytes)
- after each `.align` insertion, rerun `optimize_dual.sh` and keep only net wins
- use `show_align_padding.sh` to measure actual padding cost from the listing

## Expected Artifacts

- `/tmp/optimize-size.<tag>.noacc.pretty`
- `/tmp/optimize-size.<tag>.acc.pretty`

For full method details and decision rules, read `references/workflow.md`.
