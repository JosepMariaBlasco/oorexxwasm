#!/usr/bin/env bash
# Rebuild the ooRexx/WASM working environment from scratch.
#   1. Check out ooRexx from SVN at a fixed revision into $OOREXX
#   2. Apply every patch in patches/ in lexical order
#   3. If a saved build matches the current patches (MANIFEST, see
#      save-build.sh), install it into $BUILD/bin, bin-node and bin-web and
#      stop: no emsdk, no compilation (~1 min total).  The pack is looked for
#      in $SAVED, then downloaded from this repository's branch saved-build
#      as oorexxwasm-`build-manifest.sh --tag`.tar.gz (publish-build.sh).
#   4. Otherwise install Emscripten via emsdk (skipped if already present)
#      and build the WASM runtime into $BUILD
# Everything goes under $ORX_WASM_WORK, by default the directory that
# contains this repository's clone.
# Usage: setup-env.sh [--no-build | --rebuild]
#   --no-build  checkout + patches + emsdk, no build
#   --rebuild   ignore the saved binaries and compile
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -euo pipefail

REV=${OOREXX_REV:-13263}
EMVER=${EMVER:-6.0.9}
OOREXX=${OOREXX:-$ORX_WASM_WORK/oorexx}
BUILD=${BUILD:-$ORX_WASM_WORK/build-wasm}
EMSDK=${EMSDK_DIR:-$ORX_WASM_WORK/emsdk}
TOOL=$ORX_WASM_WORK/wasmtool
SAVED=${SAVED:-$ORX_WASM_WORK/saved-build}
RAW_URL=${RAW_URL:-https://raw.githubusercontent.com/JosepMariaBlasco/oorexxwasm/saved-build}
PROJECT=$(cd "$(dirname "$0")/.." && pwd)

command -v svn >/dev/null || { apt-get update -qq >/dev/null; apt-get install -y -q subversion >/dev/null; }

if [[ ! -d "$OOREXX/.svn" ]]; then
  echo "== svn checkout r$REV -> $OOREXX"
  svn checkout -q -r "$REV" https://svn.code.sf.net/p/oorexx/code-0/main/trunk "$OOREXX"
  for p in "$PROJECT"/patches/*.patch; do
    echo "== apply $(basename "$p")"
    (cd "$OOREXX" && svn patch -q "$p")   # svn patch: git format, executable bits
  done
else
  echo "== $OOREXX already exists; not re-applying patches"
fi

# saved binaries for exactly these patches?
install_pack() {   # $1: oorexxwasm-build.tar.gz
  local T; T=$(mktemp -d)
  tar -C "$T" -xzf "$1"
  diff -q <("$PROJECT/scripts/build-manifest.sh") "$T/build/MANIFEST" >/dev/null || { rm -rf "$T"; return 1; }
  echo "== saved build matches the patches: installing it -> $BUILD"
  mkdir -p "$BUILD"
  rm -rf "$BUILD/bin" "$BUILD/bin-node" "$BUILD/bin-web"
  cp -a "$T/build/bin" "$BUILD/bin"
  [[ -d "$T/build/bin-node" ]] && cp -a "$T/build/bin-node" "$BUILD/bin-node"
  [[ -d "$T/build/bin-web" ]] && cp -a "$T/build/bin-web" "$BUILD/bin-web"
  [[ -d "$T/build/samples" ]] && { rm -rf "$BUILD/samples"; cp -a "$T/build/samples" "$BUILD/samples"; }
  rm -rf "$T"
}
if [[ "${1:-}" == "" ]]; then
  TAG=$("$PROJECT/scripts/build-manifest.sh" --tag)
  if [[ -f "$SAVED/oorexxwasm-build.tar.gz" ]] && install_pack "$SAVED/oorexxwasm-build.tar.gz"; then
    echo "== done (from $SAVED; no emsdk, no compilation; use --rebuild to compile)"; exit 0
  fi
  echo "== looking for the saved build $TAG"
  mkdir -p "$SAVED"
  if curl -fsSL -o "$SAVED/oorexxwasm-build.tar.gz.part" "$RAW_URL/oorexxwasm-$TAG.tar.gz"; then
    mv "$SAVED/oorexxwasm-build.tar.gz.part" "$SAVED/oorexxwasm-build.tar.gz"
    if install_pack "$SAVED/oorexxwasm-build.tar.gz"; then
      echo "== done (saved build $TAG; no emsdk, no compilation; use --rebuild to compile)"; exit 0
    fi
  fi
  rm -f "$SAVED/oorexxwasm-build.tar.gz.part"
  echo "== no saved build for these patches: compiling"
fi

if [[ ! -x "$EMSDK/upstream/emscripten/emcc" ]]; then
  echo "== emsdk $EMVER"
  [[ -d "$EMSDK" ]] || git clone -q --depth 1 https://github.com/emscripten-core/emsdk "$EMSDK"
  (cd "$EMSDK" && ./emsdk install "$EMVER" >/dev/null && ./emsdk activate "$EMVER" >/dev/null)
fi
mkdir -p "$TOOL" && ln -sfn "$EMSDK/upstream" "$TOOL/install"

[[ "${1:-}" == "--no-build" ]] && exit 0
[[ "${1:-}" == "" || "${1:-}" == "--rebuild" ]] || { echo "unknown option $1" >&2; exit 2; }
echo "== build -> $BUILD"
(cd "$OOREXX" && JOBS=$(nproc) ./wasm/build-wasm.sh "$TOOL" "$BUILD")
# the Node command-line build and the browser build (relink only)
echo "== Node CLI build -> $BUILD/bin-node"
"$OOREXX/wasm/build-node.sh" "$BUILD" >/dev/null
echo "== web build -> $BUILD/bin-web"
"$OOREXX/wasm/build-web.sh" "$BUILD" >/dev/null
echo "== done"
