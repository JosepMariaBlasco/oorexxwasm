#!/usr/bin/env bash
# Publish a pack made by save-build.sh on the branch `saved-build` of this
# repository, as oorexxwasm-build-<hash>.tar.gz (hash: build-manifest.sh
# --tag), so that setup-env.sh can download it.  The branch holds one
# orphan commit with the latest pack only, replaced (force-pushed) each time,
# so old binaries do not pile up in the history of main.
# Needs push access to the repository.
# Usage: publish-build.sh [OUT=$ORX_WASM_WORK/saved-build] [REMOTE=origin]
set -euo pipefail
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
OUT=${1:-$ORX_WASM_WORK/saved-build}
REMOTE=${2:-origin}
HERE=$(cd "$(dirname "$0")" && pwd)
TAG=$("$HERE/build-manifest.sh" --tag)
diff -q <("$HERE/build-manifest.sh") "$OUT/MANIFEST" >/dev/null || { echo "$OUT/MANIFEST does not match the current patches" >&2; exit 1; }
URL=$(git -C "$HERE/.." remote get-url "$REMOTE")
T=$(mktemp -d)
git -C "$T" init -q -b saved-build
cp "$OUT/oorexxwasm-build.tar.gz" "$T/oorexxwasm-$TAG.tar.gz"
cp "$OUT/MANIFEST" "$T/MANIFEST"
printf 'Prebuilt WASM binaries for the patches listed in MANIFEST.\nscripts/setup-env.sh downloads oorexxwasm-%s.tar.gz when the patches match.\n' "$TAG" > "$T/README.md"
git -C "$T" add -A
git -C "$T" -c user.name="$(git -C "$HERE/.." config user.name || echo build)" \
    -c user.email="$(git -C "$HERE/.." config user.email || echo build@localhost)" \
    commit -q -m "Saved build $TAG"
git -C "$T" push -q -f "$URL" saved-build:saved-build
rm -rf "$T"
echo "published oorexxwasm-$TAG.tar.gz on branch saved-build"
