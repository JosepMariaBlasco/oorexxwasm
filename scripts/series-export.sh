#!/usr/bin/env bash
# Export the commits on top of tag "base" of a series repository (see
# series-repo.sh) into patches/ as NNNN-name.patch (git format, which
# `svn patch` applies including executable bits).  The names are kept from the
# current patches/ by position; extra commits get a name from their
# subject.  Also writes patches/SHA256SUMS.
# Usage: series-export.sh [DIR=$ORX_WASM_WORK/series-git]
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -euo pipefail
DIR=${1:-$ORX_WASM_WORK/series-git}
PROJECT=$(cd "$(dirname "$0")/.." && pwd)
P="$PROJECT/patches"; T=$(mktemp -d)
mapfile -t names < <(ls "$P"/*.patch 2>/dev/null | xargs -n1 basename | sed -E 's/^[0-9]{4}-//; s/\.patch$//')
(cd "$DIR" && git format-patch -q --no-signature --zero-commit -o "$T" base..HEAD)
rm -f "$P"/*.patch
i=0
for f in $(ls "$T" | sort); do
  n=${names[$i]:-$(sed -E 's/^[0-9]{4}-//; s/\.patch$//' <<<"$f" | tr 'A-Z' 'a-z')}
  mv "$T/$f" "$P/$(printf '%04d' $((i+1)))-$n.patch"; i=$((i+1))
done
(cd "$P" && sha256sum [0-9]*.patch > SHA256SUMS)
ls "$P"
