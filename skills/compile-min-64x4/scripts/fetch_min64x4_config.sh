#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: fetch_min64x4_config.sh [--redux] [dest]

Fetches the latest Minimal 64x4 BespokeASM instruction-set configuration file.

Options:
  --redux Fetch the Minimal 64x4 Redux configuration instead of the original.

Arguments:
  dest    Optional output path. Defaults to MIN64X4_CONFIG_PATH or
          /tmp/slu4-minimal-64x4.yaml (original), and to
          MIN64X4_REDUX_CONFIG_PATH or /tmp/slu4-minimal-64x4-redux.yaml
          (--redux).
USAGE
}

variant="original"
if [[ $# -gt 0 && "$1" == "--redux" ]]; then
  variant="redux"
  shift
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ "$variant" == "redux" ]]; then
  dest="${1:-${MIN64X4_REDUX_CONFIG_PATH:-/tmp/slu4-minimal-64x4-redux.yaml}}"
  url="https://raw.githubusercontent.com/michaelkamprath/bespokeasm/main/examples/slu4-minimal-64x4-redux/slu4-minimal-64x4-redux.yaml"
else
  dest="${1:-${MIN64X4_CONFIG_PATH:-/tmp/slu4-minimal-64x4.yaml}}"
  url="https://raw.githubusercontent.com/michaelkamprath/bespokeasm/main/examples/slu4-minimal-64x4/slu4-minimal-64x4.yaml"
fi

if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$dest" "$url"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$dest" "$url"
else
  echo "Need curl or wget to fetch the Minimal 64x4 BespokeASM config." >&2
  exit 1
fi

if [[ ! -s "$dest" ]]; then
  echo "Could not fetch BespokeASM config to $dest" >&2
  exit 1
fi

printf '%s\n' "$dest"
