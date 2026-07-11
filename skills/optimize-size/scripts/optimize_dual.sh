#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <source.min64x4 | source.min64x4r> [tag]

Optimizes branch/jump forms for BOTH builds:
  1) default build
  2) build with -D USE_ACCELERATOR

The target ISA is selected by the source extension via compile_min64x4.sh:
  .min64x4  -> Minimal 64x4 (original)
  .min64x4r -> Minimal 64x4 Redux

Algorithm:
  - Force all eligible ops to fast/local forms (F*).
  - Compile both builds.
  - If either build fails on page-MSB constraints, parse first error line
    and revert only that source line back to long form (B*/JPA).
  - Repeat until both builds compile.

Writes pretty outputs to:
  /tmp/optimize-size.<tag>.noacc.pretty
  /tmp/optimize-size.<tag>.acc.pretty
USAGE
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

src="$1"
default_tag="$(basename "${src}")"
default_tag="${default_tag%.min64x4r}"
default_tag="${default_tag%.min64x4}"
tag="${2:-$default_tag}"

if [[ ! -f "$src" ]]; then
  echo "Source not found: $src" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compile_script="$(cd "$script_dir/../../compile-min-64x4/scripts" && pwd)/compile_min64x4.sh"

if [[ ! -x "$compile_script" ]]; then
  echo "Compile helper not executable: $compile_script" >&2
  exit 2
fi

base="/tmp/optimize-size.${tag}"
noacc_out="${base}.noacc.out"
acc_out="${base}.acc.out"
noacc_pretty="${base}.noacc.pretty"
acc_pretty="${base}.acc.pretty"

perl -i -pe '
  s/\bJPA\b/FPA/g;
  s/\bBEQ\b/FEQ/g;
  s/\bBNE\b/FNE/g;
  s/\bBCC\b/FCC/g;
  s/\bBCS\b/FCS/g;
  s/\bBGT\b/FGT/g;
  s/\bBLE\b/FLE/g;
  s/\bBPL\b/FPL/g;
  s/\bBMI\b/FMI/g;
' "$src"

iter=0
reverted=0

revert_line_to_long() {
  local line="$1"
  local mode="$2"
  local before
  local after

  before="$(sed -n "${line}p" "$src")"

  LINE="$line" perl -i -pe '
    if ($. == $ENV{LINE}) {
      s/\bFPA\b/JPA/g;
      s/\bFEQ\b/BEQ/g;
      s/\bFNE\b/BNE/g;
      s/\bFCC\b/BCC/g;
      s/\bFCS\b/BCS/g;
      s/\bFGT\b/BGT/g;
      s/\bFLE\b/BLE/g;
      s/\bFPL\b/BPL/g;
      s/\bFMI\b/BMI/g;
    }
  ' "$src"

  after="$(sed -n "${line}p" "$src")"
  if [[ "$before" == "$after" ]]; then
    echo "Revert failed: line $line unchanged ($mode)." >&2
    echo "Line: $before" >&2
    exit 1
  fi

  reverted=$((reverted + 1))
  if (( reverted % 20 == 0 )); then
    echo "progress reverted=$reverted last_line=$line mode=$mode"
  fi
}

while :; do
  iter=$((iter + 1))
  noacc_ok=0
  acc_ok=0

  if "$compile_script" "$src" >"$noacc_out" 2>&1; then
    noacc_ok=1
    cp "$noacc_out" "$noacc_pretty"
  fi

  if "$compile_script" "$src" -- -D USE_ACCELERATOR >"$acc_out" 2>&1; then
    acc_ok=1
    cp "$acc_out" "$acc_pretty"
  fi

  if [[ $noacc_ok -eq 1 && $acc_ok -eq 1 ]]; then
    break
  fi

  err_file="$noacc_out"
  mode="noacc"
  if [[ $noacc_ok -eq 1 ]]; then
    err_file="$acc_out"
    mode="acc"
  fi

  line="$(sed -n 's/.*line \([0-9][0-9]*\).*/\1/p' "$err_file" | head -n1)"
  if [[ -z "$line" ]]; then
    echo "Could not parse failing line from $mode build." >&2
    cat "$err_file" >&2
    exit 1
  fi

  revert_line_to_long "$line" "$mode"
done

echo "PASS iterations=$iter reverted=$reverted"
echo "noacc_pretty=$noacc_pretty"
echo "acc_pretty=$acc_pretty"
