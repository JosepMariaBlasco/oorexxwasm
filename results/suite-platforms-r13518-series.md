# The official test suite on r13517 (test/trunk r13518, the series on trunk r13517)

Run locally, 15 November 2026, as for r13514
([`suite-platforms-r13515-series.md`](suite-platforms-r13515-series.md)):
Ubuntu 24.04 (x86_64), `TZ=Europe/Madrid`, native and Node as an ordinary
user, Chromium with `tests/suite-browser/run.py`. Firefox, WebKit and Windows
not run (GitHub Actions, on demand).

r13517 protects the condition object of a CATCH clause while the clause is
set up (RFE #31): before it, a garbage collection at that moment could free
it, and a clause that used it (`catch c = syntax`, `CONDITION('O')`, `RAISE
PROPAGATE`) crashed now and then. A routine called 200,000 times whose
clause uses `c` crashed in 3 runs of 3 under Node on r13514, and ends with
`ok` in 5 of 5 on r13517. test/trunk r13518 adds the tests for it
(`CATCH.testGroup`, 146 tests). The series is the same, byte for byte.

| | groups | passing | tests | failures | errors |
|---|---:|---:|---:|---:|---:|
| native (same series) | 409 | 406 | 24,780 | 3 | 0 |
| Node | 409 | 404 | 24,771 | 13 | 0 |
| Chromium | 409 | 360 | 24,763 | 176 | 141 |

The differences are those of r13514 (the earlier summary explains them),
and:

- Node: `RexxContext` failed once (`TEST_INTERPRETER_THREAD_INVOCATION`,
  flaky, in `known.tsv`); three runs of the group pass, and the reference
  has the passing run.
- Chromium: `CATCH` has two errors more, the two new tests, which run `rexx`
  as a child process (RC 127). `TEST_COMPILED` and `TEST_COMPILED_VARIABLE`
  run `rexxc` with `ADDRESS SYSTEM`: there is no compiled file, and the
  routine made from it returns nothing (91.999).
