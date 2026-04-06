#!/usr/bin/env python3
"""
Align inline comment columns in Minimal 64x4 assembly files.

Scans for blocks of code where inline comment semicolons are jagged
(varying by more than a threshold within a block) and aligns them
to a consistent column.

Usage:
    python3 lint_comments.py <file.min64x4> [--preview] [--threshold N] [--min-column N]
"""

import argparse
import sys


def find_inline_comment(line):
    """
    Find the position of the first inline comment semicolon.

    Returns (comment_start_col, code_end_col, comment_text) or None.

    Handles:
    - Double-quoted strings ("...")
    - Single-quoted character literals ('x', ';')
    - Full-line comments (returns None)
    - Assembler directives (returns None)
    """
    stripped = line.rstrip()
    if not stripped:
        return None

    lstripped = stripped.lstrip()
    if lstripped.startswith(';') or lstripped.startswith('#'):
        return None

    in_dquote = False
    i = 0
    while i < len(stripped):
        c = stripped[i]

        if c == '"':
            in_dquote = not in_dquote
        elif c == "'" and not in_dquote:
            # Character literal: skip 'x' or '\x' patterns
            close = stripped.find("'", i + 1)
            if close > i and close - i <= 4:
                i = close + 1
                continue
        elif c == ';' and not in_dquote:
            code = stripped[:i].rstrip()
            comment = stripped[i:]
            return (i, len(code), comment)
        i += 1

    return None


def code_width(line):
    """
    Return the width of the instruction text on a line (ignoring comments).
    Returns 0 for blank lines, full-line comments, and directives.
    """
    stripped = line.rstrip()
    if not stripped:
        return 0
    lstripped = stripped.lstrip()
    if lstripped.startswith(';') or lstripped.startswith('#'):
        return 0

    info = find_inline_comment(line)
    if info:
        return info[1]  # code_end before the comment
    else:
        return len(stripped.rstrip())


def is_hard_boundary(lines, i):
    """
    Check if line i is a hard block boundary — a point where comment
    alignment should definitely reset.

    Hard boundaries:
    - Section break comments (; --- or ; ===)
    - Assembler directives (#create_memzone, .memzone, .org, .align)
    - Two or more consecutive blank lines
    """
    stripped = lines[i].rstrip()
    lstripped = stripped.lstrip()

    # Section break comments
    if lstripped.startswith('; ---') or lstripped.startswith('; ==='):
        return True

    # Assembler directives
    if lstripped.startswith('#') or lstripped.startswith('.memzone') or \
       lstripped.startswith('.org') or lstripped.startswith('.align'):
        return True

    # Two consecutive blank lines
    if not stripped and i + 1 < len(lines) and not lines[i + 1].rstrip():
        return True

    return False


def collect_blocks(lines):
    """
    Collect visual blocks of code lines with inline comments.

    Block boundaries are hard boundaries only (section breaks, directives,
    double blank lines). Single blank lines and labels do NOT break blocks,
    allowing related code across labels to share a comment column.

    Returns list of (commented_lines, all_line_indices) tuples where:
    - commented_lines: [(line_idx, code_end, comment_text), ...]
    - all_line_indices: [line_idx, ...] for all code lines in the block (including uncommented)
    """
    blocks = []
    current_commented = []
    current_all = []
    i = 0

    while i < len(lines):
        if is_hard_boundary(lines, i):
            if len(current_commented) >= 2:
                blocks.append((current_commented, current_all))
            current_commented = []
            current_all = []
            i += 1
            continue

        line = lines[i]
        stripped = line.rstrip()

        # Track all non-blank, non-full-comment code lines
        if stripped and not stripped.lstrip().startswith(';'):
            cw = code_width(line)
            if cw > 0:
                current_all.append((i, cw))

        info = find_inline_comment(line)
        if info:
            _, code_end, comment_text = info
            current_commented.append((i, code_end, comment_text))

        i += 1

    if len(current_commented) >= 2:
        blocks.append((current_commented, current_all))

    return blocks


