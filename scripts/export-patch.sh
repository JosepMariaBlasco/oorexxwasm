#!/usr/bin/env bash
# Export our changes in $ORX_WASM_WORK/oorexx as ONE numbered patch containing
# only the delta over the patches that precede it, and verify that
# (r$REV + earlier patches + new patch) reproduces the working tree exactly.
# Usage: export-patch.sh NNNN-name.patch      (e.g. 0002-pthread-locks-recursion.patch)
#   An existing file with that name is overwritten (re-export during a session);
#   only patches sorting BEFORE it are used as the base.
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -euo pipefail
NAME=${1:?usage: export-patch.sh NNNN-name.patch}
REV=${OOREXX_REV:-13263}
SRC=${OOREXX:-$ORX_WASM_WORK/oorexx}
PROJECT=$(cd "$(dirname "$0")/.." && pwd)
BASE=$(mktemp -d)/base
svn export -q -r "$REV" https://svn.code.sf.net/p/oorexx/code-0/main/trunk "$BASE" 2>/dev/null || {
  # offline fallback: revert a copy of the checkout
  cp -a "$SRC" "$BASE"; (cd "$BASE" && svn revert -q -R . && svn status | awk '/^\?/{print $2}' | xargs -r rm -rf); }
for p in "$PROJECT"/patches/*.patch; do
  [[ "$(basename "$p")" < "$NAME" ]] || continue
  (cd "$BASE" && patch -p1 -s < "$p")
done
OUT="$PROJECT/patches/$NAME"
(cd "$(dirname "$BASE")" && diff -ruN -x .svn base "$SRC" | sed -E "s|^--- base/([^\t]*).*|--- a/\1|; s|^\+\+\+ $SRC/([^\t]*).*|+++ b/\1|; s|^diff -ruN -x .svn base/([^ ]*) .*|diff -ruN a/\1 b/\1|") > "$OUT" || true
# verify
(cd "$BASE" && patch -p1 -s < "$OUT")
if diff -r -x .svn -q "$BASE" "$SRC"; then echo "OK: $OUT reproduces $SRC ($(grep -c '^+++ ' "$OUT") files)"; else echo "MISMATCH"; exit 1; fi
rm -rf "$(dirname "$BASE")"
