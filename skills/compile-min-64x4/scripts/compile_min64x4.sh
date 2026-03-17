#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: compile_min64x4.sh <source.min64x4> [-- <extra bespokeasm args>]

Compiles a Minimal 64x4 assembly source using BespokeASM and a fetched copy of
the Minimal 64x4 instruction-set configuration from the BespokeASM GitHub repo.

Examples:
  compile_min64x4.sh extended-min.min64x4
  compile_min64x4.sh extended-min.min64x4 -- -D USE_ACCELERATOR
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

src="$1"
shift || true

if [[ ! -f "$src" ]]; then
  echo "Source not found: $src" >&2
  exit 2
fi

if ! command -v bespokeasm >/dev/null 2>&1; then
  echo "Missing required command: bespokeasm" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
fetch_script="$script_dir/fetch_min64x4_config.sh"

if [[ ! -x "$fetch_script" ]]; then
  echo "Missing required helper: $fetch_script" >&2
  exit 2
fi

extra_args=()
if [[ $# -gt 0 ]]; then
  if [[ "$1" != "--" ]]; then
    usage
    exit 2
  fi
  shift
  extra_args=("$@")
fi

cfg="${MIN64X4_CONFIG_PATH:-/tmp/slu4-minimal-64x4.yaml}"

if [[ ! -s "$cfg" ]]; then
  "$fetch_script" "$cfg" >/dev/null
fi

if [[ ! -s "$cfg" ]]; then
  echo "Could not fetch BespokeASM config to $cfg" >&2
  exit 1
fi

bespokeasm compile -c "$cfg" -n -p "$src" "${extra_args[@]}"
