# Extended Min Test Suites

This directory contains the canonical runnable regression suites for the standalone `extended-min` repository.

Conventions:

- Every runnable suite is an `*.xmin` file with an 8-character basename.
- Each suite prints final `PASS <ids>` and `FAIL <ids>` lines, followed by a `PASS=<n> FAIL=<n>` count summary, so the decisive result stays visible on hardware without scrollback.
- These suites focus on expected-pass behavior.

Current suites:

- `m1cmpint.xmin`: int comparisons and basic expression storage
- `m1cmplng.xmin`: mixed int/long comparisons
- `m1arithm.xmin`: arithmetic and unary minus behavior
- `m2varcon.xmin`: var-vs-constant compare fast paths
- `m2ctrlfl.xmin`: control flow, break, else, nested loops
- `m2augasg.xmin`: `+=` / `-=` fast paths
- `m3scalar.xmin`: scalar copies for all widths, indexed assignment, empty/bulk fallbacks, function arguments/returns, and an absolute view crossing a page
- `p2consts.xmin`: constants, casts, shadowing, hex literals
- `p4longs1.xmin`: long casts, literals, params, returns
- `p5opsctl.xmin`: long ops plus compare/control regressions
- `p6muldiv.xmin`: int/long multiply and divide behavior
- `arrslice.xmin`: array and slice behavior
- `usecmt01.xmin`: loader ignores commented `use "..."` text

For changes to variable reads or assignments, run `m3scalar.xmin` and `arrslice.xmin` on hardware. `m3scalar.xmin` covers all three scalar widths, one-element slices, indexed and whole-value assignments, empty values, a 257-element bulk copy, function arguments/returns, reference writes, and an absolute view crossing a page boundary. Its expected summary is `m3scalar PASS=12 FAIL=0`.

Compile the interpreter for both targets with and without `USE_ACCELERATOR` before running these suites. Assembly checks and host models do not establish hardware correctness or measured speed; use timer-card benchmarks to assess runtime performance.

Speed benchmarks (require the timer card and `timerlib.min` on the machine; they do not print PASS/FAIL):

- `speed4.min`: original-Min-compatible benchmark (sort, search, fib, gcd, int array loops); prints one total timer value
- `xspeed.xmin`: general Extended Min benchmark in 13 separately timed sections. Sections 1-8 time language features: long `*` / `/`; long add/sub/bitwise/shift/not/negate/compare; int `*` / `/` / shifts; scalar, indexed, slice, and whole-array copies; user function calls (char/int/long params, by-ref, recursion); control flow with constants and `break`; list ops, concatenation, and casts; hex-blob `@` views. Sections 9-13 time small programs: int insertion sort, char-array prime sieve, string processing, long Collatz steps, and many-variable lookups with nested calls. Each section prints `cyc=` (8 MHz clock cycles), `ms=`, and `chk=`, followed by a total. Section loop counts are the `N1`..`N13` constants at the top of the file.

To compare two interpreter builds, run `xspeed.xmin` under each with the same target machine and the same `USE_ACCELERATOR` setting. The `chk=` values must be identical. Run the reference build first: the output ends with `long Rn := ...` lines. Paste these over the `R1`..`R13` constants at the top of the file. All result lines are sent with `output(...)`, so they also appear on the UART and can be copied from a serial terminal. Later runs then print each section's speed ratio, an equal-weight overall `score=`, and a `total time ratio=`. In all three, 1000 means reference speed and 1250 means 25% faster. Record the interpreter revision with the results.

Intentionally omitted from this first standalone suite set:

- old debug programs
- interactive demos
- speed-only probes
- expected-error fixtures
- hardware-visual checks that do not self-report cleanly

Those can be re-added later as separate focused assets, but they do not fit the "single file, self-reporting end summary" rule used here.
