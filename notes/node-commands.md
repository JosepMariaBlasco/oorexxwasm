# External commands under Node

*Written 04/10/2026; describes patch 0002 of the current series
(`patches/0002-wasm-node-commands-rexxc-errno.patch`).*

The changes described here are part of patch 0002 (the stdin
`LINES()`/`CHARS()` and `rexxtry` parts of that patch are not covered in this
note). A native build of the same tree compiles and gives the same results as
before on the affected test groups (ADDRESS, OPTIONS, STREAM, Stream,
SysFileXXX, RexxInfo, rexxc).

## 1. Commands: `child_process.spawnSync` on the interpreter thread

`ioCommandHandler` (`interpreter/platform/unix/SystemCommands.cpp`) builds
`argv` exactly as natively (`/bin/sh -c cmd` for SH/""/COMMAND/SYSTEM,
`/bin/<name> -c` for KSH/BASH/…, word-split argv for PATH) and then, under
`__EMSCRIPTEN__`, calls `wasmCommandHandler()` instead of
`posix_spawnp`/pipes/`waitpid`:

- `wasmCommandRun` (EM_JS) runs `spawnSync` **on the calling thread**. With
  PROXY_TO_PTHREAD every Rexx thread is a Node worker, where blocking is
  legal: no proxying to the main thread, concurrent commands from several
  Rexx threads really run in parallel (6 × `sleep 0.3` in 0.7 s), the JS main
  thread stays free. `require` is available in the workers (CommonJS output).
- No redirection: `stdio: 'inherit'` (real fds 0/1/2). Ordering with SAY is
  preserved, to a terminal, a file and a pipe (SAY writes are synchronous
  fd writes, proxied to the main thread before the child starts).
- ADDRESS … WITH: INPUT is passed as `options.input` (buffer from
  `ReadInputBuffer`), OUTPUT/ERROR collected as buffers and handed to
  `WriteOutputBuffer`/`WriteErrorBuffer`. The buffers stay in a per-thread JS
  global between the run call and two small copy calls (C mallocs, JS copies),
  so no `_malloc` from JS is needed. `maxBuffer` 2 GB.
- OUTPUT and ERROR to the same target (interleaved): spawnSync cannot share
  one pipe for both, so the command is wrapped as
  `/bin/sh -c 'exec 2>&1; exec "$0" "$@"' argv...` — argv preserved exactly.
- Environment: the interpreter's `environ` (so `SET`/`EXPORT`/`VALUE(,,'ENVIRONMENT')`
  reach children). If PATH is still Emscripten's default `/` (MEMFS build,
  which does not import the host environment), the host PATH is used.
- Current directory: `getcwd()` (proxied: the FS lives on the main thread)
  if it exists on the host — always with NODERAWFS; with MEMFS the virtual
  cwd may happen to exist on the host (`/`), otherwise Node's cwd.
- Result mapping identical to native: 127 → FAILURE, other non-zero → ERROR,
  signal → RC −signo. Spawn errors (ENOENT for ADDRESS PATH, and synchronous
  throws such as an empty command name — `address path ''` used to kill the
  runtime) → 127 → FAILURE, like a failing `posix_spawnp`.
- `cd`/`set`/`unset`/`export` still handled in-process (only without
  redirection, as natively).
- Browser: `process`/`require` absent → FAILURE RC 127, as before.

## 2. `rexxc` multi-call

`wasm/rexxc-main.cpp` compiles `RexxCompiler.cpp` into `rexx_exe` with
`main` renamed; `rexx.cpp` dispatches when `argv[1]` is `--orx-wasm-rexxc`.
`wasm/build-node.sh` writes a `rexxc` launcher next to `rexx`. No second
1 MB wasm. Compiled programs run with `rexx`; error exits match native.

## 3. `.RexxInfo~executable` / `~libraryPath`

