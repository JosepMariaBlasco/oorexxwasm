# ooRexx for WebAssembly

[![qualify](https://github.com/JosepMariaBlasco/oorexxwasm/actions/workflows/qualify.yml/badge.svg)](https://github.com/JosepMariaBlasco/oorexxwasm/actions/workflows/qualify.yml)

[Open Object Rexx](https://www.oorexx.org/) (ooRexx) compiled to WebAssembly
with Emscripten, so that the real interpreter runs in the browser and under
Node.js: threads, the RexxAPI, external commands, sockets, and access from
Rexx to JavaScript and to the page.

**Try it:** the [ooRexx Playground](https://rexx.epbcn.com/oorexx-wasm/) runs
ooRexx in your browser (needs a browser with cross-origin isolation:
current Chrome, Edge, Firefox or Safari).

This repository is not a fork of ooRexx. It holds a **series of patches** on
top of ooRexx SVN trunk, plus the scripts, tests and pages built around them.
Patches 0001–0005 are proposed for inclusion in ooRexx in
[RFE #879](https://sourceforge.net/p/oorexx/feature-requests/879/).

## The patch series

Applied in order on top of ooRexx SVN trunk **r13263**
(`https://svn.code.sf.net/p/oorexx/code-0/main/trunk`):

| Patch | What it adds |
|---|---|
| 0001 | The WASM build (`wasm/build-wasm.sh`, CMake cache for Emscripten) and the base runtime: threads as pthreads, stack checks, the RexxAPI in-process, MEMFS |
| 0002 | Node command line: external commands as host processes, `rexxc`, errno, stdin `LINES()`, `rexxtry` |
| 0003 | Node: the RexxAPI (queues, registrations, macrospace) shared between processes through a daemon, like native `rxapi` |
| 0004 | Node: real TCP/UDP sockets and DNS |
| 0005 | The browser runtime: `wasm/web/ooRexx.js`, one Web Worker per run, interactive stdin, output streams marked as plain / trace / error |
| 0006 | `ADDRESS JDOR`: Rony G. Flatscher's JDOR drawing commands on the browser's canvas |
| 0007 | `.JSObject`: JavaScript objects from Rexx (the worker's and the page's), events |
| 0008 | Command environments written in Rexx (`cmdhandler`), a portable extension package |
| 0009 | `ADDRESS FETCH`: HTTP from Rexx commands |
| 0010 | `ADDRESS DOM`: building and driving the page from Rexx commands |

0001–0005 are the RFE. 0006–0010 build on them and are not part of it. The
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
oorexx/        ooRexx trunk r13263 + patches
build-wasm/    bin/ (Node and browser, MEMFS), bin-node/ (Node CLI), bin-web/ (pages)
saved-build/   the prebuilt binaries it downloaded
emsdk/         Emscripten, only when compiling
```

If the branch [`saved-build`](../../tree/saved-build) has binaries that match
the current patches, `setup-env.sh` downloads them and you are done in about
a minute. Otherwise, or with `--rebuild`, it installs Emscripten 6.0.9 and
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
`tests/suite-browser/run.py` in Chromium, Firefox and WebKit. Results on
r13263, 402 test groups:

| | groups passing |
|---|---:|
| native (same series) | 397 |
| Node | 388 |
| Chromium | 365 |
| Firefox | 366 |
| WebKit | 367 |

Every difference with native has a known cause (mostly: no processes in the
browser, and the native test libraries the API groups need):
[`results/suite-platforms-r13263-series.md`](results/suite-platforms-r13263-series.md).

## Repository layout

- `patches/`: the series.
- `scripts/`:
  - `setup-env.sh`;
  - the saved build (prebuilt binaries on the branch `saved-build`):
    `save-build.sh`, `publish-build.sh`, `build-manifest.sh`;
  - working on the series as git commits: `series-repo.sh`, `series-export.sh`, `export-patch.sh`;
  - `relink.sh`, `check-method-signatures.py`.
- `tests/`: `qualify.sh`, probes (Node, browser, recursion, threads), the
  official suite runners, and the JDOR comparison with the Java handler.
- `playground/`: the ooRexx Playground page and its samples. See
  [`playground/README.md`](playground/README.md).
- `examples/`: a command environment written in Rexx (`ADDRESS SQLITE`).
- `docs/`: *ooRexx WASM and JavaScript*, the specification of `.JSObject`.
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
JDOR samples from BSF4ooRexx (Apache 2.0, see their `NOTICE`).

**License.** Two licenses, by directory:

- `patches/` is under the **Common Public License 1.0**
  ([`patches/LICENSE`](patches/LICENSE)), the license of ooRexx itself: the
  patches are meant for ooRexx, and they derive from Tom Dyer's dev1,
  contributed under the CPL 1.0.
- Everything else (scripts, tests, the playground, notes, docs) is under the
  **Apache License 2.0** ([`LICENSE`](LICENSE)). Third-party parts keep their
  own licenses: the JDOR samples from BSF4ooRexx (Apache 2.0, `NOTICE`), the
  Rexx Parser (Apache 2.0), the IBM Plex fonts (SIL Open Font License).
