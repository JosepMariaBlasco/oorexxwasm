# The official test suite on r13535 (test/trunk r13536, the series on trunk r13535)

Run in GitHub Actions, 17 November 2026 (`suite.yml`, run 44082073886, commit
51e9c2f; Windows: run 44084202966, commit 6bc42c8), `TZ=Europe/Madrid`; the CSVs are that run's
artifacts. Native is ooRexx built from the same patched tree.

r13535 is trunk's newest main revision: FINALLY (RFE #31) with its three
later rules, BEEP, DIRECTORY and FILESPEC as built-in functions (RFE #890),
and the fixes since r13517: #2172 (SysGetMessage's damaged-catalog tests skip
under Emscripten), #2173 (a socket as standard input is a transient stream),
#2174 (RESULT of RAISE ... RETURN for every condition), r13527 and r13529.

| | groups | passing | tests | failures | errors |
|---|---:|---:|---:|---:|---:|
| native (same series) | 412 | 410 | 25,009 | 2 | 0 |
| Node | 412 | 408 | 25,000 | 7 | 0 |
| Chromium | 412 | 362 | 24,992 | 177 | 157 |
| Firefox | 412 | 362 | 24,992 | 176 | 157 |
| WebKit | 412 | 363 | 24,992 | 172 | 157 |
| Windows (Node on windows-latest) | 412 | 397 | 25,000 | 44 | 1 |

Compared with r13518 (`tests/suite-check.py`; Firefox, WebKit and Windows
with their last references, r13388, and with this run's Chromium):

- New groups: `FINALLY` (Node 203/203; in the browsers 14 errors, all tests
  that run `rexx` as a child process, RC 127), `DIRECTORY`,
  `BuiltinSearchOrder`.
- Node: `Stream` passes (#2173: `TEST_STREAM_SUPPLIER_TRANSIENT_UNOPENED`,
  #2169's test, no longer fails), and so does `SysGetMessage` (#2172).
  `TRACE`: `TEST_TRACE_LABEL_WITH_FORWARD` (and in this run
  `TEST_TRACE_PULL_PUSH_QUEUE`) depend on thread timing (`known.tsv`): the
  forwarded test waits 1 ms for the threads of REPLY to end; under Node it
  failed 3 runs of 3 locally, and passes with 0.2 s.
- Native: `ProcessInvocation` passes. `CHAROUT` and `LINEOUT` are the usual
  ones of a run with the output redirected.
- Chromium: `rexxc` has two errors more, its new tests (test/trunk r13533),
  which run `rexxc` as a child process; `File` one failure more (flaky).
- Firefox and WebKit: as Chromium in the same run, nothing worse. Against
  r13388 they show the same 16 groups as Chromium did from r13388 to r13518
  (test/trunk r13515 and later run many tests as child processes:
  [`suite-platforms-r13515-series.md`](suite-platforms-r13515-series.md)).
- Windows (with r13388's reference): the first run (44082073886, at
  51e9c2f) failed `Stream`'s `TEST_BUG_1940` and `SysFileXXX`'s
  `TEST_TRAILING_SEPARATOR` (#1940, test/trunk r13515): Windows ignores a
  trailing separator, so Node found or created "file" for "file/". Fixed in
  `wasm/node-pre.js` (patch 0009, 6bc42c8); both pass in this run.
  `SysFileTree`'s `TEST_TREE_DIRECTORY` compares two listings of the
  temporary directory, which a group running alongside writes to (flaky,
  `known.tsv`); it failed in two runs with other groups and passes alone
  (run 44086000432): the reference has that run's line. `File`: one
  timestamp failure more (flaky). The other failures are r13388's.
