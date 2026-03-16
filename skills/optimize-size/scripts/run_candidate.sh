#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <source.min64x4> [tag]

Runs full candidate optimization and prints a one-line TSV summary:
  tag  fast  long  align  g_stop_noacc  g_stop_acc  score
USAGE
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

src="$1"
tag="${2:-$(basename "${src}" .min64x4)}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$script_dir/optimize_dual.sh" "$src" "$tag"

noacc_pretty="/tmp/optimize-size.${tag}.noacc.pretty"
acc_pretty="/tmp/optimize-size.${tag}.acc.pretty"

metrics="$("$script_dir/collect_metrics.sh" "$src" "$noacc_pretty" "$acc_pretty")"

fast="$(printf '%s\n' "$metrics" | sed -n 's/^fast=//p')"
long="$(printf '%s\n' "$metrics" | sed -n 's/^long=//p')"
align="$(printf '%s\n' "$metrics" | sed -n 's/^align=//p')"
gn="$(printf '%s\n' "$metrics" | sed -n 's/^g_stop_noacc=//p')"
ga="$(printf '%s\n' "$metrics" | sed -n 's/^g_stop_acc=//p')"
score="$(printf '%s\n' "$metrics" | sed -n 's/^score=//p')"

printf 'tag\tfast\tlong\talign\tg_stop_noacc\tg_stop_acc\tscore\n'
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$tag" "$fast" "$long" "$align" "$gn" "$ga" "$score"
