#!/usr/bin/env bash
# Run the official ooRexx test suite one test group per process (a crash or
# hang only loses that group) and collect a CSV:
#   group,status,ran,assertions,failures,errors,seconds
# status: ok | fail | crash | timeout | noresult
# Usage: run-suite.sh REXX_CMD OUTDIR [JOBS=2] [TIMEOUT=300] [PATTERN]
#   REXX_CMD: e.g. $ORX_WASM_WORK/build-wasm/bin-node/rexx  or  $ORX_WASM_WORK/build-native/bin/rexx
#   PATTERN : optional grep -E filter on the group path
# Needs the suite checked out in $SUITE (default $ORX_WASM_WORK/oorexx-test).
# Groups that share system-wide state through rxapi (the macrospace) run one
# after another at the end, never alongside each other: $SERIAL.
# Resumable: if OUTDIR/results.csv exists, groups that already have a line
# there are skipped and new lines are appended (a VM or CI runner may be
# recycled mid-run, killing it: just run it again).
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -u
REXX=${1:?}; OUT=${2:?}; JOBS=${3:-2}; TMO=${4:-300}; PAT=${5:-.}
SUITE=${SUITE:-$ORX_WASM_WORK/oorexx-test}
SERIAL=${SERIAL:-'API/classic/CLASSIC|API/oo/FUNCTION|rexxutil/Macrospace'}
mkdir -p "$OUT/logs"; OUT=$(cd "$OUT" && pwd)
cd "$SUITE"
export PATH=$SUITE:$SUITE/framework:$PATH REXX OUT TMO SUITE
find ooRexx -name '*.testGroup' | grep -E "$PAT" | sort > "$OUT/all.txt"
grep -vE "$SERIAL" "$OUT/all.txt" > "$OUT/groups.txt"
grep -E "$SERIAL" "$OUT/all.txt" > "$OUT/serial.txt"
one() {
  g=$1; id=${g//\//_}; log="$OUT/logs/$id.log"; t0=$(date +%s)
  # each group runs in its own scratch copy dir? no: tests write temp files next
  # to themselves, so groups in the same directory must not run concurrently.
  timeout "$TMO" "$REXX" testOORexx.rex -R "$(dirname "$g")" -f "$(basename "$g" .testGroup)" -U > "$log" 2>&1
  rc=$?; t1=$(date +%s)
  ran=$(grep -m1 '^Tests ran:' "$log" | awk '{print $3}')
  asr=$(grep -m1 '^Assertions:' "$log" | awk '{print $2}')
  fl=$(grep -m1 '^Failures:' "$log" | awk '{print $2}')
  er=$(grep -m1 '^Errors:' "$log" | awk '{print $2}')
  if [ $rc = 124 ]; then st=timeout
  elif [ -z "$ran" ]; then if grep -q 'RuntimeError\|Aborted\|worker sent an error\|Segmentation' "$log"; then st=crash; else st=noresult; fi
  elif [ "${fl:-0}" = 0 ] && [ "${er:-0}" = 0 ]; then st=ok
  else st=fail; fi
  echo "$g,$st,${ran:-},${asr:-},${fl:-},${er:-},$((t1-t0))"
}
export -f one
# serialise per directory (tests create temp files in their own directory)
awk -F/ '{d=$0; sub(/\/[^\/]*$/,"",d); print d}' "$OUT/groups.txt" | sort -u > "$OUT/dirs.txt"
run_dir() { grep -E "^$1/[^/]+$" "$OUT/groups.txt" | while read -r g; do
  grep -q "^$g," "$OUT/results.csv" || one "$g"; done; }
export -f run_dir
[ -s "$OUT/results.csv" ] || echo "group,status,ran,assertions,failures,errors,seconds" > "$OUT/results.csv"
xargs -P "$JOBS" -I{} bash -c 'run_dir "$@"' _ {} < "$OUT/dirs.txt" >> "$OUT/results.csv"
while read -r g; do grep -q "^$g," "$OUT/results.csv" || one "$g"; done < "$OUT/serial.txt" >> "$OUT/results.csv"
awk -F, 'NR>1{n++; s[$2]++; ran+=$3; f+=$5; e+=$6} END{printf "groups %d:", n; for(k in s) printf " %s=%d", k, s[k]; printf " | tests %d failures %d errors %d\n", ran, f, e}' "$OUT/results.csv"
