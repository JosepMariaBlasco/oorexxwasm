# Chromium: worker threads lost when a worker terminates its workers and is terminated right after

A minimal reproduction, in plain JavaScript, of a Chromium bug that the
browser build of ooRexx/WASM ran into (patch 0005 works around it, see
`wasm/web-pre.js` and `wasm/web/ooRexx.js`).

## What it does

Each round, the page starts a worker (`parent.js`). The parent creates a
shared `WebAssembly.Memory` (64 MiB, maximum 512 MiB) and four workers of its
own (`child.js`) that receive it and touch its pages. When the four are up,
the parent terminates them and tells the page, and the page terminates the
parent at once. That is the shape of a WebAssembly program with threads
ending in a worker: Emscripten's runtime terminates its pthread workers when
the program exits, and the page then terminates the worker that hosted it.

Every worker of every round has been terminated, so after the rounds
nothing should be left.

## Run it

```bash
python3 serve.py        # http://127.0.0.1:8000/, cross-origin isolated
```

Open http://127.0.0.1:8000/ in Chrome, leave 300 rounds and press **Run**,
then look at the tab's *Memory footprint* in Chrome's Task Manager
(Shift+Esc on Windows and Linux; *Window > Task Manager* on macOS). Reload
the page (or open a new tab), tick one of the two boxes and run again to
compare:

- *wait 50 ms before terminating the parent*;
- *the parent does not terminate its children* (terminating the parent ends
  them too).

Where `performance.measureUserAgentSpecificMemory()` is available, the page
also prints the memory it measures and how many dedicated workers it still
finds.

## What happens

Measured on Linux x86_64 with headless Chromium (Playwright's
`chrome-headless-shell`, HeadlessChrome 153.0.8010.12 and 156.0.8078.4),
counting the renderer process's `DedicatedWorker` threads in `/proc` and its
resident memory, a few seconds after the rounds:

| Rounds | Variant | Threads left | Renderer RSS |
|---|---|---|---|
| 300 | as described | 126 | 879 MB |
| 300 | wait 50 ms before terminating the parent | 0 | 125 MB |
| 300 | the parent does not terminate its children | 0 | 123 MB |
| 100 | as described | 43 | 830 MB |
| 100 | wait 50 ms | 0 | 120 MB |
| 100 | children not terminated by the parent | 0 | 118 MB |

The lost threads sleep in a futex, use no CPU and keep their memory (in
ooRexx/WASM they were still there 30 s later and after a forced garbage
collection). In
ooRexx/WASM, where each run is such a round with a larger program, a page
lost 2–3 threads and ~18 MB per run: after ~190 runs in one page every new
run failed with `RangeError: WebAssembly.Memory(): could not allocate
memory`, and long sequences of runs sometimes crashed the renderer
(`SEGV_ACCERR` in V8, a heap word holding text where a compressed pointer
was expected).

Firefox 157 and WebKit 27.2 (Playwright 1.64) lose nothing, in this
reproduction or in ooRexx/WASM.

## Notes

- A `setTimeout(..., 0)` in the parent between terminating its children and
  telling the page does not help; some time must pass (50 ms was enough
  here, 10 ms nearly always).
- Children blocked in `Atomics.wait` instead of idle are lost too; some of
  them are reclaimed after a few seconds.
- A worker blocked in a WebAssembly `memory.atomic.wait32`, terminated by its
  parent, is reclaimed at once.
