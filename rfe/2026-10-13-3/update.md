# RFE #879 update, 13 October 2026 (3): the RexxAPI no longer needs the JavaScript main thread

## What changed

**Patch 3** (the RexxAPI daemon under Node) changed, and **patch 7**
(`.JSObject`) changed by a few lines.

Under Node, the WASM processes share the RexxAPI through a daemon, as native
processes share `rxapi`. Node's sockets are asynchronous, and their data
arrives through an event loop. Until now the connections to the daemon lived
on the JavaScript main thread, which was supposed to be idle, since the
interpreter runs on other threads.

It is not always idle. When JavaScript calls a Rexx method synchronously and
waits for its result (a `.JSObject` handler used as a comparator for `sort`,
or an override of a class made by `.js~extend`), the main thread waits for
the Rexx thread, and its event loop does not run. Waiting for the daemon
then hung, because its reply could not arrive:

- **always**, if the method itself used the RexxAPI: a queue, or any
  external function such as `SysSleep`, because looking up an external
  function first asks the daemon for a macrospace function with that name;
- **sometimes**, if another Rexx thread was waiting for the daemon at that
  moment while holding the interpreter's kernel lock (the macrospace lookup
  is made that way), because the method needed the lock to run.

The connections now live on an I/O thread of their own: a thread that
stays in its own event loop, whatever the main thread is doing. The
operations go to it instead of to the main thread. Reads and writes still
avoid any round trip, as before, and the cost per call is the same (about
70–150 µs for a `QUEUE`, a `PULL`, `QUEUED()` or `SysSleep`).

Starting a thread takes the main thread, so the I/O thread is started while
the main thread is free: at the first RexxAPI operation, and, before that,
at the JavaScript bridge's first request. That request cannot come from a
synchronous handler. **Patch 7** adds this call, the new check (below) and
a few words in `wasm/README.md`.

The daemon still goes away when its socket file disappears. It now ends
itself with a `SIGTERM`, because `process.exit()` on the I/O thread would end
only that thread.

The specification says so in
[*Waiting*](../../docs/ooRexx-WASM-and-JavaScript.md#waiting), with a row in
its table of changes. [`notes/node-rxapi.md`](../../notes/node-rxapi.md)
describes the I/O thread and how the hang was found: with the stacks of all
the threads, taken through Node's inspector.

## Tests

A new check in `qualify-node-cli.sh` sorts a JavaScript array with a Rexx
comparator that uses a queue and calls `SysSleep`. It then sorts 200 more
arrays while another Rexx thread uses the queue and calls `SysSleep` in a
loop. Before the change, it hung at the first sort. The script now has 30
checks, 28 with patches 1–8 alone.

The four-thread stress test of `.js~extend` that found the hang hung in
about two runs out of three. It passed 6 runs out of 6 with the change.

On Windows, where the daemon listens on a named pipe, the same program
passes on GitHub's `windows-latest` runner, from the installed npm package.

**Patches 1 and 2** are byte-identical, and **4–6 and 8** differ only in
their line numbers, except that in patch 8 two lines of the daemon code use
the I/O thread's way of loading Node modules. The patches apply cleanly to
trunk **r13268**, in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass their tests:
`qualify-node-cli.sh` 28 checks, and `web-api.py` 49 cases. The API test
groups pass too, with the whole series: 796 tests, no failures.

## The patches

[`patches/` at commit c223fb4](https://github.com/JosepMariaBlasco/oorexxwasm/tree/c223fb4/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes. The example
environments 0009–0012 only moved down by a few lines.

## Results on r13268

The official test suite, test/trunk r13268, ran on GitHub's runners with the
whole series applied:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 400 | 24,283 | 2 | 0 |
| Node.js command line (Linux) | 399 | 24,231 | 5 | 0 |
| Chromium | 371 | 24,223 | 159 | 73 |
| Firefox | 371 | 24,223 | 158 | 73 |
| WebKit | 371 | 24,223 | 157 | 73 |

These are the results of the previous update, except for two groups whose
results vary from run to run:

- In the browsers, the File group fails 3 or 4 tests. MEMFS keeps file times
  in whole milliseconds, and one of the tests passes by chance now and then.
- In WebKit, the CALL group's stack depth test depends on the engine build.

There were no crashes.

**Windows.** Patch 3 changes the daemon's transport on Windows too, where
it listens on a named pipe, so the suite also ran there: the Node variant on
`windows-latest`, compared with the reference of the morning's update.

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| Node.js command line (Windows) | 388 | 24,231 | 38 | 0 |

There were no regressions. The reference has 389 groups ok and 35 failures.
The difference is in two groups whose results vary from run to run: File
(12 failures this time, 10 in the reference) and TRACE (1 failure). In a
first run, SysSleep failed one test instead: a sleep of 3 seconds, with
three others at the same time, took 3.0269 seconds against a limit of
3.026. Two more runs of that group passed, and so did this full run. The
same measurement under Linux is no different before and after the change.

## Files

- [`results/suite-platforms.md`](results/suite-platforms.md): the
  platforms side by side (also as [CSV](results/suite-platforms.csv)), with
  the cause of every difference.
- The results of each platform as CSV:
  [native](results/suite-native.csv), [Node](results/suite-node.csv),
  [Windows](results/suite-windows.csv), [Chromium](results/suite-chromium.csv),
  [Firefox](results/suite-firefox.csv), [WebKit](results/suite-webkit.csv).
