#!/usr/bin/env bash
# Relink rexx.js/rexx.wasm from an existing build with extra/overridden flags,
# without recompiling.  Output goes to OUTDIR (rexx.img, preload files reused).
# Usage: relink.sh BUILD_DIR OUTDIR [extra em++ flags...]
#   e.g. relink.sh $ORX_WASM_WORK/build-dbg /tmp/v1 -sASSERTIONS=2 -sSAFE_HEAP=1
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -euo pipefail
BUILD=$(cd "$1" && pwd); OUT=$2; shift 2
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
export EM_CONFIG="$BUILD/.emscripten"
cmd=$(cat "$BUILD/CMakeFiles/rexx_exe.dir/link.txt")
cmd=${cmd//-o bin\/rexx.js/-o $OUT\/rexx.js}
cd "$BUILD" && eval "$cmd $*"
ls -l "$OUT"/rexx.js "$OUT"/rexx.wasm | awk '{print $5, $9}'
