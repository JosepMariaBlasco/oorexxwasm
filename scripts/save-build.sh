#!/usr/bin/env bash
# Pack the current WASM binaries, with a MANIFEST identifying what they were
# built from (scripts/build-manifest.sh), into OUT/oorexxwasm-build.tar.gz.
# setup-env.sh reuses such a pack, instead of installing Emscripten and
# compiling, when its MANIFEST matches the current patches: from OUT if it is
# there, else from the GitHub release made by scripts/publish-build.sh.
# Run after the final build (and oorexx/wasm/build-node.sh, build-web.sh).
# Usage: save-build.sh [BUILD_DIR=$ORX_WASM_WORK/build-wasm] [OUT=$ORX_WASM_WORK/saved-build]
set -euo pipefail
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
BUILD=$(cd "${1:-$ORX_WASM_WORK/build-wasm}" && pwd)
OUT=${2:-$ORX_WASM_WORK/saved-build}
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); S="$T/build"
mkdir -p "$S/bin" "$S/bin-node"
cp "$BUILD"/bin/rexx.{js,wasm,data,img} "$S/bin/"
mkdir -p "$S/bin/node_modules/ws" && cp "$BUILD/bin/node_modules/ws/index.js" "$S/bin/node_modules/ws/"
if [[ -d "$BUILD/bin-node" ]]; then
  (cd "$BUILD/bin-node" && cp -a rexx rexxc rxqueue rxsubcom rexx.js rexx.wasm rexx.img *.cls "$S/bin-node/")
fi
if [[ -d "$BUILD/bin-web" ]]; then      # oorexx/wasm/build-web.sh (playground)
  mkdir -p "$S/bin-web" && cp -a "$BUILD/bin-web/." "$S/bin-web/"
fi
# the build tree samples (+ support files): the test suite locates them
# relative to .RexxInfo~executable (bin-node/../samples)
mkdir -p "$S/samples" && (cd "$BUILD/samples" && cp -a *.rex *.cls *.txt "$S/samples/")
"$HERE/build-manifest.sh" > "$S/MANIFEST"
mkdir -p "$OUT"
tar -C "$T" -czf "$OUT/oorexxwasm-build.tar.gz" build
cp "$S/MANIFEST" "$OUT/MANIFEST"
rm -rf "$T"
cat "$OUT/MANIFEST"; ls -l "$OUT/oorexxwasm-build.tar.gz"
echo "release tag: $("$HERE/build-manifest.sh" --tag)"
