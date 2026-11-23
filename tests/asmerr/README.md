# asm Block Error Fixtures

Expected-error fixtures for `asm` blocks. Unlike the suites in `tests/`, each file stops with an error; the first line of each file states the expected message and line number. They only load data into the user areas and never call it, so the same files work on both the Minimal 64x4 and the Redux.

| File | Expected output | Checks |
|---|---|---|
| `asmchk.xmin` | `Invalid asm in line 3` | record checksum mismatch |
| `asmdigit.xmin` | `Invalid asm in line 3` | non-hex digit in a record |
| `asmlow.xmin` | `Invalid asm in line 3` | load address `0x00ff`, below the low user area |
| `asmgap.xmin` | `Invalid asm in line 3` | record running from `0x0ffe` into `0x1000` (interpreter code) |
| `asmspill.xmin` | `Invalid asm in line 3` | load address `0xed7f`, the top of the long spill stack |
| `asmos.xmin` | `Invalid asm in line 3` | record running from `0xeffe` into `0xf000` (MinOS) |
| `asmnoeof.xmin` | `Invalid asm in line 4` | block not closed by an EOF record |
| `asmrterr.xmin` | `before`, then `Invalid ID in line 6` | a runtime error after an `asm` block still reports the right source line (the error path re-runs the tokenizer over the block) |

A record that crosses out of a user area writes its in-range bytes before the error is raised.
