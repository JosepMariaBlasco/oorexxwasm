# Threads, recursion and the test suite

*Written 03/10/2026 against ooRexx SVN trunk r13195; the work described here
is now part of patch 0001 of the current series (except the ooRexx bug fixes,
which are now in trunk).*

Base: ooRexx SVN trunk r13195 + Tom Dyer's dev1 patch. Toolchain: Emscripten
6.0.9, Node 22.22, headless Chromium (Playwright 1.56).

## 1. Root cause of the thread failures: no locks at all

`librexx` is a STATIC archive in the WASM build. Nothing references
`interpreter/platform/unix/SystemInitialization.cpp`, so the linker dropped that
object — and with it the ELF constructor `_rexx_init()`, which calls
`processStartup()` → `createLocks()`. Every `SysMutex` therefore stayed
`created == false`; `SysMutex::request()` returns `false` without locking and
callers ignore the return value. The interpreter ran all threads with **no
kernel lock**: `ActivityManager::currentActivity` was overwritten by other
threads, giving `null function or function signature mismatch` crashes (vtable
call through a null `topStackFrame`) and hangs.

How it was found: instrumented `MessageClass::dispatch()` (`cur=0`), then the
kernel lock (double owners), then `SysMutex::request()` ("request on uncreated
mutex", 100+ times even for `say 1`), then `_rexx_init` (never printed).

Fix: link `rexx` with `$<LINK_LIBRARY:WHOLE_ARCHIVE,rexx>` for `rexx_exe` and
`rexximage` (EMSCRIPTEN only). Note the precedent upstream: bug #2078 (the same
"created flag reset → lock guards nothing" symptom from static-init order).

Result (Node): 10 concurrent STARTs 5/10 → 30/30; 50 concurrent STARTs 10/10.

## 2. -sPROXY_TO_PTHREAD, no Asyncify

The interpreter runs on a worker; the JS main thread stays free to start
workers and deliver WebSocket events. Blocking is legal on the worker, so
Asyncify was dropped (the RxSock shim's `emscripten_sleep(1)` became
`usleep(1000)`; socket syscalls are proxied to the main thread).

Browser, which used to freeze on any thread creation: START, REPLY, .Alarm,
10 concurrent STARTs, SysSleep, low-level sockets and .StreamSocket all pass.

Regression found and fixed: `.StreamSocket~new("localhost", port)` →
ECONNREFUSED. Emscripten fakes DNS with a JS table (`$DNS`); `getaddrinfo` is
proxied to the main thread but `_emscripten_lookup_name` (used by
`gethostbyname`) is not, so the name→fake-IP mapping was made in the worker's
table and `connect()` on the main thread could not map it back. Fixed with
`wasm/emscripten-dns-proxy.js` (`--js-library`) redefining it with
`__proxy: 'sync'`. **Upstream candidate (Emscripten).**

## 3. Recursion: -fwasm-exceptions + native stack probe → clean Error 11

Without Asyncify, `-fwasm-exceptions` is usable (no JSPI needed).

| | dev1 | with the first probe |
|---|---|---|
| Node, max Rexx depth | ~312 (dies, RangeError) | ~9,700, then Error 11 |
| Browser, max depth | ~165 (dies) | ~680–730, then Error 11 |
| rexx.wasm | 2.2 MB | 981 KB (with rxregexp + rxmath) |

`checkStackSpace()` only watches the linear-memory C stack; the frames live on
the JS engine's native stack, which runs out first (browser workers: a few KB of
native stack per Rexx level). Added under `__EMSCRIPTEN__`:

- `wasmNativeStackLow()` (EM_JS): a probe that checks whether enough native
  stack is left; if it does not fit, the engine throws (RangeError, or
  InternalError "too much recursion" in Firefox), which the probe catches →
  Rexx Error 11 while there is still room to handle it (a SYNTAX trap handler
  runs at the depth where the error was raised — internal routines inherit
  SIGNAL ON). The probe recurses through wasm frames (`orxWasmStackProbe`,
  called through a volatile pointer) to a depth calibrated once per thread to
  a quarter of the deepest recursion that fits while the stack is still
  shallow. The first version was a JS `apply()` call with 32768 arguments
  (~256 KB of native stack); it was replaced because in Firefox a JS-only
  probe still succeeds while wasm frames already overflow (see
  `browser-suite.md`, which also has the depths measured with the current
  probe).
