# The official test suite on r13550 (test/trunk r13553, the series on trunk r13550)

Run locally, 20 November 2026, as for r13517
([`suite-platforms-r13518-series.md`](suite-platforms-r13518-series.md)):
Ubuntu 24.04 (x86_64), `TZ=Europe/Madrid`, native and Node as an ordinary
user, Chromium with `tests/suite-browser/run.py`. Firefox, WebKit and Windows
not run (GitHub Actions, on demand): their references stay r13535's.

r13550 is trunk's newest main revision: the THROW instruction (RFE #31,
r13541, experimental), the `Throw()` API (r13546), error 4.901 for an
uncaught thrown condition with a description (r13550), and #2178 (r13545:
a halt reaches every activity). The series only moves (offsets); the
JavaScript bridge uses both: a thrown condition crosses JavaScript as
itself, and `RexxError.throwing()` throws one from JavaScript.

| | groups | passing | tests | failures | errors |
|---|---:|---:|---:|---:|---:|
| native (same series) | 413 | 410 | 25,099 | 3 | 0 |
| Node | 413 | 410 | 25,090 | 5 | 0 |
| Chromium | 413 | 362 | 25,082 | 175 | 167 |

Compared with r13535 (`tests/suite-check.py`, with
`results/suite-*-r13536-series.csv`):

- New group: `THROW` (51 tests). Native passes. Under Node `TEST_REPLY`
  fails now and then: after REPLY the caller's SAY and the method's go on
  at once on two threads, and the test expects the caller's line first;
  the group alone passed 4 runs of 5, and the reference has a passing
  run (flaky, `known.tsv`). In Chromium its 8 errors are the tests that
  run `rexx` as a child process (RC 127).
- Node: `TRACE` passes: `TEST_TRACE_LABEL_WITH_FORWARD` no longer depends
  on thread timing (#2176, test/trunk r13540).
- Native: `ProcessInvocation` fails `TESTLOADLIBRARY` here, as in the local
  run of r13517; it passes in GitHub Actions. `CHAROUT` and `LINEOUT` are
  the usual ones of a run with the output redirected.
- Chromium: `API/oo/METHOD` has two errors more, `TESTTHROW05` and
  `TESTTHROW07`, which run `rexx` as a child process; `File` two failures
  fewer (flaky).
