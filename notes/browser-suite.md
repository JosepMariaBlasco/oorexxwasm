# The official test suite in the browser

*Written 05/10/2026 against test/trunk r13248; patch numbers refer to the
current series.*

Goal (from the discussion on RFE #879): run the ooRexx test suite (test/trunk
r13248) inside the browser build, in Chromium, Firefox and WebKit, Playwright
on Linux, and say exactly what works on this platform.

## How

`tests/suite-browser/` in this repository:

- `run.py ENGINE BIN_WEB OUTDIR [--jobs 2] [--timeout 150] [--retry-timeouts]`:
  bundles the test tree (`suite.idx` + `suite.bin`), serves it with the web
  build (COOP/COEP), and runs one test group per run — a fresh interpreter in
  its own worker — with `testOORexx.rex -R dir -f group -U`, the tree written
  into the run's MEMFS under `/suite`. Same CSV as `tests/run-suite.sh`
  (`group,status,ran,assertions,failures,errors,seconds`), logs per group.
  A watchdog retries runs that do not start, `--retry-timeouts` also runs
  that time out; every retry goes to `hangs.csv`.
- `known.tsv`: every group that does not pass in a browser, with its cause
  (and the intermittent or environment-dependent failures seen on other
  platforms). Columns `category`, `group` (path under `ooRexx/`, without
  `.testGroup`) and `why` (what the log shows). Categories, several
  separated by commas:
  - `processes`: the test runs an external command (rexx, rexxc, rxqueue,
    rxsubcom, sh, echo, id...); a browser has no processes, so ADDRESS to a
    shell or command environment ends with RC 127.
  - `install`: `.RexxInfo~executable` is `.nil` in the browser: the
    executable (rexx.wasm) comes from a URL, not from the program's file
    system, so there is no File for it.
  - `test-bug`: the test group itself is wrong (json_02 and yaml when the
    executable is `.nil`, bug #2097, fixed in test/trunk r13249; DateTime
    expects `0:00am` to be valid, which trunk r13250 made invalid on
    purpose, on every platform).
  - `api-libs`: needs the native test libraries (orxclassic, orxmethod...),
    not built for WASM (as under Node).
  - `sockets`: RxSock in the browser goes over WebSockets: no listening
    sockets, no socket options.
  - `stack`: recursion depth bounded by the engine's native stack (Error 11
    is raised cleanly; the test wants at least 5000 levels). Depends on the
    engine build.
  - `memfs`: Emscripten's MEMFS reads file times back in whole
    milliseconds (like FAT, which the tests allow for elsewhere).
  - `flaky`: intermittent, passes when rerun.
  - `upstream`: ooRexx itself, not the port.

  `tests/suite-check.py` (the comparison with a reference run, used by the
  `suite` workflow) reports groups in `flaky` or `stack` but does not count
  them as regressions.
- `compare.py NAME=csv...`: platforms side by side; groups failing in a
  browser without a known cause are listed as UNEXPLAINED.
- `reasons.py LOGDIR GROUP...`: one line per failure/error of a log.

Engines: Chromium 141 (Playwright's), Firefox 142 and WebKit 26 (Playwright's
browser builds, via `PLAYWRIGHT_BROWSERS_PATH`). Firefox and WebKit run
headless on Linux; WebKit there is the engine of Safari, not Safari itself.

## What running in three engines found (all fixed, in the series)

1. **Firefox: deep recursion killed the worker** ("too much recursion")
   instead of Error 11. The native stack probe was JS (`apply` with 32768
   arguments); in Firefox it never fails while wasm frames already overflow.
   Now the probe recurses through wasm frames (`orxWasmStackProbe`) and is
   calibrated on each thread to a quarter of the stack. → 0001.
