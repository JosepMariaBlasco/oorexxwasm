#!/bin/bash
# Import the JDOR samples of BSF4ooRexx850 (Rony G. Flatscher, Apache License
# 2.0) the playground offers, with the bitmaps they load, from the BSF4ooRexx SVN
# at a fixed revision: converted from Latin-1 to UTF-8 and adapted to the JDOR
# environment of the browser build (no BSF): adapt-bsf4oorexx-samples.py.
# Usage: import-bsf4oorexx-samples.sh [REV=1125]
set -euo pipefail
REV=${1:-1125}
HERE=$(cd "$(dirname "$0")" && pwd)
DST=$HERE/samples/bsf4oorexx
SVN=https://svn.code.sf.net/p/bsf4oorexx/code
mkdir -p "$DST"
FILES="1-120_JDOR_color_text.rxj 1-130_JDOR_rotate.rxj 1-140_JDOR_images.rxj 1-150_JDOR_string_circle.rxj
1-160_JDOR_getState.rxj 1-170_JDOR_lineHeight.rxj 1-180_JDOR_sandGlass.rxj 1-180_JDOR_sandGlass_log.rxj
1-180_JDOR_sandGlass_replay_log.rxj 1-190_JDOR_shapes.rxj 1-210_JDOR_area_cag.rxj 1-220_JDOR_area_cag.rxj
2-120_JDOR_shear.rxj 2-130_JDOR_animate_two_frames.rxj 3-100_create_bitmap_JDOR_commands.rxj
3-110_JDOR_animate_composite.rxj bsf4oorexx_256.png oorexx4ooo_256.png oorexx_256.png"
for f in $FILES; do
  svn cat -r "$REV" "$SVN/branches/850/samples/$f" > "$DST/$f"
  case "$f" in *.rxj)
    if ! iconv -f utf-8 -t utf-8 "$DST/$f" >/dev/null 2>&1; then
      iconv -f latin1 -t utf-8 "$DST/$f" > "$DST/$f.tmp" && mv "$DST/$f.tmp" "$DST/$f"
    fi;;
  esac
done
python3 "$HERE/adapt-bsf4oorexx-samples.py" "$DST"/*.rxj
svn cat -r "$REV" "$SVN/trunk/Apache_LICENSE_2.0.txt" > "$DST/LICENSE-Apache-2.0.txt"
cat > "$DST/NOTICE" <<NOTE
These JDOR samples and bitmaps come from BSF4ooRexx850 by Rony G. Flatscher
(https://sourceforge.net/projects/bsf4oorexx/, SVN branches/850/samples, r$REV),
under the Apache License 2.0 (LICENSE-Apache-2.0.txt).  The programs are
converted from Latin-1 to UTF-8 and adapted to the JDOR environment of the
ooRexx/WASM browser build (adapt-bsf4oorexx-samples.py): instead of creating
a Java handler through BSF4ooRexx (.bsf~new, BsfCommandHandler, ::requires
"BSF.CLS"), they say ::requires "jdor.cls", which defines ADDRESS JDOR, and
bsf.createJavaArrayOf becomes .array~of; where a program opens the
bitmap it saved with an operating system command (ADDRESS SYSTEM), a second
JDOR environment shows it in a window instead.  Each adapted program says so in
its second line (after the #! line).  The drawing commands are Rony's, unchanged.  In the
playground they run on the browser build's JDOR command handler (no Java
involved).
NOTE
ls -l "$DST"
