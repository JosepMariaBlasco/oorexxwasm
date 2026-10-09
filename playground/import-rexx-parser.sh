#!/usr/bin/env bash
# Take the part of a Rexx Parser release the playground needs into
# playground/rexx-parser/ (vendored; build-site.sh bundles it).
# Usage: import-rexx-parser.sh Rexx-Parser-X.Y-YYYYMMDD[-HHMM].zip
#
# Chosen by tracing the files opened (strace) while running highlight.rex
# (-a, -h, -s light, -u, programs with errors), elements.rex, a program that
# ::requires Rexx.Parser.cls and one that calls highlight as a routine;
# then rounded up to whole directories. Left out: rexxpub (md2*), cgi,
# docs, tests, samples, js, csl, the non-Rexx css, other utilities.
set -euo pipefail
ZIP=$(realpath "$1")
DEST=$(cd "$(dirname "$0")" && pwd)/rexx-parser
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"
SRC=$TMP; [ -f "$SRC/bin/Rexx.Parser.cls" ] || SRC=$(dirname "$(dirname "$(find "$TMP" -name Rexx.Parser.cls | head -1)")")
rm -rf "$DEST"; mkdir -p "$DEST/bin/modules/print" "$DEST/css"
cp "$SRC"/LICENSE "$SRC"/NOTICE "$DEST/"
cp "$SRC"/bin/Rexx.Parser.cls "$SRC"/bin/highlight.rex "$SRC"/bin/elements.rex "$DEST/bin/"
cp -r "$SRC"/bin/parser "$SRC"/bin/HLDrivers "$DEST/bin/"
cp "$SRC"/bin/modules/print/print.cls "$DEST/bin/modules/print/"
cp "$SRC"/css/rexx-*.css "$DEST/css/"
grep -o 'current release is [^.]*\.[0-9]*, refresh [0-9]*' "$SRC/readme.md" > "$DEST/VERSION" || basename "$ZIP" .zip > "$DEST/VERSION"
echo "from $(basename "$ZIP" | sed -E "s/^[0-9a-f]{8}-//")" >> "$DEST/VERSION"
du -sh "$DEST"; find "$DEST" -type f | wc -l; cat "$DEST/VERSION"