- The probe costs ~20 µs, so it is gated: in `checkStackSpace()` only when
  `stackFrameDepth` is 8 frames deeper than the deepest depth already probed
  OK (loops never probe; reset whenever `stackLimit` is re-established); in
  `LanguageParser::parseSubTerm()` every 8 levels of nesting (the parser
  pushes no activations).
- Internal *function* calls (`x = f(n)`) had no stack check at all — `CALL`
  checks in CallInstruction, the function path did not — so
  `RexxActivation::internalCall()` needed a `checkStackSpace()` call. This is
  not WASM-specific: reported as ooRexx bug #2093 and fixed in trunk r13251.

Rejected on the way (measured): probing on every check (11 µs/call, 20× slower
calls); gating on the linear stack pointer (only 80 B/level for calls and 0 for
the parser, while native use is 600 B–7 KB/level).

`tests/recursion-cases.txt` / `tests/probe-recursion.sh`: function, CALL,
method, INTERPRET, ::routine, trapped, depth, parser nesting (20,000 parens),
recursion inside a START thread — all end in Error 11 / trapped 11.1, in Node
and Chromium. Call benchmark unchanged (200k calls ≈ 0.11 s).

## 4. Embedded extension packages

`PackageManager::embeddedPackages[]` (WASM only) replaces the single
`rxsockPackage`: rxsock, rxregexp, rxmath are compiled into librexx with
`ORX_EMBEDDED_PACKAGE`, which turns `OOREXX_GET_PACKAGE()` into nothing (each
package would otherwise define its own `RexxGetPackage`). rxregexp is required
by the test framework. `rxregexp.cls` is preloaded in the browser build.

## 5. ooRexx bug: SysFileIterator without FNM_CASEFOLD

`SysFileIterator::findNextEntry()` (unix), in the `#ifndef HAVE_FNM_CASEFOLD`
branch, uppercases every name after the first one even for case-sensitive
searches, and `free()`s `testName` even when it is `entry->d_name` (heap
corruption). Invisible on glibc (has FNM_CASEFOLD); the dev1 build cache had
set `HAVE_FNM_CASEFOLD 0` though musl supports it. Symptom:
`SysFileTree("dir/*.testGroup")` found nothing. The WASM cache now says
`HAVE_FNM_CASEFOLD 1`; the branch itself (now guarded by `caseLess`) was
reported as ooRexx bug #2096 and fixed in trunk r13254.

## 6. Node command-line variant for real scripts / the test suite

A relink script (now `wasm/build-node.sh`, patch 0002) builds, without
recompilation, a Node-only runtime with NODERAWFS (host files), the host
environment copied into `ENV`, and a `rexx` launcher. It works around an
Emscripten 6.0.9 NODERAWFS bug: `FS.fstat()` dereferences `stream.node`, which
NODERAWFS streams lack (TypeError on `node_ops`). **Upstream candidate
(Emscripten).**

## 7. External data queue (and the rest of the RexxAPI): in-process server

No rxapi daemon can run in a WASM process. The server code
(`rexxapi/server/*`: queues, registrations, macrospace) is linked into
`librexxapi`, and the client reaches it through `SysLoopbackConnection`
(`rexxapi/common/platform/unix/`): `ClientMessage` writes the request as
usual; on the first read the request is decoded and handed to
`APIServer::processMessage()` (new, WASM-only: the per-message part of
`processMessages()`) on the calling thread, and the reply is read back. The
protocol and the server are unchanged — only the transport. The
`#if !defined(__EMSCRIPTEN__)` that the dev1 patch had put around
`RexxCreateSessionQueue()` / `RexxDeleteSessionQueue()` was removed.

PUSH/QUEUE/QUEUED()/PARSE PULL/LINEIN("QUEUE:"), named queues (RXQUEUE),
8 threads × 100 concurrent QUEUEs (800, sum 3600, 3/3 runs) — Node and
Chromium. RxFuncAdd/subcom registration and macrospace go through the same
server.

## 8. hostemu embedded (loaded on demand)

`embeddedPackages[]` entries carry `inImage`. rxsock/rxregexp/rxmath are
registered when the image is built (their loaders do nothing on unix);
hostemu is registered on first request in `PackageManager::loadLibrary()`, so
its loader (`RexxRegisterSubcomExe("HostEmu")`) runs in the current process —
`LibraryPackage::reload()` never calls loaders. Needed by the SIGNAL test
group (`::requires "hostemu" LIBRARY`).

