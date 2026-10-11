# RFE #879 update, 8 October 2026: the same five patches, now also tested on r13263

*Posted as a comment on [RFE #879](https://sourceforge.net/p/oorexx/feature-requests/879/); the attachment it mentions is there.*

**The patches have not changed.** They are byte-identical to the attachment
of 7 October. Today's trunk commits (r13255–r13263) touch no file of the
series, so the patches apply cleanly to a checkout of trunk **r13263**, in
order, with `svn patch` or `git apply`. Everything was rebuilt and retested
there. They still apply to r13254 as well; the baseline line in
`wasm/README.md` (patch 1) still says r13254.

**Results on r13263** (official test suite, test/trunk r13263):

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 397 | 24,319 | 9 | 0 |
| Node.js command line | 388 | 23,471 | 9 | 8 |
| Chromium | 365 | 23,463 | 85 | 81 |
| Firefox | 366 | 23,463 | 84 | 81 |
| WebKit | 367 | 23,463 | 83 | 81 |

No crashes and no timeouts on any platform. Compared with 7 October:

- *DateTime now passes everywhere*, native included, thanks to the test fix
  in r13255: one group more on every platform. The rest of the differences
  are timing (native 395 → 397, Node unchanged at 388).
- *Timing-dependent groups moved, as before*. TRACE
  (`TEST_TRACE_LABEL_WITH_FORWARD`) passed natively this time and failed once
  under Node and in Chromium (it passes when rerun under Node). Under Node,
  `TEST_FILE_LASTMODIFIED` failed once: it compares two file times in whole
  milliseconds (1 run in 5 when repeated).

Everything else that fails has the causes listed before. The side-by-side
table in the attachment gives the cause of every group that does not pass
everywhere.

**A note on test/trunk r13264.** r13264 changes `ArrayClass.cpp` and
`array.testGroup` in the same commit. Its new Array tests make an
interpreter without that fix crash (SIGSEGV). I saw this with the official
r13263 Ubuntu package and with the WebAssembly build. That is expected, but
anyone who runs the latest tests against an older interpreter will see it.
This is why the run above uses test/trunk r13263.

**New attachment:** the five patches (unchanged) and `SHA256SUMS`, the
results as CSV (native, Node command line, Chromium, Firefox, WebKit), the
side-by-side table and the list of known causes. The build and test
instructions in `wasm/README.md` are unchanged.
