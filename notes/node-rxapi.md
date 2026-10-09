# RexxAPI shared between Node processes: the WASM rxapi daemon

*Written 04/10/2026; describes patch 0003 of the current series
(`patches/0003-wasm-node-rxapi-daemon.patch`).*

Only `__EMSCRIPTEN__` code paths change.

## Problem

With the base runtime (patch 0001) every WASM process has its own API server
linked in (`SysLoopbackConnection`). Native ooRexx processes share queues,
registrations and the macrospace through the rxapi daemon, and a child
process finds its parent's session queue through `RXQUEUESESSION`, which is a
*server handle*. With one server per process, `cmd | rxqueue`, `rexx` children
reading the parent's queue, external subcom registrations (rxsubcom) and the
macrospace seen by another interpreter could not work.

## Design: the native model, with a Node transport

- **Daemon** = the same `rexx.js`, started as `node rexx.js --orx-wasm-rxapi`
  (dispatched in `rexx.cpp`, `orxWasmRxapiMain()` in
  `rexxapi/common/platform/unix/SysNodeConnection.cpp`). It runs the
  unchanged `APIServer` (`initServer` + `listenForConnections`, one
  `APIServerThread` per connection), exactly like native rxapi's `main`.
- **Transport**: Unix domain socket `<dir>/.ooRexx-5.3.0-wasm-<user>.service`
  (dir = XDG_RUNTIME_DIR, else TMPDIR, else /tmp, as native; the `-wasm` part
  keeps it apart from a native rxapi — handles are 32-bit pointers of the
  daemon's memory). Computed in JS from the host environment, so the MEMFS
  and NODERAWFS builds use the same daemon.
- **Blocking I/O from pthreads**: Node's `net` is asynchronous and lives on
  the JS main thread, which is idle (PROXY_TO_PTHREAD). The node socket
  objects are only ever touched on the main thread. Connect, listen, accept
  and close are proxied to it with `emscripten_proxy_sync_with_ctx()`; the JS
  side completes the operation from socket events and calls
  `orxNetFinish(ctx)`, releasing the blocked thread. Reads and writes avoid
  the proxy (see "Fast path" below). `read()` blocks like `recv()`, and a
  blocking PULL in the daemon only blocks its connection's thread. On the
  main thread itself (exit-time destructor) only close is possible, done
  synchronously.
- **Client** (`SysLocalAPIManager`): under Node, `newClientConnection()`
  connects to the daemon; if that fails, the normal
  `establishServerConnection()` logic calls `startServerProcess()`, which now
  spawns the daemon detached (`child_process.spawn(process.execPath,
  [scriptDirectory + 'rexx.js', '--orx-wasm-rxapi'], {detached, stdio
  ignore, cwd '/'})` + `unref`) and retries (500 × 10 ms in WASM, 200
  natively). Cold start including the daemon: ~0.7 s; warm: as before.
- **Single daemon**: the daemon first probes the socket (someone answering →
  exit 0), then takes `<service>.lock` (O_EXCL, holding its pid). A lock is
  stale if its pid is dead, **a zombie** (kill(pid, 0) succeeds on zombies:
  in containers whose pid 1 reaps late, this first made every new daemon
  retire), or older than 10 s with nobody listening. Socket mode 0600.
- **Lifetime**: the daemon stays resident, like native rxapi; there is no
  idle exit. It does exit if its socket file disappears or is replaced
  (checked every 30 s), instead of lingering unreachable.
- **Fallbacks** to the in-process server (unshared): browser (no
  `process`/`require`), `ORX_WASM_RXAPI=inprocess`, daemon cannot be
  launched, or not reachable after the retries.
- **`getpid()`**: Emscripten returns the constant 42 (getppid 41). The server
  keys sessions by pid, so all WASM processes would have been one session.
  `__syscall_getpid`/`__syscall_getppid` (weak in libc) are overridden in
  `SysProcess.cpp` with `process.pid`/`process.ppid` under Node. Also makes
  `SysQueryProcess('PID')` real.
- **rxqueue / rxsubcom** are multi-call tools in rexx.wasm like rexxc
  (`wasm/rxqueue-main.cpp`, `wasm/rxsubcom-main.cpp`, launchers written by
  `wasm/build-node.sh`). `rexx.cpp` dispatches `--orx-wasm-<tool>`.
- **Debugging**: `ORX_WASM_RXAPI_DEBUG=1` traces connect/listen/start/
  fallback to stderr; the daemon started in that mode appends its trace to
  `$TMPDIR/orx-wasm-rxapi-debug.log`.

## Fast path for reads and writes

A first version proxied every `ApiConnection` operation, reads and writes
included, to the JS main thread. That costs a postMessage wakeup per
operation, and a request/reply needs at least four (client write + read,
daemon read + write): ~0.45 ms per API call. The current design:

- **Writes** go straight from the calling pthread: connect/accept report
  the socket's host fd (`sock._handle.fd`) and `write()` calls
  `fs.writeSync(fd, ...)` in an EM_JS on that thread (EAGAIN → 0.2 ms nap and
  retry). The main thread only ever reads the socket, so nothing interleaves.
- **Reads** use a per-connection receive ring (`NodeRing`, 64 KiB, allocated
  by C and handed over in the connect/accept operation): the main thread's
  `data` handler copies into it (single producer), bumps `seq` and
  `Atomics.notify`s; `read()` (single consumer) copies out without any proxy
  and sleeps with `emscripten_futex_wait(&seq)` when empty. If the ring is
  full the rest stays in JS (`PENDING`) and the reader asks for a refill
  (`OP_PUMP`, the only proxied data operation, large messages only).
  `CLOSED` = end of file. Data buffered before accept is pumped on attach.

## Pitfall found: EM_JS drops backslashes

The zombie test was first a regex `/^\d+ \(.*\) Z/`; in the generated JS it
became `/^d+ (.*) Z/` — EM_JS bodies lose backslashes. No escapes in EM_JS
code (the zombie check now uses `lastIndexOf(')')`).

## Results

- Parent/child session queue, `cmd | rxqueue` (FIFO, /lifo, named queues),
  named queues persisting across separate invocations: OK.
- 8 threads × 100 QUEUE + 800 PULL: correct (sum 3600) with the daemon.
  With the first, fully proxied transport this took ~0.75 s vs ~0.15 s with
  the in-process server.
- Per-call cost on the development VM (3000-call loops; native rxapi for
  reference), fully proxied → fast path: queue 440 → 175 µs (native 75),
  pull 360 → 135 (native 75), queued 250 → 128 (native 63).
  `seq 1 20000 | rxqueue` + `queued()`: 6.7 s → 3.5 s (native 1.0 s; ~0.5 s
  of it is two Node startups).
- Fast-path checks: messages of 1000 B … 2 MB both ways (ring boundary
  65535/65536/70000 and the PENDING path), 8 threads × 100 QUEUE + 800 PULL
  = 3600, `tests/qualify.sh` 33/33, full suite.
- Suite groups rxQueue, rxsubcom, RexxQueue, Macrospace, QUEUED, RXQUEUE,
  RexxContext, ASSIGNMENT, NUMERIC, rexx_command, rexxc: all ok. Current
  results: `results/suite-wasm-r13263-series.csv`.
- Browser probes unchanged (in-process server).
