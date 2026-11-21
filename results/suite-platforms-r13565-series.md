# The official test suite on r13564 (test/trunk r13565, the series on trunk r13564)

Run locally, 21 November 2026, as for r13550
([`suite-platforms-r13553-series.md`](suite-platforms-r13553-series.md)):
Ubuntu 24.04 (x86_64), `TZ=Europe/Madrid`, native and Node as an ordinary
user, Chromium with `tests/suite-browser/run.py`. Firefox, WebKit and Windows
not run (GitHub Actions, on demand): their references stay r13535's.

r13564 is trunk's newest main revision: `ThrowObject()`, with
`RaiseConditionObject` always raising one level (r13554); a condition
thrown in a native command environment reaches the issuer thrown (r13557);
the `Throw()` API takes a name with blanks around it (r13559); #2179
(r13562) and #2180 (r13564: THROW SYNTAX has its own errors 33.905, 41.902
and 98.940). The series only moves (offsets); the JavaScript bridge throws
a thrown condition again with `ThrowObject()`.

| | groups | passing | tests | failures | errors |
|---|---:|---:|---:|---:|---:|
| native (same series) | 413 | 410 | 25,119 | 3 | 0 |
| Node | 413 | 410 | 25,110 | 5 | 0 |
| Chromium | 413 | 361 | 25,102 | 177 | 168 |

Compared with r13550 (`tests/suite-check.py`, with
`results/suite-*-r13553-series.csv`):

- Native and Node: the same groups pass and fail.
- Node: `THROW` (53 tests now) passes every time: in the full run and
  alone in 6 runs of 6, with both cores busy. Its two REPLY tests no longer
  assert which thread writes first (test/trunk r13561); no longer flaky in
  `known.tsv`.
- Chromium: `API/oo/FUNCTION` has one error,
  `TEST_ADDCOMMANDENVIRONMENT_THROW_UNCAUGHT` (test/trunk r13558), which
  runs `rexx` as a child process (RC 127); `THROW`'s 8 errors are the same
  kind; `File` two failures more (flaky).
