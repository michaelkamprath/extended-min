---
name: lint-comments
description: Align inline comment columns in Minimal 64x4 assembly files for visual consistency and readability.
---

# Lint Comments

Use this skill to align inline comment semicolons within local code blocks so they form clean columns.

## What It Does

Scans a `.min64x4` assembly file for blocks of code where inline comments (`;` after instruction text) are jagged — varying by 5 or more columns within a block. For each jagged block, it aligns all inline comments to a consistent column based on the longest instruction in that block.

## What It Does NOT Do

- Does not modify full-line comments (lines where `;` is the first non-whitespace character)
- Does not modify assembler directives (`#require`, `#create_memzone`, `.org`, etc.)
- Does not add or remove comments
- Does not change comment text
- Does not change instruction text, operands, or labels
- Does not change leading indentation

## Usage

### Preview mode (report only, no changes)

```bash
python3 skills/lint-comments/scripts/lint_comments.py <file.min64x4> --preview
```

### Apply fixes

```bash
python3 skills/lint-comments/scripts/lint_comments.py <file.min64x4>
```

### Custom minimum spread threshold

By default, blocks with a comment column spread of less than 5 are left alone. Override with `--threshold`:

```bash
python3 skills/lint-comments/scripts/lint_comments.py <file.min64x4> --threshold 3
```

### Custom minimum comment column

By default, comments are aligned to at least column 40 so they don't crowd short instruction lines. Override with `--min-column`:

```bash
python3 skills/lint-comments/scripts/lint_comments.py <file.min64x4> --min-column 36
```

## After Running

Always recompile both build variants after running the linter:

```bash
skills/compile-min-64x4/scripts/compile_min64x4.sh <file.min64x4>
skills/compile-min-64x4/scripts/compile_min64x4.sh <file.min64x4> -- -D USE_ACCELERATOR
```

The linter is cosmetic-only and should not affect compiled output, but verify as a precaution.

## Known Limitations

- Character literals containing semicolons (e.g., `CPI ';'`) can be misidentified as comment delimiters. The script handles single-quoted character literals specifically, but unusual quoting may require manual review.
- Block boundaries are "hard" only: section breaks (`; ---`), assembler directives (`.align`, `.memzone`), and double blank lines. Single blank lines and labels do NOT break blocks, allowing related code across labels to share a comment column. This matches the visual grouping of most Minimal 64x4 assembly but may occasionally group unrelated code.
