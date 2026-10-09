#!/bin/bash
# Compare our JDOR (web build) with Rony's Java JDOR, headless, on the JDOR
# samples of BSF4ooRexx850: both run the same command streams (captured from
# the samples' own canonical output, ADDRESS ... WITH OUTPUT), and cmp.py
# diffs results (RC), canonical output, error messages and the saved images.
# Usage: compare.sh [BIN_WEB=$ORX_WASM_WORK/build-wasm/bin-web] [ENGINE=chromium]
# Work dir: $WORK (default $ORX_WASM_WORK/jdor-work); report: $WORK/cmp/*/side.png
# Needs: svn, a JDK (apt install openjdk-21-jdk-headless), Python Playwright.
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=$(cd "${1:-$ORX_WASM_WORK/build-wasm/bin-web}" && pwd); ENGINE=${2:-chromium}
export WORK=${WORK:-$ORX_WASM_WORK/jdor-work}
REV=1125; SVN=https://svn.code.sf.net/p/bsf4oorexx/code
mkdir -p "$WORK"/{java/src,samples,cmds}
if [ ! -f "$WORK/java/classes/org/oorexx/handlers/jdor/JavaDrawingHandler.class" ]; then
  mkdir -p "$WORK/java/src/org/oorexx/handlers/jdor"
  svn cat -r $REV "$SVN/branches/850/bsf4oorexx.dev/source_java/JavaDrawingHandler.java" |
    iconv -f latin1 -t utf-8 > "$WORK/java/src/org/oorexx/handlers/jdor/JavaDrawingHandler.java"
  cp -r "$HERE/harness/org" "$WORK/java/src/"
  (cd "$WORK/java/src" && javac -nowarn -d ../classes $(find . -name '*.java') 2>&1 | grep -v '^Note:\|JAVA_TOOL' || true)
fi
for f in $(svn ls -r $REV "$SVN/branches/850/samples" | grep -E '^[123]-.*JDOR.*\.rxj$|_256\.png$|\.log$'); do
  [ -f "$WORK/samples/$f" ] || svn cat -r $REV "$SVN/branches/850/samples/$f" > "$WORK/samples/$f"
done
ln -sfn "$BIN" "$WORK/bin"; cp "$HERE/page.html" "$HERE/driver.rex" "$WORK/"
python3 "$HERE/serve.py" 8124 "$WORK" & SRV=$!; trap 'kill $SRV' EXIT; sleep 1
cd "$WORK"
for f in samples/1-1*.rxj samples/1-2[0-2]*.rxj samples/2-1[23]*.rxj samples/3-100*.rxj; do
  b=$(basename "$f" .rxj)
  case "$b" in *_log|*replay*) continue;; esac
  NOERR=1 timeout 180 python3 "$HERE/run.py" "$ENGINE" "$f" samples/*.png samples/*.log --arg "?" > "cmds/$b.raw" 2>&1 || true
  python3 - "cmds/$b.raw" "cmds/$b.txt" <<'PY'
import sys
words = set("""areaAdd areaUnion areaExclusiveOr areaXor areaIntersect areaSubtract areaTransform assignRC background
clearRect clip clipRemove color colour composite copyArea draw3DRect drawArc drawImage drawLine drawOval drawPolygon
drawPolyline drawRect drawRoundRect drawString fill3DRect fillArc fillOval fillPolygon fillRect fillRoundRect font
fontSize fontStyle GC getState goto location moveTo pos position gradientPaint image imageCopy imageSize imageType
loadImage newImage new paint popGC popImage preferredImageType pushGC pushImage render reset clear rotate saveImage
scale setPaintMode setXorMode shear sleep stringBounds stroke translate transform shape clipShape drawShape fillShape
pathIterator shapeBounds pathAppend pathClone pathClose pathCurrentPoint pathCurveTo pathLineTo pathMoveTo pathQuadTo
pathReset pathTransform pathWindingRule""".lower().split())
lines = [l.rstrip("\n") for l in open(sys.argv[1]) if l.split(" ")[0].lower() in words]
open(sys.argv[2], "w").write("\n".join(lines) + "\n")
PY
done
python3 "$HERE/cmp.py" cmds/*.txt 2>&1 | grep -v -i deprecat
