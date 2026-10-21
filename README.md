# ooRexx for WebAssembly

[![qualify](https://github.com/JosepMariaBlasco/oorexxwasm/actions/workflows/qualify.yml/badge.svg)](https://github.com/JosepMariaBlasco/oorexxwasm/actions/workflows/qualify.yml)

[Open Object Rexx](https://www.oorexx.org/) (ooRexx) compiled to WebAssembly
with Emscripten, so that the real interpreter runs in the browser and under
Node.js: threads, the RexxAPI, external commands, sockets, and access from
Rexx to JavaScript and to the page.

**Try it:** the [ooRexx Playground](https://rexx.epbcn.com/oorexx-wasm/) runs
ooRexx in your browser (needs a browser with cross-origin isolation:
current Chrome, Edge, Firefox or Safari), and
[*ooRexx in a web page*](https://rexx.epbcn.com/oorexx-wasm/example/) is a
page scripted in Rexx with `<script type="text/rexx">` (its source:
[`web/`](web/)).
[*Grokking in Rexx*](https://rexx.epbcn.com/oorexx-wasm/grok/) is a neural
network written in ooRexx that learns modular addition in the browser and
draws itself learning (its source: [`playground/grok/`](playground/grok/)).

**Install it:** `npm install -g oorexxwasm` for Node.js (Linux, macOS,
Windows), or the zips of the
[releases](https://github.com/JosepMariaBlasco/oorexxwasm/releases) for web
pages and for the Playground: see [`INSTALL.md`](INSTALL.md).

This repository is not a fork of ooRexx. It holds a **series of patches** on
top of ooRexx SVN trunk, plus the scripts, tests and pages built around them.
Patches 0001–0008 are proposed for inclusion in ooRexx in
[RFE #879](https://sourceforge.net/p/oorexx/feature-requests/879/); the
updates to that request are now published in [`rfe/`](rfe/).

## The patch series

Applied in order on top of ooRexx SVN trunk **r13282**
(`https://svn.code.sf.net/p/oorexx/code-0/main/trunk`):

| Patch | What it adds |
|---|---|
| 0001 | The WASM build (`wasm/build-wasm.sh`, CMake cache for Emscripten) and the base runtime: threads as pthreads, stack checks, the RexxAPI in-process, MEMFS |
| 0002 | Node command line: external commands as host processes, `rexxc`, errno, stdin `LINES()`, `rexxtry` |
| 0003 | Node: the RexxAPI (queues, registrations, macrospace) shared between processes through a daemon, like native `rxapi` |
| 0004 | Node: real TCP/UDP sockets and DNS |
| 0005 | The browser runtime: `wasm/web/ooRexx.js`, one Web Worker per run, interactive stdin, output streams marked as plain / trace / error |
| 0006 | Build variants with the test suite's native libraries linked in (`wasm/build-test.sh`), so the API test groups run under Node and in the browsers |
| 0007 | `.JSObject`: JavaScript objects from Rexx (the worker's and the page's), events, Rexx objects in JavaScript, Rexx from the page |
| 0008 | Node on Windows: Windows file names (written `C:/dir/file`), `;` in `PATH` lists, commands through `cmd.exe` (`ADDRESS CMD`), the RexxAPI daemon on a named pipe, `.cmd` launchers |
| 0009 | `ADDRESS JDOR`: Rony G. Flatscher's JDOR drawing commands on the browser's canvas (an example environment) |
| 0010 | Command environments written in Rexx (`cmdhandler`), a portable extension package that 0011, 0012 and 0013 use |
| 0011 | `ADDRESS FETCH`: HTTP from Rexx commands (an example environment) |
| 0012 | `ADDRESS DOM`: building and driving the page from Rexx commands (an example environment) |
| 0013 | Command environments written in JavaScript: `.js~addCommandEnvironment(name, fn)`, on `cmdhandler` |

0001–0008 are the RFE: the port, and `.JSObject`, which
[`docs/ooRexx-WASM-and-JavaScript.md`](docs/ooRexx-WASM-and-JavaScript.md)
specifies. 0009, 0011 and 0012 are example command environments built on
them. 0010 is a separate, portable package, not WebAssembly-specific, on
which 0011, 0012 and 0013 depend; 0013 makes JavaScript functions command
environments, as `.JSObject`'s specification describes. The
patches are in git format and apply with `svn patch` or `git am`;
`patches/SHA256SUMS` lists their hashes.

## Getting started

Linux (or WSL), with `bash`, `svn`, `python3`, `curl` and Node.js 22 or later:

```bash
git clone https://github.com/JosepMariaBlasco/oorexxwasm
oorexxwasm/scripts/setup-env.sh
```

`setup-env.sh` checks out ooRexx at the base revision, applies the patches
and installs a build. Everything goes into the directory that contains your
clone (`$ORX_WASM_WORK`, overridable), next to it:

```
oorexx/        ooRexx trunk r13282 + patches
build-wasm/    bin/ (Node and browser, MEMFS), bin-node/ (Node CLI), bin-web/ (pages)
saved-build/   the prebuilt binaries it downloaded
emsdk/         Emscripten, only when compiling
```

If the branch [`saved-build`](../../tree/saved-build) has binaries that match
the current patches, `setup-env.sh` downloads them and you are done in about
a minute. Otherwise, or with `--rebuild`, it installs Emscripten 6.0.12 and
compiles (a few minutes).

Then:

```bash
W=$ORX_WASM_WORK                          # the directory that contains the clone
$W/build-wasm/bin-node/rexx -e 'say "Hello from" .RexxInfo~platform'
$W/build-wasm/bin-node/rexx program.rex   # host files, host commands, real sockets
```

The in-tree documentation is in the patched tree: `oorexx/wasm/README.md`.

## Tests

```bash
tests/qualify.sh            # one command: Node, the Node CLI, Chromium, the web build and the playground
```

`qualify.sh` asserts every check and exits non-zero on any failure. GitHub
Actions runs it on every push and pull request
([`.github/workflows/qualify.yml`](.github/workflows/qualify.yml)); when the
patches change, the workflow compiles them and, on `main`, publishes the new
binaries to the branch `saved-build`. Every week it also compiles from
scratch. It needs
`pip install websockets playwright` (Chromium for the browser part). The
in-tree tests it runs are `wasm/tests/qualify-node.sh`,
`wasm/tests/qualify-node-cli.sh` and `wasm/tests/web-api.py`.

The **official ooRexx test suite** (test/trunk at the same revision as the
interpreter) runs with `tests/run-suite.sh` under Node and with
`tests/suite-browser/run.py` in Chromium, Firefox and WebKit, on the variants
with the test suite's native libraries (`build-wasm/bin-node-test`,
`bin-web-test`, from `wasm/build-test.sh`: the API test groups need them).
Results on
r13278, 402 test groups (GitHub Actions runners, Ubuntu 24.04):

| | groups passing |
|---|---:|
| native (same series) | 400 |
| Node | 398 |
| Chromium | 371 |
| Firefox | 371 |
| WebKit | 371 |

Every difference with native has a known cause (mostly: no processes in the
browser):
[`results/suite-platforms-r13278-series.md`](results/suite-platforms-r13278-series.md).
The results on r13275, r13268 and r13263, the previous bases, are kept next to them.

The suite also runs in GitHub Actions on demand
([`.github/workflows/suite.yml`](.github/workflows/suite.yml): Actions >
suite > Run workflow), one job per platform (native, Node, Chromium; Firefox
and WebKit when asked for). Each job compares its run with the reference CSV
in `results/` (`tests/suite-check.py`) and fails if a group got worse; the
run's summary puts all platforms side by side.

## Repository layout

- `patches/`: the series.
- `scripts/`:
  - `setup-env.sh`;
  - the saved build (prebuilt binaries on the branch `saved-build`):
    `save-build.sh`, `publish-build.sh`, `build-manifest.sh`;
  - working on the series as git commits: `series-repo.sh`, `series-export.sh`, `export-patch.sh`;
  - the distributions: `npm-package.sh` (npm), `web-package.sh` (the web
    and Playground zips), built and published by
    [`.github/workflows/release.yml`](.github/workflows/release.yml);
  - `relink.sh`, `check-method-signatures.py`.
- `tests/`: `qualify.sh`, probes (Node, browser, recursion, threads), the
  bridge's conversion probe (`conversion-probe/`, run by `qualify.sh`), the
  official suite runners, and the JDOR comparison with the Java handler.
- `playground/`: the ooRexx Playground page and its samples. See
  [`playground/README.md`](playground/README.md).
- `debugger/`: Dom Wise's ooRexx debugger with a front end for web pages: the
  playground's Debug, and `ooRexx-debugger.js`, which debugs the Rexx scripts
  of any page opened with `?rexx-debug=1`. See
  [`debugger/README.md`](debugger/README.md).
- `web/`: the browser distribution's own files (example page with
  `<script type="text/rexx">`, `serve.mjs`, `.htaccess`, README), packed with
  the web build by `scripts/web-package.sh`.
- `npm/`: the npm package's launchers, README and tests (`scripts/npm-package.sh`).
- `examples/`: a command environment written in Rexx (`ADDRESS SQLITE`).
- `docs/`: [*ooRexx/WASM and JavaScript*](docs/ooRexx-WASM-and-JavaScript.md), the specification of `.JSObject`, kept up to date with the implementation; `docs/posted/` holds each version as it was posted to the ooRexx developers' list.
- `notes/`: design notes (threads and recursion, Node commands, rxapi and
  sockets, `.JSObject`, FETCH and DOM, the suite in the browser, provenance).
- `results/`: the official test suite's results, as CSV.

## Upstream

Problems found along the way were reported upstream:
- ooRexx bugs #2093–#2096, all fixed in trunk (r13251–r13254), and #2104;
- Emscripten issues and pull requests #27885–#27890 (two of them merged
  fixes that will let the port drop its workarounds);
- Deno issue #36983.

## Credits and license

The port started from Tom Dyer's "dev1" patch, contributed under the CPL 1.0
(see [`notes/provenance.md`](notes/provenance.md)). JDOR is
Rony G. Flatscher's (BSF4ooRexx). The playground uses the
[Rexx Parser](https://github.com/JosepMariaBlasco/rexx-parser) and includes
JDOR samples from BSF4ooRexx (Apache 2.0, see their `NOTICE`). The debugger
is Dom Wise's [ooRexx debugger](https://sourceforge.net/p/oorexxdebugger/).

**License.** Two licenses, by directory:

- `patches/` is under the **Common Public License 1.0**
  ([`patches/LICENSE`](patches/LICENSE)), the license of ooRexx itself: the
  patches are meant for ooRexx, and they derive from Tom Dyer's dev1,
  contributed under the CPL 1.0.
- Everything else (scripts, tests, the playground, notes, docs) is under the
  **Apache License 2.0** ([`LICENSE`](LICENSE)). Third-party parts keep their
  own licenses: the JDOR samples from BSF4ooRexx (Apache 2.0, `NOTICE`), the
  Rexx Parser (Apache 2.0), the IBM Plex fonts (SIL Open Font License), and
  `debugger/`, Dom Wise's ooRexx debugger and its web front end (MIT,
  `debugger/LICENSE`).
