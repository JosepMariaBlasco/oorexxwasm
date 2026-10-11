# RFE #879: WebAssembly port of ooRexx (browser and Node.js)

*The request as posted on [SourceForge](https://sourceforge.net/p/oorexx/feature-requests/879/)
on 4 October 2026 (without the signature). Summary: WebAssembly port of ooRexx 5.3
(browser and Node.js): patch series for review. Its attachments are on the ticket.
What changed since is in the [updates](../README.md).*

## What this is

A port of the ooRexx interpreter to WebAssembly with Emscripten, offered as a
series of patches against trunk r13248 for the committers to review. It is
submitted as an RFE because several of the questions it raises are for the
project to decide, not for one committer (see Decisions below).

The port provides three builds from one compilation:

- **The base runtime** (`rexx.js` + `rexx.wasm` + `rexx.data`), which runs
  under Node.js and in a browser. It runs the full interpreter and image,
  with threads (START, REPLY, .Alarm, GUARD), the external data queue and
  the rest of the RexxAPI. rxsock, rxregexp, rxmath, hostemu and rxunixsys
  are embedded. Deep recursion ends in Error 11, as natively.
- **A Node.js command-line ooRexx** (`wasm/build-node.sh`): `rexx`,
  `rexxc`, `rxqueue` and `rxsubcom` that work on the host file system and
  environment. ADDRESS commands run as real processes, ADDRESS ... WITH
  included. The RexxAPI is shared between processes by a daemon, like
  rxapi. RxSock has real TCP/UDP sockets, servers included, and real name
  resolution.
- **A browser runtime for web pages** (`wasm/build-web.sh`): one Web Worker
  per run and interactive standard input (PULL, LINEIN, CHARS/LINES).
  Programs can be stopped, and files can be passed in and collected
  afterwards. A small JavaScript API is included: `OoRexx.load()`,
  `run({...})`.

Outside WebAssembly the series is meant to change nothing. The code is
under `if (EMSCRIPTEN)` in CMake or `#if defined(__EMSCRIPTEN__)` in C++, or
lives in the new `wasm/` directory. The exceptions:

- the four bug fixes below, which are separate patches and separate tickets;
- a few changes that compile natively but do nothing there:
  - `HOST_ERRNO()` / `HOST_ERRNO_REVERSE()` (unix and Windows `SysFile.hpp`)
    and `SysProcess::hostErrno()` / `localErrno()` are the identity outside
    WebAssembly;
  - `SysFile.hpp` is now included in `SysRexxUtil.cpp` and
    `SystemCommands.cpp`;
  - a declaration in `LocalMacroSpaceManager.cpp` moved;
  - in the public `oorexxapi.h`, `OOREXX_GET_PACKAGE` is empty when the new
    macro `ORX_EMBEDDED_PACKAGE` is defined (only the WASM build defines it,
    for the packages linked into the interpreter).

Native builds were verified on Linux x86-64 only (see Status). The Windows
change is the one-line identity macro, but Windows, macOS and the BSDs have
not been built.

## Try it

- **In a browser, without installing anything:** the ooRexx Playground at
  <https://rexx.epbcn.com/oorexx-wasm/> runs this interpreter (the
  `build-web.sh` runtime). The playground page itself is not part of the
  submission.
- **Build it on Linux.** You need Node.js 22 or later on PATH, CMake,
  Python 3 and Subversion (or git). The build itself takes about 5 minutes
  on two cores.

```bash
# Emscripten 6.0.9
git clone https://github.com/emscripten-core/emsdk && cd emsdk
./emsdk install 6.0.9 && ./emsdk activate 6.0.9 && cd ..
node --version            # must be >= 22 (or: source emsdk/emsdk_env.sh for emsdk's node)
# ooRexx trunk r13248 + the series
svn checkout -r 13248 https://svn.code.sf.net/p/oorexx/code-0/main/trunk oorexx
cd oorexx
for p in /path/to/patches/*.patch; do svn patch "$p"; done
# (or git apply; with patch -p1 also chmod +x wasm/*.sh wasm/tests/*.sh wasm/tests/*.py)
./wasm/build-wasm.sh ../emsdk/upstream ../build-wasm   # base runtime -> ../build-wasm/bin
./wasm/build-node.sh ../build-wasm                     # Node CLI     -> ../build-wasm/bin-node
./wasm/build-web.sh ../build-wasm                      # browser      -> ../build-wasm/bin-web
../build-wasm/bin-node/rexx -e 'say "Hello from WebAssembly"; say .RexxInfo~platform'
```

