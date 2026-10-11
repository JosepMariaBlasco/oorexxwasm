#!/bin/sh
# run.sh REXX [CASE...]: runs the cmdhandler torture cases, each in a process
# of its own, and sums up.  REXX is the command that runs a Rexx program (it
# may have words: "rexx", "/path/bin-node/rexx", a launcher...).
#   TORTURE_SCALE    multiplies the counts (default 1; e.g. 0.1 for WASM)
#   TORTURE_TIMEOUT  seconds per case (default 900)
#   TORTURE_OUT      where the logs go (default a new temporary directory)
# A case passes when it exits 0. CRASH = killed by a signal; ASAN = an
# AddressSanitizer report in its output (a sanitized build). Exit status 1
# when any case did not pass.
REXX=${1:?usage: run.sh REXX [CASE...]}; shift
D=$(cd "$(dirname "$0")" && pwd)
T=${TORTURE_TIMEOUT:-900}
OUT=${TORTURE_OUT:-$(mktemp -d "${TMPDIR:-/tmp}/cmdhandler-torture.XXXXXX")}
mkdir -p "$OUT"
if [ $# -eq 0 ]; then set -- $(cd "$D" && ls t[0-9]*.rex); fi
bad=0
echo "logs in $OUT (scale ${TORTURE_SCALE:-1})"
for c in "$@"; do
  c=${c%.rex}.rex
  t0=$(date +%s)
  ( cd "$D" && timeout -k 10 "$T" $REXX "$D/$c" ) > "$OUT/${c%.rex}.log" 2>&1
  st=$?
  t1=$(date +%s)
  case $st in
    0) r=PASS ;;
    1) r=FAIL ;;
    124|137) r=TIMEOUT ;;
    *) if [ $st -gt 128 ] && [ $st -le 192 ]; then r="CRASH(signal $((st - 128)))"
       else r="EXIT($st)"; fi ;;   # a Rexx error ends with 256 - its number
  esac
  # (UBSan's vptr reports are false positives: the interpreter restores its
  # image by setting virtual table pointers itself)
  if grep -q "ERROR: AddressSanitizer" "$OUT/${c%.rex}.log" ||
     grep "runtime error:" "$OUT/${c%.rex}.log" | grep -qv "member call on address\|downcast of address"; then r="ASAN"; fi
  [ "$r" = PASS ] || bad=1
  sum=$(grep -E '^[0-9]+ passed, [0-9]+ failed' "$OUT/${c%.rex}.log" | tail -1)
  printf '%-24s %-18s %5ss  %s\n' "${c%.rex}" "$r" $((t1 - t0)) "$sum"
  [ "$r" = PASS ] || grep -E '^FAIL|UNEXPECTED|ERROR: AddressSanitizer|SUMMARY|runtime error:|Error [0-9]' "$OUT/${c%.rex}.log" |
    grep -v "member call on address\|downcast of address" | head -8 | sed 's/^/    /'
done
exit $bad