2. **WebKit: 5-10% of runs hung** (at start or mid-run). WebKit sometimes
   loses an `Atomics.waitAsync` wakeup; Emscripten uses it to tell the
   runtime's thread that a pthread proxied a system call to it (MEMFS lives
   there). Reproduced without ooRexx (a C program doing 2000 `stat()` from a
   pthread: 20/200 runs hang in WebKit, 0 in Chromium; 0/300 with waitAsync
   hidden). Fix: `web-pre.js` hides `Atomics.waitAsync`; Emscripten falls
   back to postMessage, no measurable cost. → 0005. Worth reporting to
   WebKit (and maybe Emscripten: a switch to avoid waitAsync).
3. **WebKit: a C++ exception thrown on a secondary thread escaped** with the
   legacy wasm exception encoding (a Rexx error in a START'ed method killed
   the run; Message/Object groups). Fix: the standardized encoding (exnref,
   `-sWASM_LEGACY_EXCEPTIONS=0`) everywhere — Chromium refuses a module that
   mixes encodings, so `build-web.sh` compiles `web-jdor.cpp` with it too.
   Needs Chrome 137, Firefox 131, Safari 18.4, Node 22. → 0001, 0006.
4. **The clock had millisecond resolution**: Emscripten's `gettimeofday()`
   and `CLOCK_REALTIME` are `Date.now()`, so TIME('L') microseconds were 000
   and SysSleep(1e-8) measured 0. Now `performance.timeOrigin +
   performance.now()` (TimeSupport.cpp) → 0001; and `Date.now()` with that
   resolution in the web runtime, so MEMFS stamps files with the same clock
   (File~lastModified test) → 0005. Emscripten still reads file times back
   in whole ms (`stat()` goes through a JS Date), in MEMFS and in NODERAWFS:
   the 2 File `*_FRACTIONS` tests (they allow for FAT elsewhere) now fail
   in the browsers and under Node; before, they passed only because the
   clock was as coarse as the file times. An Emscripten issue candidate.

Recursion depth after the probe change (internal CALL / function / method):
Node 7,131 / 5,451 / 4,010; Chromium 923 / 699 / 530; Firefox 1,315 / 907 /
714; WebKit 5,107 / 3,571 / 2,834.

## Results

Test/trunk r13248 with the series as it was then (including the
`.RexxInfo` decision below); native is the same series built natively.
These r13248 result files are not in the repository; the current results
(trunk r13263) are in `results/`, side by side with causes in
`results/suite-platforms-r13263-series.md`.

| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native | 402 | 396 | 6 | 0 | 0 | 24522 | 358095 | 10 | 0 |
| node | 402 | 389 | 13 | 0 | 0 | 23674 | 341096 | 7 | 8 |
| chromium | 402 | 363 | 37 | 2 | 0 | 23385 | 338645 | 85 | 81 |
| firefox | 402 | 364 | 36 | 2 | 0 | 23385 | 338654 | 84 | 81 |
| webkit | 402 | 364 | 36 | 2 | 0 | 23385 | 338648 | 84 | 81 |

Causes (`known.tsv`): processes 24, api-libs 8, test-bug 2 (json_02, yaml:
`init` with executable .nil; a two-line fix in the tests, reported as ooRexx
bug #2097), install 1 (RexxInfo's executable half), File (processes + MEMFS
ms times), CALL stack depth (Chromium, Firefox), rxsock socketClass, TRACE
(flaky). No run hung in any engine.

Decision: `.RexxInfo~executable` stays .nil in the browser — the executable
(rexx.wasm + rexx.js) exists but was loaded from a URL or the cache, not from
the program's file system, so there is no File for it (and it is not called
rexx); `libraryPath` = `/usr/lib/ooRexx/` (0005).

## Open

- WebKit: DateTime hung (no output after "Executing automated test suite")
  in 2 of 3 full runs and passed when retried; not reproduced alone, under
  load, or after the same 85 preceding groups.
- MutexSemaphore hangs at interpreter termination under load — an upstream
  bug also seen natively, and in Firefox and Node.
- json_02 / yaml test bug: reported as bug #2097
  (https://sourceforge.net/p/oorexx/bugs/2097/); neither group fails in the
  r13263 results.
- The runner lives in this repository, not in the ooRexx tree. For CI
  (Jenkins) it could move in-tree (`wasm/tests/`), with the bundle built
  from a test checkout.
