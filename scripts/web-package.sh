#!/usr/bin/env bash
# Build the browser distribution from the web build (oorexx/wasm/build-web.sh's
# bin-web), as two zips:
#   oorexxwasm-web-VERSION.zip         the interpreter's files for a page, the
#                                      example page (web/), serve.mjs, .htaccess
#   oorexxwasm-playground-VERSION.zip  the ooRexx Playground site
#                                      (playground/build-site.sh), + serve.mjs
# Each unpacks into a directory of the same name.
# Usage: web-package.sh VERSION [BIN_WEB=$ORX_WASM_WORK/build-wasm/bin-web]
#                       [OUT=$ORX_WASM_WORK/web-out]
#   OOREXX=$ORX_WASM_WORK/oorexx (for CPLv1.0.txt and the playground's samples)
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=${ORX_WASM_WORK:-$(cd "$HERE/.." && pwd)}
VERSION=${1:?usage: web-package.sh VERSION [BIN_WEB] [OUT]}
BIN=$(cd "${2:-$WORK/build-wasm/bin-web}" && pwd)
OUT=${3:-$WORK/web-out}
export OOREXX=${OOREXX:-$WORK/oorexx}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)

RUNTIME="ooRexx.js ooRexx-worker.js rexx.js rexx.wasm rexx.data js-realm.js polygon-clipping.umd.min.js"

# the web distribution
NAME=oorexxwasm-web-$VERSION
D=$OUT/$NAME
rm -rf "$D" "$OUT/$NAME.zip"; mkdir -p "$D"
for f in $RUNTIME; do cp "$BIN/$f" "$D/"; done
cp "$HERE"/web/index.html "$HERE"/web/app.rex "$HERE"/web/serve.mjs "$HERE"/web/README.md "$D/"
cp "$HERE/web/htaccess" "$D/.htaccess"
cp "$OOREXX/CPLv1.0.txt" "$D/"
cp "$HERE/LICENSE" "$D/LICENSE-Apache-2.0.txt"
(cd "$OUT" && zip -qr "$NAME.zip" "$NAME")

# the playground site
PNAME=oorexxwasm-playground-$VERSION
P=$OUT/$PNAME
rm -rf "$P" "$OUT/$PNAME.zip"
"$HERE/playground/build-site.sh" "$BIN" "$P" >/dev/null
cp "$HERE/web/serve.mjs" "$OOREXX/CPLv1.0.txt" "$P/"
cp "$HERE/LICENSE" "$P/LICENSE-Apache-2.0.txt"
(cd "$OUT" && zip -qr "$PNAME.zip" "$PNAME")

ls -l "$OUT/$NAME.zip" "$OUT/$PNAME.zip"
