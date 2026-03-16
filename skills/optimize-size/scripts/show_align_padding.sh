#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <pretty-listing-file>" >&2
  exit 2
fi

pretty="$1"
if [[ ! -f "$pretty" ]]; then
  echo "Missing file: $pretty" >&2
  exit 2
fi

perl -ne '
  if (/\|\s*([0-9a-fA-F]{4})\s*\|\s*([^|]*)\|\s*(.*)$/) {
    $addr = hex($1);
    $bytes = $2;
    $src = $3;

    $n = 0;
    while ($bytes =~ /\b[0-9a-fA-F]{2}\b/g) { $n++; }

    if ($src =~ /\.align\b/) {
      if (defined $prev_end && $addr > $prev_end) {
        $d = $addr - $prev_end;
        $pad += $d;
        printf("align@%04x pad=%d prev_end=%04x\n", $addr, $d, $prev_end);
      } else {
        printf("align@%04x pad=0\n", $addr);
      }
    }

    if ($n > 0) { $prev_end = $addr + $n; }
  }
  END {
    $pad ||= 0;
    print "TOTAL_ALIGN_PADDING=$pad\n";
  }
' "$pretty"
