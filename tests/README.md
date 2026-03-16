# Extended Min Test Suites

This directory contains the canonical runnable regression suites for the
standalone `extended-min` repository.

Conventions:

- Every runnable suite is an `*.xmin` file with an 8-character basename.
- Each suite prints final `PASS <ids>` and `FAIL <ids>` lines, followed by a
  `PASS=<n> FAIL=<n>` count summary, so the decisive result stays visible on
  hardware without scrollback.
- These suites focus on expected-pass behavior.

Current suites:

- `m1cmpint.xmin`: int comparisons and basic expression storage
- `m1cmplng.xmin`: mixed int/long comparisons
- `m1arithm.xmin`: arithmetic and unary minus behavior
- `m2varcon.xmin`: var-vs-constant compare fast paths
- `m2ctrlfl.xmin`: control flow, break, else, nested loops
- `m2augasg.xmin`: `+=` / `-=` fast paths
- `p2consts.xmin`: constants, casts, shadowing, hex literals
- `p3strngs.xmin`: string constants and aliases
- `p4longs1.xmin`: long casts, literals, params, returns
- `p5opsctl.xmin`: long ops plus compare/control regressions
- `p6muldiv.xmin`: int/long multiply and divide behavior
- `arrslice.xmin`: array and slice behavior

Intentionally omitted from this first standalone suite set:

- old debug programs
- interactive demos
- speed-only probes
- expected-error fixtures
- hardware-visual checks that do not self-report cleanly

Those can be re-added later as separate focused assets, but they do not fit
the "single file, self-reporting end summary" rule used here.
