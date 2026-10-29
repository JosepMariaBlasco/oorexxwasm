#!/usr/bin/env bash
# Build the npm package oorexxwasm from the Node command-line build
# (wasm/build-node.sh's bin-node): npm/bin (launchers in JavaScript, so that
# npm makes the commands on every platform), lib/ = bin-node without its
# shell launchers, the README, ooRexx's license.  Writes the package
# directory and the tarball npm pack makes.
# Usage: npm-package.sh VERSION [BIN_NODE=$ORX_WASM_WORK/build-wasm/bin-node]
#                       [OUT=$ORX_WASM_WORK/npm-out]
#   OOREXX=$ORX_WASM_WORK/oorexx (for CPLv1.0.txt), OOREXX_REV (description)
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=${ORX_WASM_WORK:-$(cd "$HERE/.." && pwd)}
VERSION=${1:?usage: npm-package.sh VERSION [BIN_NODE] [OUT]}
BIN=$(cd "${2:-$WORK/build-wasm/bin-node}" && pwd)
OUT=${3:-$WORK/npm-out}
OOREXX=${OOREXX:-$WORK/oorexx}
REV=${OOREXX_REV:-13331}

PKG=$OUT/package
rm -rf "$PKG"; mkdir -p "$PKG/bin" "$PKG/lib"
cp "$HERE"/npm/bin/*.js "$PKG/bin/"
chmod +x "$PKG"/bin/{rexx,rexxc,rxqueue,rxsubcom}.js
for f in "$BIN"/*; do
  case "$(basename "$f")" in rexx|rexxc|rxqueue|rxsubcom|node_modules) continue ;; esac
  cp -r "$f" "$PKG/lib/"
done
cp "$HERE/npm/README.md" "$PKG/"
cp "$OOREXX/CPLv1.0.txt" "$PKG/"
cat > "$PKG/package.json" <<JSON
{
  "name": "oorexxwasm",
  "version": "$VERSION",
  "description": "ooRexx 5.3.0 (trunk r$REV) compiled to WebAssembly, for Node.js: rexx, rexxc, rxqueue, rxsubcom. An experimental port, not an official RexxLA distribution.",
  "keywords": ["rexx", "oorexx", "interpreter", "webassembly", "wasm"],
  "homepage": "https://github.com/JosepMariaBlasco/oorexxwasm",
  "bugs": "https://github.com/JosepMariaBlasco/oorexxwasm/issues",
  "repository": { "type": "git", "url": "git+https://github.com/JosepMariaBlasco/oorexxwasm.git" },
  "license": "CPL-1.0",
  "bin": {
    "rexx": "bin/rexx.js",
    "rexxc": "bin/rexxc.js",
    "rxqueue": "bin/rxqueue.js",
    "rxsubcom": "bin/rxsubcom.js",
    "rexx-wasm": "bin/rexx.js",
    "rexxc-wasm": "bin/rexxc.js",
    "rxqueue-wasm": "bin/rxqueue.js",
    "rxsubcom-wasm": "bin/rxsubcom.js"
  },
  "files": ["bin", "lib", "README.md", "CPLv1.0.txt"],
  "engines": { "node": ">=22" }
}
JSON
(cd "$OUT" && npm pack "$PKG" --silent)
ls -l "$OUT"/oorexxwasm-"$VERSION".tgz
