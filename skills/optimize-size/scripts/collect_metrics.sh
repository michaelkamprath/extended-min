#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <source.min64x4> <noacc.pretty> <acc.pretty>

Print branch-form counts and score tuple for candidate comparison.
Lexicographic score (lower is better):
  1) max(g_stop_noacc, g_stop_acc)
  2) g_stop_noacc + g_stop_acc
  3) long_count
  4) -fast_count
USAGE
}

if [[ $# -ne 3 ]]; then
  usage
  exit 2
fi

src="$1"
noacc_pretty="$2"
acc_pretty="$3"

for f in "$src" "$noacc_pretty" "$acc_pretty"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing file: $f" >&2
    exit 2
  fi
done

sym_addr() {
  local pretty="$1"
  local sym="$2"
  sed -n "s/.*| *\([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]\) |.*${sym}.*/\1/p" "$pretty" | head -n1
}

hex_or_fail() {
  local v="$1"
  local label="$2"
  if [[ -z "$v" ]]; then
    echo "Could not find $label in listing" >&2
    exit 1
  fi
  echo "$v"
}

fast_count="$( (rg -n "\\b(FPA|FEQ|FNE|FCC|FCS|FGT|FLE|FPL|FMI)\\b" "$src" || true) | wc -l | tr -d ' ' )"
long_count="$( (rg -n "\\b(JPA|BEQ|BNE|BCC|BCS|BGT|BLE|BPL|BMI)\\b" "$src" || true) | wc -l | tr -d ' ' )"
align_count="$( (rg -n "^\\s*\\.align\\b" "$src" || true) | wc -l | tr -d ' ' )"

g_stop_noacc_hex="$(hex_or_fail "$(sym_addr "$noacc_pretty" "g_stop:")" "g_stop in noacc")"
g_stop_acc_hex="$(hex_or_fail "$(sym_addr "$acc_pretty" "g_stop:")" "g_stop in acc")"

constsub_noacc_hex="$(sym_addr "$noacc_pretty" "ConstSubstitute:")"
constsub_acc_hex="$(sym_addr "$acc_pretty" "ConstSubstitute:")"
opt_noacc_hex="$(sym_addr "$noacc_pretty" "OPTIONAL ACCELERATOR HELPERS")"
opt_acc_hex="$(sym_addr "$acc_pretty" "OPTIONAL ACCELERATOR HELPERS")"

g_stop_noacc_dec=$((16#$g_stop_noacc_hex))
g_stop_acc_dec=$((16#$g_stop_acc_hex))

if (( g_stop_noacc_dec > g_stop_acc_dec )); then
  score1="$g_stop_noacc_dec"
else
  score1="$g_stop_acc_dec"
fi
score2=$((g_stop_noacc_dec + g_stop_acc_dec))
score3="$long_count"
score4=$((-fast_count))

printf 'fast=%s\n' "$fast_count"
printf 'long=%s\n' "$long_count"
printf 'align=%s\n' "$align_count"
printf 'g_stop_noacc=0x%s\n' "$g_stop_noacc_hex"
printf 'g_stop_acc=0x%s\n' "$g_stop_acc_hex"
printf 'constsub_noacc=%s\n' "${constsub_noacc_hex:-NA}"
printf 'constsub_acc=%s\n' "${constsub_acc_hex:-NA}"
printf 'opt_section_noacc=%s\n' "${opt_noacc_hex:-NA}"
printf 'opt_section_acc=%s\n' "${opt_acc_hex:-NA}"
printf 'score=max_gstop:%s,sum_gstop:%s,long:%s,neg_fast:%s\n' "$score1" "$score2" "$score3" "$score4"
