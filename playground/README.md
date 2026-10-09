# ooRexx Playground

A public web page where anyone can write ooRexx and run it in the browser,
on the real interpreter compiled to WebAssembly (patch 0005 adds the browser
build: `oorexx/wasm/build-web.sh`, `wasm/web/ooRexx.js`). Live at
https://rexx.epbcn.com/oorexx-wasm/ (Apache). It borrows the look of the RVM
Workbench, a separate page.

## Files

- `index.html` — the page (template: build-site.sh puts the samples in place of
  `/*SAMPLES*/`).
- `samples.json` — sample list: group, title, file; `"from": "oorexx"` takes the
  file from the ooRexx `samples/` directory, `files` adds companion files
  (e.g. `complex.cls`), `stdin` fills the standard input box.
- `samples/` — our own samples; `samples/bsf4oorexx/` — the JDOR samples of
  BSF4ooRexx850 (Rony G. Flatscher, Apache 2.0, NOTICE) and the bitmaps they
  load, imported by `import-bsf4oorexx-samples.sh` (SVN r1125; Latin-1 ->
  UTF-8) and adapted by `adapt-bsf4oorexx-samples.py` to `::requires
  "jdor.cls"` instead of BSF (each file's first line says so); `"from": "bsf4oorexx"` in samples.json. Binary companion files
  (`"files"` ending in .png/.jpg/.gif) are copied to the site's `samples/` and
  fetched when the sample runs.
- `fonts/` — IBM Plex Mono / Sans Condensed woff2 (OFL), served locally:
  with COEP `require-corp` third-party fonts may be blocked.
  Mono has real bold (700) and italic (400, 700) faces for the highlighted
  editor (a synthetic bold would change character widths in some browsers).
- `rexx-parser/` — the part of the Rexx Parser (J. M. Blasco, Apache 2.0) the
  playground uses, vendored by `import-rexx-parser.sh RELEASE.zip` (see the
  script for how the set was chosen). `VERSION` says which release.
- `rexx-parser-support/hlserver.rex` — the editor's highlighting server.
- `htaccess` — Apache config, installed as `.htaccess`.
- `build-site.sh [BIN_WEB] [OUT]` — assembles the site (default
  `$ORX_WASM_WORK/site`; `$ORX_WASM_WORK` is the directory that contains this
  repository's clone, see the top README).

## Build and test

```bash
W=$ORX_WASM_WORK
$W/oorexx/wasm/build-web.sh $W/build-wasm                # -> build-wasm/bin-web (setup-env.sh does it)
playground/build-site.sh                                 # -> $W/site
python3 $W/oorexx/wasm/tests/web-api.py $W/build-wasm/bin-web   # API assertions (in-tree)
tests/playground_check.py $W/site                        # page driven like a user
BASE=http://host/path/ tests/playground_check.py         # against a real server
```

Both tests are in `qualify.sh` (section "Web build + playground").

## Deploy (Apache 2.4)

Copy the site directory as is (including `.htaccess`) to the target directory.
Needs `mod_headers` (mandatory: COOP/COEP make the page cross-origin isolated,
without which browsers deny SharedArrayBuffer and the interpreter's threads)
and `mod_deflate` (optional: ~3 MB → ~0.65 MB transferred). The directory must
allow `.htaccess` overrides of type `FileInfo` (`Header`, `AddType`,
`AddOutputFilterByType`), or put the same directives in the vhost. The
`.htaccess` has no `Options`/`DirectoryIndex`: on rexx.epbcn.com they gave
500 (no `AllowOverride Options`/`Indexes`). Check:

```bash
curl -sI https://rexx.epbcn.com/<path>/rexx.wasm | grep -i -E 'cross-origin|content-type'
# Cross-Origin-Opener-Policy: same-origin / Cross-Origin-Embedder-Policy: require-corp / application/wasm
```

Verified with Apache 2.4.58 + the `.htaccess` (all page checks pass), driven
in headless Chromium.

## Design notes

- One Web Worker per run hosts the Emscripten runtime; the interpreter's
  pthreads are nested workers. Stop = `worker.terminate()`. The compiled
  module and `rexx.data` are fetched once and passed to each run (~100 ms
  per run start).
- Interactive stdin: the console input line continues the output like a
  terminal; Enter sends a line, Ctrl+D sends end of file. If the standard
  input box has text, that text is the whole input instead.
- "Your files" (bar under the editor) is the workspace: files under
  `/home/rexx` (the cwd of every run), carried from run to run and kept in
  the browser (IndexedDB `oorexx-playground`, store `files`; saved by diff after
  every change, edits after 0.8 s; the open file is remembered in localStorage
  and reopened). If storage is unavailable or full, a note says so and files
  live in page memory only. "Clear files" asks first. Several tabs: last writer
  wins. They come from Upload / drag-and-drop (32 MB max per
  file), New, or a run that writes there. A text file (UTF-8, no NUL, ≤ 2 MB)
  opens in the editor on click and Run runs it; edits are saved into the file.
  Any program can `::requires` them. Paths may have directories: New takes `dir/name`, Folder uploads a folder tree
  (`webkitdirectory`; hidden where unsupported), a dropped folder keeps its
  tree (`webkitGetAsEntry`), a single uploaded .zip can be unpacked (own
  reader: stored/deflate via `DecompressionStream`), and Download all gives a
  .zip (own writer, stored). `..` is refused.
- Linked folders (File System Access API, Chrome/Edge only, the
  button is hidden elsewhere): Link folder → "read & write" or "read only" →
  picker; the folder is mounted as `/home/rexx/NAME/` (NAME = its name, `-2`…
  if taken) next to the browser files, several at once. Read before every run
  and on focus/visibility (outside edits reach the open file); read & write:
  edits, uploads, New and program output are written to it, deletions (× or
  by a program) always ask; read only: the editor is read-only there and a
  program's changes are dropped with a console note. Dot-names skipped; 2000
  files / 64 MB max. Handles kept in IndexedDB (store `meta`, DB version 2);
  after a reload "Reconnect NAME" asks permission again when needed. Every
  linked folder's root is put first in the run's `REXX_PATH`: `::requires "lib/x.cls"` finds `/home/rexx/NAME/lib/x.cls`. Clear
  files clears browser files only. Tested with OPFS directories
  (`window.OoRexxPlayground.linkFolder(handle, rw)`), not with the real picker. Each file can be downloaded (↓) or
  deleted (×). Sample files themselves are not carried, and a file of yours
  with a sample's name is restored after running that sample.
- ANSI escape sequences on stdout/stderr: SGR is rendered
  (bold, dim, italic, underline, inverse, strike, hidden; 16 colors as CSS
  variables `--a0`…`--a15` tuned per theme; 256 colors; 24-bit). `ESC[2J`
  clears the console; every other sequence is dropped. One style state for
  both streams, as in a terminal; a sequence split across output chunks is
  held back until complete. Sample: `samples/colors.rex`.
- Rexx Parser: `build-site.sh` writes `rexx-parser.json` ({path:
  text}, ~3.9 MB, ~0.55 MB deflated) which the page fetches once and writes into
  every run under `/usr/lib/rexx-parser/` with `REXX_PATH=/usr/lib/ooRexx:
  /usr/lib/rexx-parser/bin`. So programs can `::requires "Rexx.Parser.cls"`,
  `"parser/Highlighter.cls"`, or `call highlight "-a file"` / `call elements`.
  Sample: `samples/parser.rex`.
- Highlighted editor: a run that stays up for the page's life runs
  `hlserver.rex` (parser loaded once) and answers each "id count" + lines
  request on stdin with the Highlighter's HTML (or `ERR line code text`). The
  HTML goes in `#hl` under a transparent `#src` (same font, padding, scroll).
  The overlay always shows the textarea's exact text: lines unchanged since
  the last answer keep their colors, edited ones are plain until the next
  answer (250 ms after typing stops). Syntax errors show under the editor and
  the line gets a wavy underline. `rexx-light.css`/`rexx-dark.css` follow the
  theme. The "highlight" checkbox turns it off (remembered).
- Style chooser (after the Parser's `js/style-chooser.js`): every
  `rexx-*.css` but `test*`, fetched when first chosen; "auto" follows the page
  theme on the page's background, a chosen style brings its own background
  (`.rexx` on `#hl`) and caret color. `?style=NAME` wins over the stored
  preference, which uses the Parser site's key `rexx-parser.codeStyle` (same
  origin, so a choice made on either site carries over). The server
  restarts up to 3 times if it dies.
- Console streams: stdout, stderr (red by
  default), trace, input and debug input have their own colors (CSS
  `--c-out|err|trace|in|dbg`). The runtime (patch 0005, `orx_wasm_mark`)
  marks every output chunk as plain/trace/error message and every input
  request as .debugInput's or not (`onOut/onErr(text, kind)`,
  `onInput({debug})`), whatever stream they end up on. Without marks (an
  older runtime) the page falls back to splitting stderr by trace format
  (`TRACE_RE`) and calling typed input debug when the last line was trace. The status bar counts
  stderr and trace lines apart. Settings (⚙ in the console bar): a color per
  stream and per theme, localStorage `orx-pg-colors`.
- JavaScript: runs are granted both `.JSObject` realms
  (`js: {worker: true, page: true}` in `index.html`: users run their own
  code), so programs can use the worker's JavaScript (`.js`) and this page's
  DOM (`.js~page`); group "JavaScript & the page": `javascript.rex`,
  `page-dom.rex` (a note element, `prompt`/`confirm`, a fade),
  `page-clock.rex` (an SVG clock driven by Rexx for 20 s) and
  `page-events.rex` (a to-do panel whose form, list and button are
  handled in Rexx: `.js~handler` + `.js~eventLoop`). A program that is
  stopped leaves what it added to the page until a reload (its event
  handlers do nothing any more).
- JDOR: `ADDRESS JDOR` (wasm/web-jdor.*, patch 0006) draws on
  OffscreenCanvases in the run's worker; `onJdor` messages create windows
  here: fixed-position panels over the page (`.jdorwin`), dragged by the
  title bar (frameless ones anywhere; their x shows on hover), closed with x,
  cleared when the next run starts, `alwaysOnTop` = higher z-index. Moves and
  closes go back to the run (`run.jdorEvent`). `winScreenSize` = the
  viewport. `clipboardSet` tries `navigator.clipboard.write`, `printImage`
  prints from a hidden iframe. Samples group "Drawing (JDOR)": ours
  (`jdor.rex`) and 16 of Rony's; 2-110 (Swing dialog, Java font list) is not
  offered. playground_check.py has 12 JDOR checks.
- Help: F1 or "? Help" opens a dialog explaining the whole page (keep it in
  step when features change). Esc closes dialogs before it stops runs.
- Console history: ↑/↓ in the input line recall earlier lines (kept across
  runs, 500 lines, page memory).
