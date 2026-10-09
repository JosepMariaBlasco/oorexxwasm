#!/usr/bin/env bash
# Thread stress: N runs of K concurrent STARTs. Prints ok/N and first failure.
# Usage: stress.sh BIN_DIR [runs=20] [threads=10] [node flags...]
BIN=${1:?}; N=${2:-20}; K=${3:-10}; shift 3 2>/dev/null || shift $#
P="do i=1 to $K; m.i=.obj~new~start(\"hi\",i); end; s=0; do i=1 to $K; s=s+m.i~result; end; say \"sum=\"s; ::class obj; ::method hi; use arg k; return k"
want="sum=$((K*(K+1)/2))"; ok=0; shown=0
for i in $(seq "$N"); do
  out=$(cd "$BIN" && timeout 30 node "$@" ./rexx.js -e "$P" 2>&1); rc=$?
  if grep -qx "$want" <<<"$out"; then ok=$((ok+1))
  elif [ $shown = 0 ]; then shown=1; echo "-- first failure (run $i, rc=$rc):"; grep -E "Error|at |Aborted|assert" <<<"$out" | head -20; fi
done
echo "$ok/$N ok"
