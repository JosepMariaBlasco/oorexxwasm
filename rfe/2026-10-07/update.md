# RFE #879 update, 7 October 2026: patches 1–4 are in trunk; five patches on r13254, new attachment

*Posted as a comment on [RFE #879](https://sourceforge.net/p/oorexx/feature-requests/879/); the attachment it mentions is there.*

**Patches 1–4 are committed.** The four bug fixes that opened the series are
now in trunk (r13251–r13254; bugs #2093, #2094, #2095 and #2096), so they
leave the attachment. The series is now the five WebAssembly patches, on
trunk **r13254**. That revision also has Erich's DATE/TIME fixes (r13250),
which touch no file of the series, so they needed no change to the
patches; everything was rebuilt and retested on r13254.

| new | was | |
|---|---|---|
| 1/5 | 5/9 | build and base runtime |
| 2/5 | 6/9 | Node: external commands, rexxc, host errno values |
| 3/5 | 7/9 | Node: RexxAPI shared between processes |
| 4/5 | 8/9 | Node: real TCP/UDP sockets and name resolution |
| 5/5 | 9/9 | browser runtime for web pages |

**What changed since the previous attachment.** Patches 3 and 4 only in
line numbers and context; patch 1 also updates the baseline line of
`wasm/README.md` to r13254. Patches 2 and 5 have three fixes from reports by
Jean-Louis and Rony (thank you both):

- *Patch 2: the Node build installed every extension class* (Jean-Louis).
  `build-node.sh` copied all of `extensions/*.cls` next to `rexx`, including
  ooDialog, OLE, winsystm and ncurses, which cannot work there. It now copies
  the same portable list as the browser build.
- *Patch 2: LINES() on standard input* (Jean-Louis). At a terminal,
  `rexx -e "say lines()"` said 1 (native: 0), and in rexxtry the answers
  changed from one call to the next. For standard input, `SysFile::hasData()`
  asks the system how many bytes are waiting, with `ioctl(FIONREAD)`.
  Emscripten answers that call with success but never writes the count, so
  `LINES()` read an uninitialised variable. The browser build already
  answered `FIONREAD` itself; the Node build now does too, for the host's
  standard input: for a redirected file, the bytes left; for a terminal,
  `/dev/null` or another device, 0; for a pipe, which Node cannot ask without
  reading, the data is read ahead and given to the next reads. The results
  are the same as native for a terminal (also in rexxtry), `/dev/null`, an
  empty pipe, a pipe with data, a redirected file, `CHARS()`, and the usual
  `do while lines() > 0; parse pull ...` loop. The only intended difference:
  with a pipe whose writer has not written anything yet, `LINES()` waits for
  it instead of answering 0 at once. The same patch now installs
  `rexxtry.rex` next to `rexx`, as native installations do, so
  `rexx rexxtry` works. `qualify-node-cli.sh` has two new checks.
- *Patch 5: trace output of several threads* (Rony). With `TRACE` and
  several threads, the browser sometimes showed a `SAY` line in the trace
  colour, or a trace line as an error. The marks that tell the page which
  output is trace, error or plain output were a single global slot, so
  threads mixed them up. They are now kept per thread, and each write to
  standard output or error publishes the mark of the thread that writes.
  With Rony's program: 3 to 14 lines in the wrong colour per run before, none
  in 10 runs after. `web-api.py` has a new case for it.

**Results on r13254** (official test suite, test/trunk r13254, which has
Erich's new DATE and TIME tests). All five platforms were run again with the
new series:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 395 | 24,315 | 10 | 1 |
| Node.js command line | 388 | 23,467 | 7 | 9 |
| Chromium | 364 | 23,459 | 85 | 82 |
| Firefox | 365 | 23,459 | 84 | 82 |
| WebKit | 366 | 23,459 | 83 | 82 |

No crashes and no timeouts on any platform. Compared with the previous
update (test/trunk r13249), nothing changed because of the series. The differences come from
the suite itself and from timing:

- *DateTime, one error on every platform, native included.*
  `TEST_FROMCIVILTIME` still uses `"0:00am"` as a valid civil time, which
  r13250 now rejects on purpose (`TIME.testGroup` itself expects error 40.19
  for `"00:00am"`). The test needs adjusting (Erich, I can send the details).
- *207 fewer tests ran, on every platform alike.* `TIME.testGroup` was
  regrouped in r13250 (306 tests → 91) and `DATE.testGroup` has 8 more.
- *Timing-dependent groups moved in both directions*, none reproducible:
  TRACE failed once natively (`TEST_TRACE_LABEL_WITH_FORWARD`, the count of
  trace lines depends on thread timing; 5 reruns pass) and now passes in
  Chromium; RexxContext failed once in Chromium (a test reads a value that a
  START thread had not written yet; 6 reruns pass); ProcessInvocation now
  passes natively; CALL (stack depth) now passes in WebKit.

Everything else that fails in the browsers has the causes listed before:
external processes, the native test libraries, the `executable` half of
RexxInfo, stack depth (CALL) in Chromium and Firefox, rxsock's server side,
and file times in whole milliseconds in Emscripten's in-memory file system
(two File tests; Emscripten #27885). The side-by-side table in the attachment gives the cause of every
group that does not pass everywhere.

**New attachment:** the five patches and `SHA256SUMS`, the results as CSV
(native, Node command line, Chromium, Firefox, WebKit), the side-by-side
table and the list of known causes, as before. They apply with `svn patch`
(or `git apply`) to a clean checkout of trunk r13254, in order. The
build and test instructions in `wasm/README.md` (patch 1) are unchanged.
