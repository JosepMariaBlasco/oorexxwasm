#!/usr/bin/env bash
# Publish a pack made by save-build.sh on the branch `saved-build` of this
# repository, as oorexxwasm-build-<hash>.tar.gz (hash: build-manifest.sh
# --tag), so that setup-env.sh can download it.  The branch holds one
# orphan commit with the latest pack only, replaced (force-pushed) each time,
# so old binaries do not pile up in the history of main.  The commit is made
# inside this clone (git plumbing) and pushed from it, so it uses the clone's
# credentials (also in GitHub Actions).
# Usage: publish-build.sh [OUT=$ORX_WASM_WORK/saved-build] [REMOTE=origin]
set -euo pipefail
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
OUT=${1:-$ORX_WASM_WORK/saved-build}
REMOTE=${2:-origin}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
TAG=$("$HERE/build-manifest.sh" --tag)
diff -q <("$HERE/build-manifest.sh") "$OUT/MANIFEST" >/dev/null || { echo "$OUT/MANIFEST does not match the current patches" >&2; exit 1; }
g() { git -C "$REPO" "$@"; }
readme=$(printf 'Prebuilt WASM binaries for the patches listed in MANIFEST.\nscripts/setup-env.sh downloads oorexxwasm-%s.tar.gz when the patches match.\n' "$TAG" | g hash-object -w --stdin)
manifest=$(g hash-object -w "$OUT/MANIFEST")
pack=$(g hash-object -w "$OUT/oorexxwasm-build.tar.gz")
tree=$(printf '100644 blob %s\tMANIFEST\n100644 blob %s\tREADME.md\n100644 blob %s\toorexxwasm-%s.tar.gz\n' \
         "$manifest" "$readme" "$pack" "$TAG" | g mktree)
export GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME:-$(g config user.name || echo "saved build")}
export GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL:-$(g config user.email || echo "noreply@github.com")}
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
commit=$(g commit-tree "$tree" -m "Saved build $TAG (main at $(g rev-parse --short HEAD))")
g push -q -f "$REMOTE" "$commit:refs/heads/saved-build"
echo "published oorexxwasm-$TAG.tar.gz on branch saved-build ($commit)"
