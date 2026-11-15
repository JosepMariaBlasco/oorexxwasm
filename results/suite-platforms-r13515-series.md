# The official test suite on r13514 (test/trunk r13515, the series on trunk r13514)

Run locally, 15 November 2026, Ubuntu 24.04 (x86_64), `TZ=Europe/Madrid`,
as an ordinary user (native and Node) with `tests/run-suite.sh` (2 jobs) and
`tests/suite-browser/run.py chromium` (2 jobs, `--retry-timeouts`), on the
test variants (`build-wasm/bin-node-test`, `bin-web-test`). Firefox, WebKit
and Windows were not run this time (they run in GitHub Actions,
`.github/workflows/suite.yml`, on demand).

Base r13514: the CATCH clauses (RFE #31; `CATCH.testGroup`, 144 tests) and
about forty fixes since r13398.

| | groups | passing | tests | failures | errors |
|---|---:|---:|---:|---:|---:|
| native (same series) | 409 | 406 | 24,778 | 3 | 0 |
| Node | 409 | 403 | 24,769 | 14 | 0 |
| Chromium | 409 | 360 | 24,761 | 177 | 139 |

Files: `suite-native-r13515-series.csv`, `suite-wasm-r13515-series.csv`,
`suite-web-chromium-r13515-series.csv`. Every difference with native has a
known cause, in `tests/suite-browser/known.tsv`.

## Native

- `CHAROUT`, `LINEOUT`: the output of the run is redirected (not a terminal),
  as in every run (one test each).
- `API/oo/ProcessInvocation` (`TESTLOADLIBRARY`): the process tester does not
  find `rxmath` in this local build directory (the library is there, next to
  `rexx`); it passes in GitHub Actions.

## Node

`CHAROUT`, `LINEOUT` (as native), `File` (time stamps: fractions and the 1969
date, as before), `TRACE` (flaky,
`TEST_TRACE_LABEL_WITH_FORWARD`, as before), and two new ones:

- `Stream`, `TEST_STREAM_SUPPLIER_TRANSIENT_UNOPENED` (#2169): the child
  `rexx` reads its standard input from a socket (Node's `child_process` uses
  `socketpair()` for a pipe), and ooRexx takes a socket for a persistent
  stream: `stream("STDIN", "c", "query streamtype")` is `PERSISTENT`, natively
  too when the standard input is a socket. Natively the test passes because
  `ADDRESS ... WITH INPUT` gives the child a FIFO.
- `SysGetMessage`, the seven damaged-catalog tests: they detect the GNU C
  library with the host's `getconf GNU_LIBC_VERSION`, but rexx.wasm is linked
  with Emscripten's musl, and ooRexx checks a catalog only when built with
  `__GLIBC__` ("Message catalog not found" instead of "Invalid message
  catalog").

Changes of the port this base needed (both in the series):

- **#1247**: very long chains of operators or messages are now evaluated with
  a stack check every 32 levels. Under WebAssembly the frames live on the JS
  engine's native stack, which ran out first (`RangeError`); the native stack
  probe now runs there too (patch 0002), and the three `TEST_1247_*` tests
  get Error 11.1.
- **#1940**: a name ending in `/` keeps its slash. MEMFS ignored it, so
  `SysIsFile("file/")` was 1 in the browser; the web runtime now answers
  ENOTDIR for such a name that is not a directory, and EISDIR when one is
  created (patch 0006).

## Chromium

Compared with r13388, the groups that are worse are all new tests that run
`rexx` (or `rexxc`) as a child process, RC 127 in a browser: `Class`,
`Message`, `Object`, `Package`, `String/comparisonOperators`, `SPECIAL`,
`FORWARD`, `RAISE`, `SysDumpVariables`, `SysFormatMessage`, `SysStemCopy`,
`SecurityManager`, `Stream`, `environmentEntries`, `rexxc`,
`ProcessInvocation`; new groups `CATCH` (15 errors, 3 failures), `SETLOCAL`,
`SysMutexSem`. `CALL` and `TRACE` are `stack` and `flaky`, as before.