## 9. Other fixes found by the suite

- **`VariableReference::setValueRexx` returned `void`** but is registered as a
  native method, which `CPPCode::run` calls as `RexxObject *(...)`. x86
  tolerates it; WASM traps ("function signature mismatch") → the VarRef group
  killed the runtime. The fix (return `OREF_NULL`) is not WASM-specific: it
  was reported as ooRexx bug #2095 and fixed in trunk r13253.
  `scripts/check-method-signatures.py` scans all 652 registrations in
  Setup.cpp: this was the only real one.
- **Listening sockets** (`SockListen`, socketClass group): SOCKFS on Node does
  `new (require('ws').Server)`, absent from the client-only shim →
  "WebSocketServer is not a constructor" killed the runtime. The shim now
  makes `listen()` fail with EOPNOTSUPP, as in the browser.

## 10. Official test suite (test/trunk r13195)

`tests/run-suite.sh` runs each test group in its own process (a crash only
loses that group), serialised per directory, and writes `results.csv`.

| run | groups ok/fail/crash | tests | failures | errors |
|---|---|---|---|---|
| native (same tree, x86-64, as root) | 397 / 5 / 0 | 24,512 | 9 | 0 |
| WASM, before queue/hostemu/listen fixes | 353 / 48 / 1 | 23,584 | 116 | 112 |
| WASM, final (pool, macrospace, rxunixsys) | 364 / 38 / 0 | 23,656 | 86 | 81 |

These r13195 result files are not in the repository; current results (trunk
r13263 with the current series) are in `results/`, e.g.
`results/suite-wasm-r13263-series.csv` and
`results/suite-platforms-r13263-series.md`.

The 5 native failures (CHAROUT, LINEOUT, File, Stream, SysFileXXX) are the
ones the suite's ReadMe warns about (running as root / redirected output).

Why the 38 WASM groups still failed at r13195:

| cause | groups |
|---|---|
| external commands (no processes: RC 127) | ADDRESS (23 F), samples (29 F), utilities/rexx_command, rexxc, rxqueue, rxsubcom; and single tests that shell out in ARG, CONDITION, LINEIN, STREAM, Stream, Method, Routine, RexxQueue, OPTIONS, PARSE, SIGNAL, Macrospace (other-interpreter test), incorrectCharacters, RESULT_RC_SIGL, bug2003_guard_when, CHAROUT, probably environmentEntries (`.rs`) |
| native API test libraries (orxmethod…, no dlopen) | API/classic, API/oo × 7 |
| listening sockets | socketClass (9 F) |
| same as native (root / redirection) | CHAROUT, LINEOUT, File, SysFileXXX, Stream |
| timing-flaky, also native under load | TRACE (TEST_TRACE_LABEL_WITH_FORWARD; 1/5 native under load) |
| WASM-specific, small | RexxInfo (executable = node; libraryPath not a File), SysSleep (1e-8 s measured as 0), File timestamps before 1970 (NODERAWFS) |

What fixed groups between the first and the final run: the data queue
(ASSIGNMENT, NUMERIC, QUEUED, RXQUEUE, RexxQueue mostly), hostemu (SIGNAL
group loads), the ws shim (socketClass runs instead of crashing), the
thread pool (GUARD ×3, TRACE REPLY, TraceObject, RexxContext, RAISE CRLF),
macrospace translation without dlopen (Macrospace 14 F → 0), rxunixsys
(SysFileTree).

## 11. More fixes after the first suite run

- **Thread pool** (`-sPTHREAD_POOL_SIZE=4`): first START/REPLY latency
  52 ms → ~1 ms (each new worker loads the module). Timing-sensitive tests
  (GUARD expects the replied thread to run within 15 ms) depended on it.
  Stress 20/20 (10 threads) and 10/10 (50 threads) with the pool — the
  instability seen in earlier runs was the missing locks.
- **Macrospace**: `LocalMacroSpaceManager::translateRexxProgram()` looked up
  `RexxTranslateInstoreProgram` with `dlopen("rexx")`; under WASM it is
  called directly.
- **rxunixsys** embedded (on demand) for `SysStat`; the WASM cache now says
  `HAVE_WORDEXP(_H) 0` and `HAVE_SYS_XATTR_H 0` (musl declares them,
  Emscripten does not implement them).
