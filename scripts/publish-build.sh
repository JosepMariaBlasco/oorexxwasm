#!/usr/bin/env bash
# Publish a pack made by save-build.sh as a GitHub release of this repository,
# tagged build-<hash of its MANIFEST> (build-manifest.sh --tag) on the current
# HEAD, so that setup-env.sh can download it.  Does nothing if that release
# already exists.  Needs `gh` with write access to the repository.
# Usage: publish-build.sh [OUT=$ORX_WASM_WORK/saved-build] [REPO=JosepMariaBlasco/oorexxwasm]
set -euo pipefail
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
OUT=${1:-$ORX_WASM_WORK/saved-build}
REPO=${2:-JosepMariaBlasco/oorexxwasm}
HERE=$(cd "$(dirname "$0")" && pwd)
TAG=$("$HERE/build-manifest.sh" --tag)
diff -q <("$HERE/build-manifest.sh") "$OUT/MANIFEST" >/dev/null || { echo "$OUT/MANIFEST does not match the current patches" >&2; exit 1; }
if gh api "repos/$REPO/releases/tags/$TAG" >/dev/null 2>&1; then echo "release $TAG already exists"; exit 0; fi
SHA=$(git -C "$HERE/.." rev-parse HEAD)
body=$(printf 'Prebuilt WASM binaries (bin, bin-node, bin-web, samples) for\n\n```\n%s\n```\n\n`scripts/setup-env.sh` downloads this when the patches match.' "$(cat "$OUT/MANIFEST")")
id=$(gh api "repos/$REPO/releases" -f tag_name="$TAG" -f target_commitish="$SHA" -f name="Saved build $TAG" \
       -f body="$body" -F prerelease=true --jq .id)
gh api --method POST -H "Content-Type: application/gzip" \
   "https://uploads.github.com/repos/$REPO/releases/$id/assets?name=oorexxwasm-build.tar.gz" \
   --input "$OUT/oorexxwasm-build.tar.gz" --jq '.browser_download_url'