- **Check it:** each part brings its own qualification script with
  assertions (exit status 0 only if all checks pass):

```bash
pip install websockets                                   # WebSocket echo server for the base runtime
./wasm/tests/qualify-node.sh ../build-wasm               # base runtime under Node
./wasm/tests/qualify-node-cli.sh ../build-wasm/bin-node  # Node CLI: files, commands, rexxc, rxapi, sockets, DNS
pip install playwright && playwright install chromium   # for the browser test
python3 wasm/tests/web-api.py ../build-wasm/bin-web      # browser API in headless Chromium
```

`wasm/README.md` documents the design and the platform policy.

## Status

- **Official test suite** (test/trunk r13248, one process per test group),
  run on the Node command-line build: **389 of 402 test groups** end without
  failures (23,674 tests, 340,944 assertions). Six of the 389 run no tests:
  SysGetMessage, tilde, ncurses, SysUnix (rxunixsys) and rxapi are
  restricted to UNIX, and the test framework (`ooTest.frm`, `knownOSes`)
  does not know `.RexxInfo~platform = EMSCRIPTEN`; SourceFile is restricted
  to Windows and Linux.

  With EMSCRIPTEN added to `knownOSes` as an experiment:

  - tilde passes;
  - SysGetMessage fails 1 test (no message catalogs);
  - SysUnix fails 10 tests (SysStat of a Unix-domain socket, group database,
    getservbyport, crypt);
  - ncurses and rxapi cannot run (no ncurses, no native rxapi).

  Whether the framework should treat EMSCRIPTEN as UNIX is one of the
  decisions below. Some groups run fewer assertions than natively (e.g.
  File, RexxInteger), because they skip parts on platforms they do not
  recognise.

  The 13 groups that fail:

  - 8 API groups (CLASSIC, CONVERSION, FUNCTION, INVOCATION, METHOD,
    ProcessInvocation, ProcessRexxStart, RexxStart). They need the native
    test libraries (orxmethod, …), which a WASM build does not have.
  - 5 groups that also fail in a native build in the same environment:
    CHAROUT, LINEOUT, Stream, File and SysFileXXX. The suite's ReadMe warns
    about running as root and with redirected output. In CHAROUT, LINEOUT
    and Stream the same test fails in both builds. In File and SysFileXXX
    the WASM build fails fewer tests than native, but File fails one
    WASM-specific test: timestamps before 1970 cannot be set (Emscripten's
    NODERAWFS).

  SysSleep and TRACE are timing-sensitive and occasionally fail under
  load. Both passed in this run.
- **Native build with the whole series applied** (Linux x86-64, GCC 13):
  the official test suite gives the same status in all 402 groups as plain
  trunk r13248, with the same 24,522 tests and the same 10 failures. The
  failures are in the 5 groups above and in ProcessInvocation's
  TESTLOADLIBRARY, and plain trunk has them too. Assertion counts differ only
  in groups whose count depends on the environment (SysFileTree,
  SysSearchPath, REPLY). The CSVs of these runs (and of the `knownOSes`
  experiment) are attached.
- **Qualification scripts:** all pass: base runtime under Node, 14 Node CLI
  checks, 18 browser API cases in headless Chromium. Each intermediate patch
  of the series builds and passes the checks that exist at that point.
- **Browsers:** tested in headless Chromium, including the playground page
  at desktop and mobile sizes. Firefox and Safari have not been tested yet.
  The browser runtime needs a cross-origin isolated page (COOP/COEP
  headers), because threads need SharedArrayBuffer.

## The series

Apply in order on trunk r13248 (`svn patch` handles the git format,
including the executable bits).

