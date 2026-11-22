# The official test suite on r13591 (test/trunk r13592, the series on trunk r13591)

Run locally, 22 November 2026, as for r13564
([`suite-platforms-r13565-series.md`](suite-platforms-r13565-series.md)):
Ubuntu 24.04 (x86_64), `TZ=Europe/Madrid`, native and Node as an ordinary
user, Chromium with `tests/suite-browser/run.py`. Firefox, WebKit and Windows
not run (GitHub Actions, on demand): their references stay r13535's.

r13591 is trunk's newest main revision: `THREAD_INTERFACE_VERSION` 105 for
`ThrowObject()` (r13568); the Rexx Parser and Highlighter in
`extensions/parser` (RFE #878, r13570-r13573, with its fixes up to r13591);
a THROW action in the test binaries' context exits (r13579). The series
only moves (offsets), and packages the Rexx Parser in every build: Node
(`parser.cls`, `parser/`, and the utilities `highlight.rex`,
`rexxcheck.rex`, `fencedcode.rex` next to `rexx.js`) and the browser
(`/usr/lib/ooRexx` in `rexx.data`). test/trunk r13592 adds the Parser's 13
test groups (`ooRexx/extensions/parser`, 726 tests).

| | groups | passing | tests | failures | errors |
|---|---:|---:|---:|---:|---:|
| native (same series) | 426 | 423 | 25,846 | 3 | 0 |
| Node | 426 | 422 | 25,837 | 6 | 0 |
| Chromium | 426 | 373 | 25,829 | 177 | 168 |

Compared with r13564 (`tests/suite-check.py`, with
`results/suite-*-r13565-series.csv`): no regressions on any of the three.

- The 13 new groups pass natively. Under Node and in Chromium 12 pass;
  `extensions/parser/BIFs` has one failure, `TEST_BEEP`: `Call Beep 1E17, 1`
  is expected to give 40.927 (out of range), but on a 32-bit build (wasm32)
  1E17 is not a whole number (9 digits), and the interpreter and the
  parser both give 40.12. The test assumes 64 bits (`known.tsv`, upstream).
- Native and Node: otherwise the same groups pass and fail.
- Chromium: `File` one failure less (flaky).
