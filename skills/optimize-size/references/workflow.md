# Extended Min Size/Speed Optimization Workflow

This workflow is designed for repeated use while `extended-min.min64x4` evolves.

## 0) Preconditions

- Work from the standalone `extended-min` repository root.
- Ensure `bespokeasm` is installed and available on `PATH`.
- Ensure either `curl` or `wget` is available so the repo-local compile skill can fetch the Minimal 64x4 BespokeASM config from GitHub.
- Avoid editing unrelated files during the optimization pass.

## 1) Baseline Snapshot

```bash
cp extended-min.min64x4 /tmp/extended-min.baseline.min64x4
```

Run baseline compile in both modes and keep listings:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh \
  extended-min.min64x4 > /tmp/baseline.noacc.pretty

skills/compile-min-64x4/scripts/compile_min64x4.sh \
  extended-min.min64x4 -- -D USE_ACCELERATOR > /tmp/baseline.acc.pretty
```

Collect baseline metrics:

```bash
skills/optimize-size/scripts/collect_metrics.sh \
  extended-min.min64x4 \
  /tmp/baseline.noacc.pretty /tmp/baseline.acc.pretty
```

## 2) Core Top-Down Convergence

Run optimizer on the candidate:

```bash
skills/optimize-size/scripts/optimize_dual.sh \
  extended-min.min64x4 current
```

What it does:
- converts all eligible long ops to fast ops globally
- compiles `noacc` and `acc`
- if compile fails, parses the first failing source line
- reverts only that line back to long-op form
- repeats until both builds pass

This gives the maximum valid fast-op usage for that exact layout.

## 3) Review Metrics and Apply

Use the lexicographic score from `collect_metrics.sh`:
1. smaller `max(g_stop_noacc, g_stop_acc)`
2. then smaller `g_stop_noacc + g_stop_acc`
3. then smaller `long_count`
4. then larger `fast_count`

Record the resulting metrics for traceability, then apply the optimized file back to `extended-min.min64x4` if you ran the optimizer on a copy.

## 4) Preserve Current Layout

- Do not run string-layout sweeps as part of the standard optimize-size workflow.
- Treat the current source layout as fixed unless a separate change explicitly moves code or data.
- If a manual layout edit is being evaluated, optimize that edited copy directly and compare metrics only for that explicit alternative.

## 5) Optional Alignment Budget Search

Only run this if requested explicitly.

Method:
- start from the no-align winner
- insert one `.align` candidate between function boundaries only
- rerun dual optimization
- compute align padding from the listing:
  ```bash
  skills/optimize-size/scripts/show_align_padding.sh /tmp/listing.pretty
  ```
- accept the insertion only if score improves and total padding budget remains under target
- iterate top-down

## 6) Non-Negotiable Checks

Before finalizing:
- compile passes in both modes
- local/fast counts and `g_stop` are recorded
- `git diff` is reviewed for unintended semantic edits
- optional runtime tests are rerun if requested

## 7) Known Good Tactics

- Keep the `int_mul` `#ifdef USE_ACCELERATOR` section near the tail, not mid-file.
- Keep compact, frequently referenced error strings near hot code when it improves page locality.

## 8) Failure Modes and Recovery

If the optimization loop fails to parse a line number:
- inspect compile error output manually
- patch that line’s fast op back to long form manually
- rerun `optimize_dual.sh`

If an edited copy becomes unstable:
- restore from `/tmp/extended-min.baseline.min64x4`
- reapply the explicit layout edit in smaller steps