| # | Patch | What |
|---|---|---|
| 1 | 0001-fix-internalcall-stack-check | Bug [#2093](https://sourceforge.net/p/oorexx/bugs/2093/): deep recursion through internal function calls segfaults instead of Error 11 |
| 2 | 0002-fix-userid-no-passwd-entry | Bug [#2094](https://sourceforge.net/p/oorexx/bugs/2094/): USERID() and the RexxAPI segfault when the uid has no passwd entry (containers) |
| 3 | 0003-fix-variablereference-setvaluerexx | Bug [#2095](https://sourceforge.net/p/oorexx/bugs/2095/): `VariableReference::setValueRexx` is a native method declared void (undefined behaviour; WebAssembly traps on it) |
| 4 | 0004-fix-sysfileiterator-no-fnm-casefold | Bug [#2096](https://sourceforge.net/p/oorexx/bugs/2096/): SysFileIterator without FNM_CASEFOLD breaks case-sensitive searches and frees a `readdir()` name |
| 5 | 0005-wasm-build-and-base-runtime | Build (`wasm/build-wasm.sh`, CMake cache for Emscripten 6.0.9), static rexx/rexxapi, interpreter on a pthread, native stack probe for Error 11, in-process RexxAPI, embedded extensions, the process' own passwd entry (getpwnam/getpwuid wrapped), RxSock over WebSockets |
| 6 | 0006-wasm-node-commands-rexxc-errno | Node CLI build (`wasm/build-node.sh`): host files and environment, ADDRESS commands as host processes, rexxc, Linux errno values for Rexx programs |
| 7 | 0007-wasm-node-rxapi-daemon | RexxAPI daemon shared between Node processes; rxqueue, rxsubcom; real process ids |
| 8 | 0008-wasm-node-real-sockets | Real TCP/UDP sockets and name resolution for RxSock under Node |
| 9 | 0009-wasm-web-runtime | Browser runtime for web pages (`wasm/build-web.sh`, `wasm/web/ooRexx.js`) |

Patches 1–4 fix bugs that also affect native builds. Each one has its own
ticket, so they can be judged (and committed) on their own. Each was run
through the native test suite alone on r13248, and the four together: the
same status in all 402 groups as plain trunk. Patches 5–9 assume them. Most
of these bugs were found while porting, and number 1 is fatal under
WebAssembly much sooner than natively.

New files are under `wasm/` (build scripts, JavaScript glue, tests and
README) and `cmake/wasm-emscripten-6.0.9-cache.cmake`. Two more new files sit
in the RexxAPI tree: `rexxapi/common/platform/unix/SysLoopbackConnection.*`
(the in-process transport) and `SysNodeConnection.*` (the transport to the
Node daemon).

## Decisions for the committers

- **Trunk or a branch?** Everything is guarded, so the series could go to
  trunk without affecting other platforms. A branch (e.g.
  `branches/wasm`) would let it mature first. Either is fine with me.
- **Emscripten dependency.** The build is qualified with Emscripten 6.0.9;
  the CMake cache records the capabilities of its libc so configure does not
  have to probe them. Should the project pin a version (and bump it
  deliberately), or follow Emscripten releases? Four Emscripten bugs are
  worked around in the series.
- **Layout.** Is a top-level `wasm/` directory acceptable? It holds the
  build scripts, the JavaScript glue, the browser API, tests and docs. Or
  should these go elsewhere (`platform/wasm`, `extensions/…`)?
- **Testing.** Should the test framework know EMSCRIPTEN (as UNIX, so
  the UNIX-only groups run)? Should the WASM build run the official test
  suite as part of the release process, and go into CI?
- **Distribution.** Would the project publish WASM builds (a Node package,
  files for web pages), or only the sources?

## Known limitations

- No ncurses (no terminal in the browser; the Node CLI could get it later).
- rxunixsys is embedded, but some of its functions do not work under
  Emscripten: the group database, services, crypt, and SysStat on special
  files.
- In the browser there are no processes: ADDRESS commands fail closed (RC
  127). Sockets there are WebSockets (Emscripten's emulation): client only,
  so a TCP server needs a WebSocket-facing endpoint.
- Recursion depth is limited by the JavaScript engine's native stack. Under
  Node: about 9,700 levels of internal CALL, 7,100 of function calls, 5,400
  of method calls. In a browser worker about 700. Beyond that, Error 11.
- Native API extensions (`.so` libraries) cannot be loaded. The port
  avoids Emscripten's dynamic linking together with threads, so extensions
  have to be linked in, as the bundled ones are.
- Threads plus growable memory carry an Emscripten performance warning.
  This is a correctness-first configuration, not a tuned one.

## Provenance

The port started from Tom Dyer's (Alchemy) "dev1" patch, posted to
oorexx-devel on 25/09/2026:
<https://sourceforge.net/p/oorexx/mailman/message/59399062/>

On the list, Tom confirmed that all his submissions to ooRexx are provided
under the Common Public License 1.0:
<https://sourceforge.net/p/oorexx/mailman/message/59407162/>

Most of dev1's code is still in the series, mostly in patch 5. The rest of
the work is mine, contributed under the CPL 1.0 like the rest of ooRexx. All
new files carry the standard RexxLA CPL header.
