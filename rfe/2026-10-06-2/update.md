# RFE #879 update, 6 October 2026 (2): json/yaml fixed, macOS build, a correction, new attachment

*Posted as a comment on [RFE #879](https://sourceforge.net/p/oorexx/feature-requests/879/); the attachment it mentions is there.*

**macOS.** Jean-Louis built the port on macOS (Apple silicon), out of source,
and the qualification passes there. His report gave three portability fixes,
now in the series:

- the build printed hundreds of `redirecting incorrect #include
  <sys/signal.h> to <signal.h>` warnings (on Linux too). `SystemInterpreter.hpp`
  includes `<sys/signal.h>` when CMake finds it, and Emscripten has it only as
  a redirect. The WebAssembly CMake cache now says it is absent (`<signal.h>`
  is included anyway). No change to the common CMakeLists.txt.
- `qualify-node.sh` and `qualify-node-cli.sh` use GNU `timeout`, which macOS
  lacks. They now take `timeout` or `gtimeout` (Homebrew's coreutils), and
  say so clearly if there is neither.
- the README now says to install Python's `websockets` in a virtual
  environment where pip refuses to change the system Python (PEP 668, as
  with Homebrew), and to install coreutils on macOS.

One more warning of ours went too (an empty JavaScript string inside C++ in
patch 7).

**A correction to point 3 of my previous update** (WebKit and C++
exceptions). I had written that WebKit loses C++ exceptions thrown on
secondary threads with the legacy exception encoding. Looking closer, it is
neither about threads nor about the legacy encoding. WebKit's WebAssembly
interpreter does not catch an exception thrown by a function called through
`call_indirect` when that call is the last instruction of a `try` (or
`try_table`) body, in both encodings. Once the function is hot and compiled
by the JIT, the same code catches correctly. Threads only mattered because a
new thread is a new worker, where all code is still cold and interpreted. It
is fixed in WebKit 26.6: Safari 26.6 on macOS (thanks, Jean-Louis) and WebKit
26.6 on Linux catch it, WebKit 26.0 does not. The choice of exnref stands: the
legacy encoding is deprecated, and with exnref the compiler produces that
shape in 4 places instead of 52. The comments in patch 5 now say this.

**Point 2 (lost `Atomics.waitAsync` wakeups in WebKit).** It now reproduces
in plain JavaScript, without WebAssembly: two workers, one waiting with
`waitAsync`, the other notifying. `Atomics.notify` reports a woken waiter,
but the promise never resolves. It hangs often with WebKit 26.6 on Linux, and
it was seen on an iPad (thanks, Rony). Safari 26.6 on macOS did not hang in
20 rounds. The workaround in patch 9 stays. I will report it to WebKit.

**json_02 and yaml now pass in the browsers.** The test bug from my
previous update is #2097, fixed in test/trunk r13249 (which differs from
r13248 only in those two test groups). With it both groups pass on all five
platforms, with the same 227 + 54 tests as native:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 396 | 24,522 | 10 | 0 |
| Node.js command line | 389 | 23,674 | 7 | 8 |
| Chromium | **365** | 23,666 | 85 | 81 |
| Firefox | **366** | 23,666 | 84 | 81 |
| WebKit | **366** | 23,666 | 84 | 81 |

No group crashes in any browser any more. Everything that still fails has
the causes listed last time (processes, native test libraries, the
`executable` half of RexxInfo, the CALL group (stack depth), rxsock's server
side, TRACE timing).

**File times.** The 2 File `*_FRACTIONS` failures in the browser come from
Emscripten's in-memory file system, which keeps file times in whole
milliseconds. That is now Emscripten issue #27885. Under Node, Emscripten
6.0.11 already returns sub-millisecond times.

**New attachment:** patches 0001–0004 unchanged (byte-identical). Patches
0005–0009 replace the earlier ones. What changed is only build settings, test
scripts, comments and documentation, with no change in runtime behaviour. The
qualification scripts were rerun and pass (also with only `gtimeout` on the
PATH). The results are now for test/trunk r13249: json_02 and yaml were rerun
on all five platforms with the new series, and the other rows carry over from
the previous update (same tests, no runtime change). The side-by-side table
and the list of causes are updated.
