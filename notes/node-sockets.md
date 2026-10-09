# Real sockets under Node

*Written 04/10/2026; describes patch 0004 of the current series
(`patches/0004-wasm-node-real-sockets.patch`).*

Files: `extensions/rxsock/rxsockfn.cpp`, `wasm/node-sockets-pre.js` (new),
`wasm/emscripten-dns-proxy.js`, `CMakeLists.txt`, `wasm/build-node.sh`,
`wasm/README.md`, `wasm/tests/qualify-node-cli.sh`. `wasm/build-node.sh`
links the Node CLI (`bin-node`) with real sockets.

## Starting point

`SockListen` failed with EOPNOTSUPP under Node. In fact every socket under
Node was emulated over WebSocket (Emscripten SOCKFS + the port's client-only
`ws` shim): `connect()` to host:port opened `ws://host:port`, so a Node
`rexx` could only talk to WebSocket servers, never listen, and
`getsockopt`/`setsockopt` knew only SO_ERROR. Suite: socketClass
(9 failures) and samples scclient/scserver/sfclient/sfserver failed.

## Design: real TCP/UDP in the Node CLI, WebSocket stays in the browser

Emscripten 6.0.9 ships `-sNODERAWSOCKETS` (`src/lib/libsockfs_node.js`):
TCP (client, bind/listen/accept) and UDP over `node:net`/`node:dgram`,
including getsockopt/setsockopt and shutdown, behind the same SOCKFS
`sock_ops` contract. It can only be linked for `-sENVIRONMENT=node` (it throws
otherwise), so:

- `bin-node` (Node CLI, NODERAWFS, what the suite runs): **real sockets**.
  Interoperates with any TCP/UDP peer (native programs, Python, other WASM
  processes). The `ws` shim is no longer installed there.
- `bin` (MEMFS build, node+web+worker): unchanged, WebSocket transport —
  required in the browser, and still what `wasm/tests/qualify-node.sh`
  exercises.

Threading: socket syscalls are proxied to the JS main thread (Emscripten
proxies all FS syscalls under pthreads), where the node handles and their
events live; the interpreter thread blocks in rxsock's polling loops while the
main event loop delivers readiness, exactly as with the WebSocket backend.
(The settings.js comment "every socket syscall runs on a single worker" does
not describe the generated code: `__syscall_*` are proxied with
`proxyToMainThread`.) Sockets can be used from any Rexx thread.

## What had to be added

1. **Blocking accept / recvfrom** (rxsockfn.cpp). Emscripten never blocks:
   `accept()` on a blocking socket returns EAGAIN at once (without this, the
   server's `s~accept` returned .nil, and socketClass hung waiting for it).
   New helper `wasmBlockingRetry(sock, deadline)` used by accept, recv and
   recvfrom: retries after EAGAIN on a blocking socket, stops on SO_ERROR,
   and honours **SO_RCVTIMEO** (ends with EWOULDBLOCK as natively; measured
   0.30 s for a 300 ms timeout). The old recv loop is folded into it.
2. **Socket options** (`wasm/node-sockets-pre.js`, a `--pre-js` wrapping
   `nodeSockOps.setsockopt/getsockopt` at preRun):
   - SO_RCVTIMEO/SO_SNDTIMEO: the backend silently dropped them and
     getsockopt failed (ENOPROTOOPT). Stored per socket. wasm32 musl uses
     the 64-bit-time option numbers 66/67 with
     `struct timeval {int64 tv_sec; int32 tv_usec; pad}` (tv_usec is
     32-bit: reading it as int64 picked up padding garbage); 20/21 also
     handled.
   - SO_DEBUG, SO_DONTROUTE, SO_OOBINLINE, SO_RCVLOWAT, SO_SNDLOWAT (Node
     cannot apply them) and SO_REUSEADDR (libuv forces it on at bind; the
     backend always reported 1): the value set is remembered and reported,
     with Linux defaults (0, lowat 1).
3. **Name resolution** (`orxNodeResolve` in `wasm/emscripten-dns-proxy.js`
   + wrappers in rxsockfn.cpp). Emscripten's DNS is a fake: names map to
   172.29.x.y, which the WebSocket backend maps back to the name for the URL.
   With node:net that breaks (`.inetaddress~new('localhost', ...)` → bind
   EINVAL, connect failure — the sc* samples), lookups never fail, there are
   no reverse names, and `gethostname()` is "emscripten". Now, in the Node
   CLI only, rxsock's `gethostbyname`, `gethostbyaddr`, `gethostname` are
   macro-redirected to `wasmGetHostByName` etc., which call
   `orxNodeResolve`: `dns.lookup` (all IPv4 addresses, /etc/hosts + system
   resolver), `dns.lookupService` (getnameinfo) for reverse,
   `os.hostname()`, and `os.networkInterfaces()` for `SockGetHostId`
   (getifaddrs is unavailable). Unknown names now fail (HOST_NOT_FOUND;
   `.inetaddress` raises 93.953 as natively). The JS function is
   `__proxy: 'sync'` + `__async: true` (PROXY_SYNC_ASYNC): it returns a
   promise on the main thread and the calling pthread blocks until it
   settles — no Asyncify needed, the event loop keeps running. Elsewhere
   (browser, MEMFS build) it returns -2 and the libc (fake) functions are
   used, which the WebSocket backend needs. The library is also linked
   into `rexximage` (whole-archive librexx contains rxsock).

## Results

- Official suite, Node CLI, when this patch was written (an earlier version
  of the series): **389/402 groups ok** (383 without it). socketClass 114
  assertions (as native), scserver/sfserver 9, scclient/sfclient 16 (as
  native). The 13 left = 8 API groups needing the native test libraries + 5
  that fail identically natively (running as root). SysSleep passed that
  run (timing-flaky). Current results:
  `results/suite-wasm-r13263-series.csv`.
- Interop probes (Node CLI): `.StreamSocket` GET against a Python HTTP
  server; 1 MiB echo through a WASM server thread (socket created in one Rexx
  thread, used in another); `SockSelect` on a listening socket (0 idle,
  1 with a pending client); UDP sendto/recvfrom with a Python peer; WASM
  server ↔ WASM client in separate processes (samples).
- Regression: `bin` (WebSocket) — `wasm/tests/qualify-node.sh` output
  identical to the previous reference run, `tests/probe-node.sh` and
  `tests/probe-browser.sh` (socket, streamsock over WebSocket) unchanged.
- Native build unaffected: all C changes are inside `#if defined(__EMSCRIPTEN__)`.

## Possible follow-ups

- Waiting is still a 1 ms poll (`usleep(1000)` between zero-time syscalls),
  as for recv/connect before. Fine for now; a readiness wait (block on the
  main thread's poll notification) would cut latency and idle CPU.
- SO_SNDTIMEO is stored but has nothing to act on: send never blocks
  (Node buffers; `writeBlocked` only gates POLLOUT).
- IPv6: the backend supports it, rxsock is IPv4-only (`sockaddr_in`).
- Upstream (Emscripten) candidates: SO_RCVTIMEO/SO_SNDTIMEO in the
  NODERAWSOCKETS backend; fake DNS kept under NODERAWSOCKETS (names should be
  resolved for real); settings.js threading comment.
