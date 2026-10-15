# ooRexx for WebAssembly: the browser files

The ooRexx interpreter (ooRexx 5.3.0, SVN trunk with the ooRexx/WASM patches)
compiled to WebAssembly, for web pages. An experimental port, not an official
RexxLA distribution. Project: https://github.com/JosepMariaBlasco/oorexxwasm

## Try it

With Node.js 18 or later:

```
node serve.mjs
```

and open http://localhost:8000/ : `index.html` is an example page whose
`<script type="text/rexx">` elements set the page's text, handle a button's
clicks, and define a routine that the page's JavaScript calls.

Opening `index.html` as a file does not work: see *Serving* below.

## Files

| File | |
|---|---|
| `ooRexx.js` | what a page loads (`<script src="ooRexx.js">`); finds the others next to it |
| `ooRexx-worker.js` | the Web Worker that runs the interpreter (one per run) |
| `rexx.js`, `rexx.wasm` | the interpreter |
| `rexx.data` | the ooRexx image and the extension classes (`js.cls`, `rxsock.cls`, …) |
| `js-realm.js` | the page's side of `.JSObject` (`.js~page`) |
| `polygon-clipping.umd.min.js` | used by `ADDRESS JDOR` (MIT license, in the file) |
| `index.html`, `app.rex` | the example page |
| `serve.mjs` | a small web server for local use, with the headers below |
| `ooRexx-debugger.js`, `debugger/` | the debugger for the page's Rexx scripts (optional; see *Debugging*) |

Copy the first seven files, together, to your site, and load `ooRexx.js` from
your pages.

## Using it in a page

```html
<script src="ooRexx.js"></script>
<script type="text/rexx">
  .js~page~document~getElementById("greeting")~textContent = "Hello from Rexx"
</script>
<script type="text/rexx" src="app.rex"></script>
```

Or from JavaScript:

```js
const rexx = await ooRexx.load();
const run = rexx.run({ args: ['prog.rex'], files: { '/home/rexx/prog.rex': source },
                       onOut: (text) => console.log(text) });
const { rc } = await run.done;
```

`ooRexx.js` describes `run()` and sessions (`rexx.start()`) in its first
comment. Rexx reaches JavaScript and the page through `.JSObject`, specified
in *ooRexx/WASM and JavaScript*:
https://github.com/JosepMariaBlasco/oorexxwasm/blob/main/docs/ooRexx-WASM-and-JavaScript.md

## Debugging

Open the page with `?rexx-debug=1` at the end of its address
(`http://localhost:8000/?rexx-debug=1`) and `ooRexx.js` loads
`ooRexx-debugger.js`, which must be next to it, with the `debugger/`
directory. A panel at the foot of the page shows the page's Rexx scripts:
click a line number to set a breakpoint, and the scripts, or the handlers
they set up, stop when they get there. Then **Step** (F10), **Run** (F8), the
stack, the variables, and a field for Rexx run where the program is paused
(`say` there shows in the panel). **Break** stops at the next clause that
runs. Breakpoints are remembered for the page, so a reload stops in the
scripts' first run. While debugging, the scripts run slower, and standard
input is the debugger's. Without `rexx-debug=1` the debugger is not loaded
at all; leave its files out of a site that does not need them.

The debugger is Dom Wise's ooRexx debugger
(https://sourceforge.net/p/oorexxdebugger/, MIT license, in
`debugger/LICENSE`), with a front end for web pages.

## Serving

The interpreter uses threads, which browsers allow only in a cross-origin
isolated page. Every page that loads `ooRexx.js` must be served with

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

and `rexx.wasm` as `application/wasm`. With these headers, everything the page
loads (scripts, images, fonts) must come from the same site, or be sent with
`Cross-Origin-Resource-Policy: cross-origin` (or CORS) by its own server.

- **Locally:** `node serve.mjs [DIR] [--port N]`.
- **Apache:** the `.htaccess` file here (needs `mod_headers`).
- **Other servers:** see `INSTALL.md` in the project.

Current Chrome, Edge, Firefox and Safari all work.

## Licenses

The interpreter files (`ooRexx.js`, `ooRexx-worker.js`, `rexx.js`,
`rexx.wasm`, `rexx.data`, `js-realm.js`) are ooRexx, under the Common Public
License 1.0 (`CPLv1.0.txt`). `polygon-clipping.umd.min.js` is under the MIT
license (in the file). `index.html`, `app.rex`, `serve.mjs` and this README
are under the Apache License 2.0 (`LICENSE-Apache-2.0.txt`).
