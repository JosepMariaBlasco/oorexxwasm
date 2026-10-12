# RFE #879 update, 12 October 2026: the JavaScript bridge is now patch 7 of the RFE

## What changed

The RFE now has seven patches. The new **patch 7** (`[PATCH 7/7]`) is
`.JSObject`: JavaScript objects used from Rexx with ordinary messages, in the
browser build and in the Node command-line build. It is specified in
[`docs/ooRexx-WASM-and-JavaScript.md`](../../docs/ooRexx-WASM-and-JavaScript.md).
That document is the living version of the one posted to the developers'
list on 8 October, and its last section lists what has changed since then.

Until now this code was patch 0008. It came after JDOR and was not part of
the RFE. It has been moved before JDOR and no longer needs it.

Patch 7 contains:

- **`.js` and `.JSObject`.** JavaScript's objects, functions, arrays and
  Promises are Rexx objects. In the browser there are two realms: `.js`,
  the Web Worker that runs the interpreter, and `.js~page`, the page with
  its DOM. The page must grant each one. Under Node `.js` is Node's realm.
- **Handlers.** `.js~handler(object, message [, options])`. Where
  JavaScript can wait (the worker, Node), a handler is synchronous, as
  `.net~handler` is in ooRexx/.NET. In the page it is queued, and
  `.js~eventLoop` or `.js~nextEvent` take the calls.
- **Rexx objects in JavaScript.** Any other Rexx object goes to JavaScript
  as a `RexxProxy`, with BSF4ooRexx's `sendMessage` names, and keeps its
  identity both ways.
- **Rexx classes extending JavaScript classes.** `.js~extend(class, base)`
  makes a JavaScript class whose methods call the Rexx class's, as
  `.net~extend` does.
- **Rexx from the page.** A call from the page gives a Promise of the
  result. `ooRexx.js` adds sessions (`rexx.start()`, with `eval`,
  `routine` and `loadPackage`) and `<script type="text/rexx">`.
- **Outside `wasm/`**, a single change: `PackageManager.cpp` gets a hook
  for the packages a WASM build links in, `orx_wasm_extra_packages()`. It
  is a weak symbol, NULL in every other build, and `wasm/extra-packages.cpp`
  defines it.

**Patches 1–6** are unchanged. Only the subject differs, which now says
`n/7`.

The patches apply cleanly to trunk **r13268**, in order, with `svn patch`
or `git apply`. Patches 1–7 alone build and pass their tests.

## The rest of the series

The repository has four more patches. They are not part of the RFE:

- **0008, 0010 and 0011** are example command environments built on
  patches 1–7: `ADDRESS JDOR` (Rony G. Flatscher's JDOR drawing commands on
  the browser's canvas), `ADDRESS FETCH` (HTTP) and `ADDRESS DOM` (the
  page).
- **0009**, `cmdhandler`, lets command environments be written in Rexx.
  It is a portable package, not specific to WebAssembly, and it is not in
  trunk. 0010 and 0011 depend on it. It is a separate matter.

## The patches

[`patches/` at commit 30b1ce3](https://github.com/JosepMariaBlasco/oorexxwasm/tree/30b1ce3/patches):
0001–0007 are the RFE, and `SHA256SUMS` lists their hashes.

## Results on r13268

The official test suite, test/trunk r13268, ran on GitHub's runners with
the whole series applied. Under WebAssembly it ran on the variants with the
test libraries:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 400 | 24,283 | 2 | 0 |
| Node.js command line | 399 | 24,231 | 5 | 0 |
| Chromium | 371 | 24,223 | 159 | 73 |
| Firefox | 371 | 24,223 | 158 | 73 |
| WebKit | 372 | 24,223 | 158 | 73 |

There were no crashes and no timeouts on any platform. Every group that
does not pass everywhere has a known cause, listed group by group in
[`results/suite-platforms.md`](results/suite-platforms.md). The causes are
the same as on 11 October:

- Under Node, CHAROUT and LINEOUT fail natively too, and File fails three
  tests on file times. RexxContext and TRACE, which depend on timing,
  passed this time.
- In the browsers, nearly all of it comes from one cause: a browser cannot
  start processes. 28 of the 31 failing groups (148 of the 159 failures,
  and all 73 errors) run a command, which gets RC 127. Some run ooRexx's
  own tools as commands: `rexx`, `rexxc`, `rxqueue`, `rxsubcom`,
  `rexxinstance`, and the samples, each run as a `rexx` process. Others
  run shell commands (`cd`, `cat`, `id -u`, `echo ... >`). The other three
  groups:
  - `socketClass` (9 failures): a page cannot listen on a port, and the
    WebSocket transport has no socket options. The client tests pass.
  - CALL (1 failure, `TEST_STACKSIZE`): the recursion depth is bounded by
    the JavaScript engine's native stack in a worker.
  - RexxInfo (1 failure): there is no `rexx` executable file to give.

  LINEOUT, which fails natively and under Node, passes in the browsers.

The tests of `.JSObject` itself all passed:

- `wasm/tests/web-api.py`: 63 cases in each of Chromium, Firefox and
  WebKit. They include `js-proxy.rex` (RexxProxy, 28 checks) and
  `js-extend.rex` (`.js~extend`, 31 checks) run in the worker.
- `wasm/tests/qualify-node-cli.sh`: 25 checks under Node, among them
  `js-proxy.rex` and `js-extend.rex` again.
- With patches 1–7 alone, `qualify-node-cli.sh` has 23 checks and
  `web-api.py` 49 cases. The rest belong to the example environments.

## Files

- [`results/suite-platforms.md`](results/suite-platforms.md): the
  side-by-side table, with the cause of every group that does not pass
  everywhere (also as [CSV](results/suite-platforms.csv)). The causes come
  from [`tests/suite-browser/known.tsv`](../../tests/suite-browser/known.tsv).
- The results of each platform as CSV:
  [native](results/suite-native.csv), [Node](results/suite-node.csv),
  [Chromium](results/suite-chromium.csv), [Firefox](results/suite-firefox.csv),
  [WebKit](results/suite-webkit.csv).
