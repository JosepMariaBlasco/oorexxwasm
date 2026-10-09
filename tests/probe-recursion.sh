#!/usr/bin/env bash
# Deep-recursion cases (tests/recursion-cases.txt): each must end in a clean
# Rexx Error 11 (or a trapped 11.1), never a JS RangeError / dead runtime.
# Usage: probe-recursion.sh BIN [node|browser|both]
# (browser mode starts the COOP/COEP server on :8000 for BIN if none is running)
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
BIN=$(cd "${1:?usage: probe-recursion.sh BIN [node|browser|both]}" && pwd); MODE=${2:-both}
HERE=$(cd "$(dirname "$0")" && pwd)
pids=()
if [[ $MODE != node ]]; then
  # same servers as probe-browser.sh, started here if not running
  cp "$HERE/t.html" "$BIN/"
  if ! (exec 3<>/dev/tcp/127.0.0.1/8000) 2>/dev/null; then
    python3 "${OOREXX:-$ORX_WASM_WORK/oorexx}/wasm/tests/http_isolated.py" "$BIN" >/dev/null 2>&1 & pids+=($!); sleep 1
  fi
fi
pat='depth [0-9]+|trapped[^|]*|parsed[^|]*|Error 11 [^|]*|RangeError[^|]*|HANG|exited rc=-?[0-9]+'
while IFS=$'\t' read -r name prog; do
  [[ -z "$name" ]] && continue
  if [[ $MODE != browser ]]; then
    printf "node    %-8s " "$name"
    (cd "$BIN" && timeout 120 node rexx.js -e "$prog" 2>&1) | grep -v '^ *[0-9]* \*-\*' | tr '\n' '|' | grep -oE "$pat" | head -1
  fi
  if [[ $MODE != node ]]; then
    printf "browser %-8s " "$name"
    (timeout 60 python3 "$HERE/browser_run.py" "$prog" 2>&1 || echo HANG) | tr '\n' '|' | grep -oE "$pat" | head -2 | tr '\n' ' '; echo
  fi
done < "$HERE/recursion-cases.txt"
for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done