Were `node` and .nil: `/proc/self/exe` is the node binary and there is no
`dladdr`. Now (`common/platform/unix/SysProcess.cpp`) both come from
Emscripten's `scriptDirectory` (directory of `rexx.js`, Node only):
executable = `<dir>/rexx` (the launcher), libraryPath = `<dir>/`, each only if
the WASM file system can see it (NODERAWFS yes; MEMFS and browser → .nil).
`loadImage()` now finds `rexx.img` there first. This mattered beyond
RexxInfo: the test framework runs child Rexx programs with
`.RexxInfo~executable`, so with `node` it ran `node prog.rex` (CHAROUT,
Stream, samples…).

## 4. errno numbering (WASI vs Linux)

Emscripten's libc uses WASI error numbers (ENOENT = 44, EACCES = 2, …).
Rexx programs saw them: `cd /nonexist` RC 44, stream `ERROR:44`. Now
`SysProcess::hostErrno()` maps WASI → Linux (table generated from
Emscripten's `bits/errno.h` and Linux values) and `localErrno()` the reverse.
Applied only where a number reaches Rexx, not inside the file-system code
(which compares with E-constants): RC of CD; stream `ERROR:n`/`NOTREADY:n`
descriptions/results (`strerror` still gets the raw value); SysMkDir,
SysRmDir, SysFileDelete, SysFileCopy, SysFileMove, SysSetPriority return
values; SysGetErrortext(n) maps back. Common code uses a `HOST_ERRNO()` macro
(unix and windows `SysFile.hpp`; identity except under Emscripten).

## 5. Build: samples support files

`wasm/build-wasm.sh` built only `rexx_exe`; the build tree's `samples/` had
the .rex but not `complex.cls`, `pipe.cls`, `jabberwocky.txt`… Now it also
builds `class_files`. `scripts/save-build.sh` saves `samples/` and `rexxc`;
`scripts/setup-env.sh` installs `samples/`.

## 6. Official test suite (test/trunk r13195), Node CLI

Measured when this part of the port was written (an earlier version of the
series, on top of trunk r13195):

| run | groups ok/fail/crash | tests | failures | errors |
|---|---|---|---|---|
| native | 397 / 5 / 0 | 24,512 | 9 | 0 |
| WASM, before Node commands | 364 / 38 / 0 | 23,656 | 86 | 81 |
| WASM, with Node commands | 379 / 23 / 0 | 23,664 | 28 | 16 |

Current results for the whole series are in
`results/suite-wasm-r13263-series.csv`.

Fixed by these changes: ADDRESS (23 F), samples (29 F), rexx_command (28 E),
rexxc (8 E), OPTIONS, STREAM, Stream (8 E → native's 1 F), Method, Routine,
RexxInfo, ARG, CONDITION, LINEIN, PARSE, SIGNAL, environmentEntries,
incorrectCharacters, RESULT_RC_SIGL, bug2003_guard_when, SysSleep.

The 23 groups that still failed at that point:

| cause | groups |
|---|---|
| native API test libraries (no dlopen) | API/classic, API/oo × 7 |
| same as native (running as root / redirection) | CHAROUT, LINEOUT, File, Stream, SysFileXXX (WASM fails fewer than native in File and SysFileXXX) |
| no RexxAPI shared between processes (in-process server per process) | rxQueue (8 E), rxsubcom (7 F), RexxQueue TEST_EXTERNAL, Macrospace TEST_ADD_OTHER_INTERPRETER |
| listening sockets (SockListen EOPNOTSUPP) | socketClass (9 F), samples/scclient, scserver, sfclient, sfserver — the last four were "ok" before only because the sample was never launched |
| timing-flaky (also native under load) | TRACE |

The RexxAPI groups are addressed by patch 0003 (see `node-rxapi.md`) and
the socket groups by patch 0004 (see `node-sockets.md`).

## 7. Minor native observation

`handleCommandInternally(..., RexxObjectPtr rc)` takes `rc` by value, so
`rc = context->False()` in `sys_process_cd`/`sys_process_export` is lost and
the handler returns NULLOBJECT (RC 0 anyway). Harmless; possible upstream
cleanup.
