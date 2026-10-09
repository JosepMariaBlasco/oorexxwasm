#!/usr/bin/env bash
# Assemble the ooRexx Playground site from the web build (oorexx/wasm/build-web.sh).
# Usage: build-site.sh [BIN_WEB=$ORX_WASM_WORK/build-wasm/bin-web] [OUT=$ORX_WASM_WORK/site]
#   OOREXX=$ORX_WASM_WORK/oorexx (for the ooRexx samples), OOREXX_REV (build note)
# Output: OUT/ ready to copy to the web server (Apache: .htaccess included).
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=$(cd "${1:-$ORX_WASM_WORK/build-wasm/bin-web}" && pwd)
OUT=${2:-$ORX_WASM_WORK/site}
OOREXX=${OOREXX:-$ORX_WASM_WORK/oorexx}
rm -rf "$OUT"; mkdir -p "$OUT/fonts"

cp "$BIN"/rexx.js "$BIN"/rexx.wasm "$BIN"/rexx.data "$BIN"/ooRexx.js "$BIN"/ooRexx-worker.js \
   "$BIN"/polygon-clipping.umd.min.js "$BIN"/js-realm.js "$OUT/"
mkdir -p "$OUT/samples/bsf4oorexx"
cp "$HERE"/samples/bsf4oorexx/NOTICE "$HERE"/samples/bsf4oorexx/LICENSE-Apache-2.0.txt "$OUT/samples/bsf4oorexx/"
cp "$HERE"/fonts/*.woff2 "$HERE"/fonts/OFL-IBM-Plex.txt "$OUT/fonts/"
cp "$HERE/htaccess" "$OUT/.htaccess"
# the Rexx Parser (vendored subset, import-rexx-parser.sh): CSS for the editor
mkdir -p "$OUT/rexx-parser"
# every style for the style chooser, as on the Parser's site ("test*" are dev fixtures)
for f in "$HERE"/rexx-parser/css/rexx-*.css; do
  case "$(basename "$f")" in rexx-test*) ;; *) cp "$f" "$OUT/rexx-parser/" ;; esac
done
cp "$HERE"/rexx-parser/LICENSE "$HERE"/rexx-parser/NOTICE "$OUT/rexx-parser/"

python3 - "$HERE" "$OUT" "$OOREXX" "${OOREXX_REV:-13254}" <<'PY'
import json, sys, datetime, os
here, out, oorexx, rev = sys.argv[1:5]
m = json.load(open(f"{here}/samples.json"))
def read(path):
    return open(path, encoding="utf-8", errors="surrogateescape").read()
import shutil
for s in m["samples"]:
    base = {"oorexx": f"{oorexx}/samples", "bsf4oorexx": f"{here}/samples/bsf4oorexx"}.get(s.get("from"), f"{here}/samples")
    text = read(f"{base}/{s['file']}")
    if text.startswith("#!@"):          # unconfigured SVN template (#!@OOREXX_SHEBANG_PROGRAM@)
        text = text.split("\n", 1)[1]
    s["source"] = text
    comp = {}
    for f in s.pop("files", []):
        if f.lower().endswith((".png", ".jpg", ".jpeg", ".gif")):   # binary: served as a file, fetched when needed
            rel = f"samples/{s.get('from') or 'own'}/{f}"
            os.makedirs(os.path.dirname(f"{out}/{rel}"), exist_ok=True)
            shutil.copy(f"{base}/{f}", f"{out}/{rel}")
            comp[f] = {"url": rel}
        else:
            comp[f] = read(f"{base if s.get('from') == 'bsf4oorexx' else oorexx + '/samples'}/{f}")
    s["companions"] = comp
m["build"] = (f"This build: ooRexx 5.3.0 (SVN r{rev} with the WebAssembly patches), "
              f"Emscripten 6.0.9, {datetime.date.today().isoformat()}.")

# rexx-parser.json: {path: text}, written into every run under /usr/lib/rexx-parser
# (REXX_PATH gets /usr/lib/rexx-parser/bin), plus the editor's highlighting server
rxp = f"{here}/rexx-parser"
bundle = {}
for d, _, fs in os.walk(rxp):
    for f in sorted(fs):
        rel = os.path.relpath(f"{d}/{f}", rxp)
        if rel in ("VERSION",): continue
        bundle["/usr/lib/rexx-parser/" + rel] = read(f"{d}/{f}")
bundle["/usr/lib/rexx-parser/playground/hlserver.rex"] = read(f"{here}/rexx-parser-support/hlserver.rex")
json.dump(bundle, open(f"{out}/rexx-parser.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
ver = open(f"{rxp}/VERSION").readline().strip().replace("current release is ", "")
m["build"] += f" Rexx Parser {ver}."
m["parser"] = ver
m["styles"] = sorted(f[5:-4] for f in os.listdir(f"{rxp}/css")
                     if f.startswith("rexx-") and f.endswith(".css") and not f[5:].startswith("test"))
blob = json.dumps(m, ensure_ascii=False).replace("</", "<\\/")
page = open(f"{here}/index.html", encoding="utf-8").read()
assert "/*SAMPLES*/" in page
open(f"{out}/index.html", "w", encoding="utf-8").write(page.replace("/*SAMPLES*/", blob))

# fonts.css: latin and latin-ext subsets (ranges from @fontsource)
LATIN = ("U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,"
         "U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD")
LATIN_EXT = ("U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,"
             "U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF")
css = ["/* IBM Plex, SIL Open Font License 1.1 (OFL-IBM-Plex.txt) */"]
# Mono bold and italics are real faces: the highlighted editor overlays a textarea,
# so every character must keep its width (synthetic bold widens it in some browsers)
for fam, slug, faces in (("IBM Plex Mono", "ibm-plex-mono",
                          ((400, "normal"), (500, "normal"), (700, "normal"), (400, "italic"), (700, "italic"))),
                         ("IBM Plex Sans Condensed", "ibm-plex-sans-condensed",
                          ((400, "normal"), (500, "normal"), (600, "normal")))):
    for w, st in faces:
        for sub, rng in (("latin-ext", LATIN_EXT), ("latin", LATIN)):
            css.append(f"@font-face{{font-family:'{fam}';font-style:{st};font-display:swap;font-weight:{w};"
                       f"src:url({slug}-{sub}-{w}-{st}.woff2) format('woff2');unicode-range:{rng}}}")
open(f"{out}/fonts/fonts.css", "w").write("\n".join(css) + "\n")
PY
ls -la "$OUT" | awk 'NR>1{print $5, $9}'
du -sh "$OUT"
