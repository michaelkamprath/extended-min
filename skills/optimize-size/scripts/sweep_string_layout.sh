#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <source.min64x4>

Creates and benchmarks focused string-layout variants in /tmp:
  1) baseline (as-is)
  2) bigonly      : move error01..error32 block to tail error section
  3) big_plus_22  : bigonly + move error22 to tail
  4) big_plus_33  : bigonly + move error33 to tail

For each variant it runs dual-mode optimization and prints a TSV row.
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

src="$1"
if [[ ! -f "$src" ]]; then
  echo "Missing source: $src" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmpdir="$(mktemp -d /tmp/opt-size-variants.XXXXXX)"

make_bigonly() {
  local in="$1"
  local out="$2"
  local block_file
  block_file="$(mktemp /tmp/opt-size-block.XXXXXX)"
  awk '/^error01:/{f=1} f{print} /^error32:/{f=0}' "$in" > "$block_file"

  if [[ ! -s "$block_file" ]]; then
    cp "$in" "$out"
    rm -f "$block_file"
    return 0
  fi

  awk '
    /^error01:/ {skip=1}
    skip { if (/^error32:/) {skip=0}; next }
    { print }
  ' "$in" > "$out.tmp"

  awk -v bf="$block_file" '
    BEGIN { inserted=0 }
    /^; OPTIONAL ACCELERATOR HELPERS/ && inserted==0 {
      print "; --------------------------------------------------------------------------------------"
      print "; ERROR STRINGS"
      print "; --------------------------------------------------------------------------------------"
      while ((getline line < bf) > 0) print line
      close(bf)
      print ""
      inserted=1
    }
    { print }
  ' "$out.tmp" > "$out"

  rm -f "$out.tmp" "$block_file"
}

move_single_to_tail() {
  local in="$1"
  local out="$2"
  local label="$3"
  local line_file
  line_file="$(mktemp /tmp/opt-size-line.XXXXXX)"
  sed -n "s/^\(${label}:.*\)$/\1/p" "$in" | head -n1 > "$line_file"
  if [[ ! -s "$line_file" ]]; then
    cp "$in" "$out"
    rm -f "$line_file"
    return 0
  fi

  awk -v label="$label:" 'BEGIN{done=0}
    !done && index($0,label)==1 {done=1; next}
    {print}
  ' "$in" > "$out.tmp"

  if rg -q "^; ERROR STRINGS$" "$out.tmp"; then
    awk -v lf="$line_file" '
      /^; ERROR STRINGS$/ && !ins { print; next }
      /^; --------------------------------------------------------------------------------------$/ && !seen { seen=1; print; next }
      /^; --------------------------------------------------------------------------------------$/ && seen && !ins {
        while ((getline line < lf) > 0) print line
        close(lf)
        ins=1
      }
      { print }
      END {
        if (!ins) {
          while ((getline line < lf) > 0) print line
          close(lf)
        }
      }
    ' "$out.tmp" > "$out"
  else
    awk -v lf="$line_file" '
      BEGIN{ins=0}
      /^; OPTIONAL ACCELERATOR HELPERS/ && ins==0 {
        print "; --------------------------------------------------------------------------------------"
        print "; ERROR STRINGS"
        print "; --------------------------------------------------------------------------------------"
        while ((getline line < lf) > 0) print line
        close(lf)
        print ""
        ins=1
      }
      { print }
      END {
        if (ins==0) {
          print "; --------------------------------------------------------------------------------------"
          print "; ERROR STRINGS"
          print "; --------------------------------------------------------------------------------------"
          while ((getline line < lf) > 0) print line
          close(lf)
        }
      }
    ' "$out.tmp" > "$out"
  fi

  rm -f "$out.tmp" "$line_file"
}

v_baseline="$tmpdir/v_baseline.min64x4"
v_bigonly="$tmpdir/v_bigonly.min64x4"
v_big22="$tmpdir/v_big_plus_22.min64x4"
v_big33="$tmpdir/v_big_plus_33.min64x4"

cp "$src" "$v_baseline"
make_bigonly "$src" "$v_bigonly"
move_single_to_tail "$v_bigonly" "$v_big22" "error22"
move_single_to_tail "$v_bigonly" "$v_big33" "error33"

echo "tmpdir=$tmpdir"
"$script_dir/run_candidate.sh" "$v_baseline" "v_baseline" | tail -n1
"$script_dir/run_candidate.sh" "$v_bigonly" "v_bigonly" | tail -n1
"$script_dir/run_candidate.sh" "$v_big22" "v_big_plus_22" | tail -n1
"$script_dir/run_candidate.sh" "$v_big33" "v_big_plus_33" | tail -n1