def compute_target_column(commented_lines, all_lines, min_column, intrusion_tolerance):
    """
    Compute the target comment column for a block.

    The target is the maximum of:
    - longest commented code line + 1 space
    - the minimum column floor

    Additionally, uncommented lines that would intrude into the comment
    column are considered: if an uncommented line extends past the initial
    target by less than intrusion_tolerance characters, the target is
    pushed right to accommodate it. Lines that exceed the tolerance are
    considered "excessively long" and ignored (they'd push the column
    too far right).
    """
    max_commented_code = max(entry[1] for entry in commented_lines)
    target = max(max_commented_code + 1, min_column)

    # Check uncommented lines for intrusion
    for line_idx, cw in all_lines:
        # Skip lines that have comments (already accounted for)
        is_commented = any(entry[0] == line_idx for entry in commented_lines)
        if is_commented:
            continue

        if cw >= target and cw < target + intrusion_tolerance:
            # This uncommented line intrudes — push target past it
            target = cw + 1

    return target


def lint_file(filepath, threshold=5, min_column=40, intrusion_tolerance=10, preview=False):
    """
    Lint comment alignment in the given file.

    Args:
        filepath: Path to the .min64x4 file
        threshold: Minimum column spread to trigger alignment (default 5)
        min_column: Minimum comment column floor (default 40)
        intrusion_tolerance: Max chars an uncommented line can intrude before
                             being ignored as "excessively long" (default 10)
        preview: If True, only report without modifying the file
    """
    with open(filepath, 'r') as f:
        lines = f.readlines()

    blocks = collect_blocks(lines)

    # Filter to jagged blocks
    jagged = []
    for commented_lines, all_lines in blocks:
        comment_cols = []
        for entry in commented_lines:
            line = lines[entry[0]]
            info = find_inline_comment(line)
            if info:
                comment_cols.append(info[0])

        if not comment_cols:
            continue

        spread = max(comment_cols) - min(comment_cols)

        # Check for intrusion: uncommented lines extending into the comment zone
        current_comment_col = min(comment_cols)
        has_intrusion = False
        for line_idx, cw in all_lines:
            is_commented = any(entry[0] == line_idx for entry in commented_lines)
            if not is_commented and cw >= current_comment_col and cw < current_comment_col + intrusion_tolerance:
                has_intrusion = True
                break

        if spread >= threshold or has_intrusion:
            jagged.append((commented_lines, all_lines, spread))

    if not jagged:
        print(f"No jagged blocks found (threshold={threshold}, min_column={min_column})")
        return 0

    jagged.sort(key=lambda x: -x[2])

    if preview:
        print(f"Found {len(jagged)} jagged blocks (threshold={threshold}, min_column={min_column}):\n")
        for commented_lines, all_lines, spread in jagged:
            line_range = f"L{commented_lines[0][0]+1}-L{commented_lines[-1][0]+1}"
            target = compute_target_column(commented_lines, all_lines, min_column, intrusion_tolerance)
            print(f"  {line_range:20s}  spread={spread:2d}  lines={len(commented_lines):2d}  target_col={target}")
        return len(jagged)

    # Apply fixes
    total_fixes = 0
    for commented_lines, all_lines, spread in jagged:
        target = compute_target_column(commented_lines, all_lines, min_column, intrusion_tolerance)

        for line_idx, code_end, comment_text in commented_lines:
            line = lines[line_idx]
            info = find_inline_comment(line)
            if not info:
                continue

            _, _, comment = info
            code_part = line[:info[0]].rstrip()

            padding = target - len(code_part)
            if padding < 1:
                padding = 1

            new_line = code_part + ' ' * padding + comment + '\n'
            if new_line != lines[line_idx]:
                lines[line_idx] = new_line
                total_fixes += 1

    with open(filepath, 'w') as f:
        f.writelines(lines)

    print(f"Fixed {total_fixes} lines across {len(jagged)} blocks")
    return total_fixes


def main():
    parser = argparse.ArgumentParser(
        description='Align inline comment columns in Minimal 64x4 assembly files.'
    )
    parser.add_argument('file', help='Path to .min64x4 assembly file')
    parser.add_argument('--preview', action='store_true',
                        help='Report jagged blocks without modifying the file')
    parser.add_argument('--threshold', type=int, default=5,
                        help='Minimum column spread to trigger alignment (default: 5)')
    parser.add_argument('--min-column', type=int, default=40,
                        help='Minimum comment column floor (default: 40)')
    parser.add_argument('--intrusion-tolerance', type=int, default=10,
                        help='Max chars an uncommented line can intrude into the '
                             'comment zone before being ignored (default: 10)')

    args = parser.parse_args()
    lint_file(args.file, threshold=args.threshold, min_column=args.min_column,
              intrusion_tolerance=args.intrusion_tolerance, preview=args.preview)


if __name__ == '__main__':
    main()
