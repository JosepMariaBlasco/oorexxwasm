# RFE #879 update, 6 October 2026: the test suite in Chromium, Firefox and WebKit; new attachment

*Posted as a comment on [RFE #879](https://sourceforge.net/p/oorexx/feature-requests/879/); the attachment it mentions is there.*

As promised to Gil and P.O.: the official test suite (test/trunk r13248)
now runs **inside the browser build**, in Chromium 141, Firefox 142 and
WebKit 26, driven by Playwright on one Linux machine. Each test group is one
run of `testOORexx.rex`, a fresh interpreter in its own Web Worker, with the
test tree in its in-memory file system. The result is the same CSV as for
native and Node (`group,status,ran,assertions,failures,errors,seconds`), so
the platforms can be put side by side:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 396 | 24,522 | 10 | 0 |
| Node.js command line | 389 | 23,674 | 7 | 8 |
| Chromium | 363 | 23,385 | 85 | 81 |
| Firefox | 364 | 23,385 | 84 | 81 |
| WebKit | 364 | 23,385 | 84 | 81 |

The three engines agree. Every group that does not pass in a browser has a
known cause:

- **24 groups run external commands** (`rexx`, `rexxc`, `rxqueue`,
  `rxsubcom`, `sh`, `echo`, `id`...); samples.testGroup runs each sample as
  a `rexx` process. A browser has no processes, so these commands end with
  RC 127. This is the platform, not a bug.
- **8 API groups** need the native test libraries, as under Node.
- **json_02 and yaml: a bug in the tests**, not in the port (details below).
- **RexxInfo**: `TEST_REXXINFO_EXECUTABLE` expects a File (details below).
- **File**: no shell on PATH, and Emscripten reads file times back in whole
  milliseconds (2 `*_FRACTIONS` tests, which also fail under Node now that
  the clock has sub-millisecond resolution, see below).
- **CALL TEST_STACKSIZE** wants 5,000 levels. Chromium and Firefox give a
  clean Error 11 earlier (about 900 and 1,300 levels; WebKit passes). The
  limit is the JavaScript engine's native stack.
- **rxsock's socketClass**: in a browser RxSock goes over WebSockets, so there
  is no listening socket and no socket options.
- **TRACE** failed once in Chromium. It is timing between threads, and it
  passes when rerun (also seen under Node).

**`.RexxInfo~executable` and `~libraryPath` in the browser.** On every other
platform `executable` is a file in the file system the program sees. In a
browser there is an executable too, of course: `rexx.wasm` with its
`rexx.js`. But it was loaded from a URL (or from the browser's cache), not
from the program's file system, which is an in-memory one made for each run.
`executable` must return a File, and no File in that file system is the
interpreter. A placeholder `/usr/bin/rexx` would be a file that is not the
executable, and it would only satisfy tests that then run nothing real. So
in the browser build `executable` stays **.nil**, which is what ooRexx
already does when it cannot tell (OpenBSD, before trunk learned to resolve
argv[0], and still when argv[0] cannot be resolved), and what the framework
already allows for (`FileUtils.cls` falls back to `libraryPath`).
`libraryPath`, on the other hand, has a true answer: **`/usr/lib/ooRexx/`**,
the directory where the browser build preloads the extension classes, and
which exists in the program's file system. With that, the samples groups
no longer break while being set up, and only the `executable` half of
RexxInfo's test fails.

**The json_02 and yaml test bug.** Their `init` method does
`executableLocation=filespec('location',.rexxInfo~executable)` without
checking for .nil. The whole group then fails before any test runs, wherever
`executable` is .nil: in the browser, and on OpenBSD when argv[0] cannot be
resolved. Only one test, the XSLT round trip, uses that location, and it
already falls back when the file is not there. A two-line fix (keep
`executableLocation` empty when `executable` is .nil) makes both groups pass
in the browser: 227 tests in json_02 and 54 in yaml, the same counts as
native. It belongs in the test repository, so it is not part of the series; it
will go there separately.

**Running in three engines found four problems in the port. All are fixed
in the new attachment:**

1. **Firefox:** deep recursion killed the run instead of raising Error 11.
   The native stack probe now recurses through WebAssembly frames and is
   calibrated on each thread (patch 5).
2. **WebKit:** 5–10% of runs hung. WebKit sometimes loses an
   `Atomics.waitAsync` wakeup, which Emscripten uses to tell a thread that
   a system call was handed to it. I reproduced it with a 15-line C
   program, without ooRexx. The browser runtime now hides `waitAsync`, so
   Emscripten falls back to `postMessage` (patch 9). After that, no WebKit
   run hung.
3. **WebKit:** a Rexx error raised in a method started with START killed
   the run. The legacy encoding of WebAssembly exceptions loses C++
   exceptions on secondary threads there. The port now uses the
   standardized encoding (exnref), which the legacy one is deprecated in
   favour of (patch 5). Minimum versions: **Chrome 137, Firefox 131,
   Safari 18.4, Node.js 22**.
4. **The clock had millisecond resolution**, because Emscripten's wall clock
   is `Date.now()`: the microseconds of `TIME('L')` were always 000, and
   SysSleep's own test failed. It now uses `performance.timeOrigin +
   performance.now()` (patch 5, and patch 9 for the in-memory file system's
   time stamps).

**New attachment:** patches 0001–0004 are unchanged (byte-identical).
Patches 0005–0009 replace the earlier ones. The zip has the patches,
`SHA256SUMS`, and the CSVs of the five platforms, plus a table that puts
them side by side with the cause of each failing group. With the new series,
the qualification scripts all pass (base runtime under Node, 14 Node CLI
checks, 22 browser API cases).

**For Jenkins (P.O.'s question):** the browser run is one command per
engine on a Linux agent with Playwright: Chromium, Firefox and WebKit all
run headless. The runner is a small Python script and a page. If the
project wants it, I can move it into the tree (`wasm/tests/`) next to the
other qualification scripts.
