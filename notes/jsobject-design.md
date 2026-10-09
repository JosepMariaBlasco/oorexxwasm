# `.JSObject`: a JavaScript bridge for ooRexx/WASM

*Written 06/10/2026–08/10/2026; describes patch 0007 (`wasm-js-objects`) of
the current series. Model: OLEObject on Windows.*

The first part of this note is the design as proposed; the sections on the
phases record what was built and where the implementation departed from the
proposal. Where the two differ, the phase sections describe the final design.

## Goal

Let Rexx code use JavaScript objects as Rexx objects — the DOM, fetch,
IndexedDB, canvas in the browser; `require()`d modules (npm) under Node —
with ordinary message syntax:

```rexx
doc = .js~page~document
p = doc~createElement("p")
p~textContent = "Hola desde Rexx"
doc~body~appendChild(p)

resp = .js~fetch("data.json")~await          -- a Promise, waited for
data = resp~json~await
say data~items~length

fs = .js~require("node:fs")                   -- Node build
say fs~readdirSync(".")~join(", ")
```

Both browser uses need it: "ooRexx running in a page" can stay as it is, and
"ooRexx for programming pages" is built on it (rxbrowsersys, ADDRESS DOM /
FETCH are thin layers over it; see `dom-fetch-design.md`).

## Facts that shape the design

1. **Three realms, not one.** In the browser the Emscripten "main runtime
   thread" is a Web Worker (`ooRexx-worker.js`), not the page; the
   interpreter runs on a pthread under it. So:
   - **worker realm**: the runtime worker. Has fetch, IndexedDB, WebSocket,
     crypto, OffscreenCanvas, timers. No DOM.
   - **page realm**: the page's main thread. DOM, `window`, `document`,
     localStorage, clipboard, dialogs. Reachable only by `postMessage` from
     the worker.
   - **node realm**: Node's main thread (Node build). `require`, `process`,
     npm modules. Node/Windows vs Node/Linux differences are Node's problem,
     not ours.
   Every JS object lives in exactly one realm; a reference carries its realm.
2. **The interpreter thread may block; the realm threads never do.** This is
   what makes a synchronous Rexx API possible. The mechanism already exists
   (JDOR, patch 0006): `emscripten_proxy_sync_with_ctx` to the runtime
   thread; the JS side may finish the call later with
   `emscripten_proxy_finish(ctx)`. For the page realm the worker forwards
   with `postMessage` and finishes the ctx when the page answers.
3. **ooRexx uppercases every message name, quoted ones too** (checked:
   `o~"getElementById"` arrives as `GETELEMENTBYID`). JS is case-sensitive.
   So natural syntax needs case-insensitive name resolution (below), with
   explicit, case-exact methods as the escape hatch.

## Rexx surface

`::requires "js.cls"` (which does `::requires "js" LIBRARY`, as jdor.cls).

**The entry object `.js`** — the default realm's `globalThis` (worker in the
browser, node under Node), plus:

| | |
|---|---|
| `.js~page` | the page's `window` (browser; error if the embedder did not allow it) |
| `.js~worker`, `.js~node` | explicit realm globals |
| `.js~require(name)` | Node: `require` |
| `.js~new(ctor, args...)` | `new` (also `ctor~new(args...)`) |
| `.js~num(x)`, `.js~bool(x)`, `.js~str(x)` | force a JS type for an argument |
| `.js~newArray(...)`, `.js~newObject(directory)` | build JS values explicitly |
| `.js~undefined` | JavaScript's `undefined` (see Phase 4) |
| `.js~handler(obj, msg [, options])` | a JS function that queues events for Rexx |
| `.js~nextEvent([timeout])`, `.js~eventLoop`, `.js~stopEventLoop` | events, see below |

**A `.JSObject`** stands for one JS object (or function). Messages:

| Rexx | JS |
|---|---|
| `o~name` | get property `name`; if it is a function, call it with `this = o` (as OLEObject); a constructor is returned, not called |
| `o~name(a, b)` | call method `name` |
| `o~name = v` (message `NAME=`) | set an existing property |
| `o["exactName"]`, `o["exactName"] = v`, `o~invoke("exactName", args...)` | case-exact, no guessing (`o~invoke(.nil, ...)` calls `o`) |
| `o~await` | wait for a Promise/thenable; result or JS error |
| `o~new(args...)` | `new o(...)` |
| `o[i]`, `o[i] = v` | element/property access (`[]`, `[]=`) |
| `o~makeArray`, `o~supplier` | iterables, so `DO x OVER o` and `DO WITH` work |
| `o~typeOf`, `o~className`, `o~instanceOf(c)`, `o~hasProperty`, `o~propertyNames` | introspection |
| `o~byteString` | the bytes of a binary value |
| `o~string`, `say o` | "a JSObject (HTMLDivElement #12, page)" — honest, like JDOR objects |
| `o1 == o2` | same JS object (identity) |

**Case-insensitive resolution.** For `GETELEMENTBYID` the bridge walks the
object's prototype chain, collects property names, and picks the one whose
uppercase matches. Cached per prototype (so per "class": one walk per
HTMLElement prototype, not per call). The lookup is live (a property added
later is found). Zero matches: the property does not exist and a get answers
`.js~undefined`. Several matches: of two, the one starting in lowercase wins
(`window.document` / `window.Document`); otherwise an error naming the
candidates, use `o["exactName"]` / `~invoke`. Setting a property that does
not exist anywhere is an error: Rexx gives only the uppercase name, so new
properties need `o["exactName"] = v`.

## Values across the bridge

JS → Rexx:
- string → string; number → Rexx number string (integers without `.0`,
  `NaN`/`Infinity` as such); boolean → `1`/`0`; `null` → `.nil`;
  `undefined` → `.js~undefined`; bigint → digits;
- object, function, array, Promise → `.JSObject` (by reference, never
  copied: arrays stay live). `~makeArray` copies on request.

Rexx → JS:
- string → **string** (Rexx has no types; numbers stay strings, which DOM
  attributes and most APIs coerce; `.js~num()` when a real number matters,
  see Decisions);
- `.nil` → `null`; `.js~undefined` → `undefined`; `.JSObject` → the object
  itself;
- Array → JS array (copy), Directory/StringTable → plain object (copy);
- a Rexx object used as a callback → see Events.

Transport: the record format of JDOR (`<tag><len>:<bytes>`, S/N/A/T + a new
`O realm<tab>id` for references, `H` for handlers, `U` for undefined), and its
sync proxy. Strings as UTF-8.

## Object lifetime

Each realm keeps a handle table: `id → object` and `object → id` (a Map), so
the same JS object always gets the same id (identity works, no leaks from
repeated gets). A `.JSObject` holds `realm + id`; its `uninit` (run by the
Rexx garbage collector) queues a release, sent with the next call or in
batches. Handlers given to JavaScript are pinned on the Rexx side (see
Phase 3 for the final rule).

## Errors

A JS exception becomes a Rexx SYNTAX condition, 98.900 "JavaScript error:
Name: message" (e.g. "JavaScript error: TypeError: x is not a function"),
with the thrown value kept in the condition's `ADDITIONAL[2]` (a `.JSObject`
for an Error: name, message, stack). A rejected Promise under `~await` the
same. Page realm not allowed / not reachable: its own message.

## Events and callbacks

JS cannot call into the interpreter synchronously (it may be busy, and a
realm thread must not block). So callbacks are queued:

```rexx
btn~addEventListener("click", .js~handler(self, "CLICKED"))   -- target, message
...
.js~eventLoop                       -- dispatch until .js~stopEventLoop
-- or: do forever; ev = .js~nextEvent(1); if ev \= .nil then ev~dispatch; end

::method clicked
  use arg event                     -- a .JSObject (the DOM event)
```

`.js~handler(obj, msg [, options])` makes a JS function that pushes
`(handler, args)` to the interpreter's event queue and returns at once. The
JS function cannot return a Rexx answer, so things like `preventDefault` are
declared in options (`.js~handler(self, "SUBMIT", "preventDefault")`).
`~await` keeps working inside handlers. Several Rexx threads may wait; one
dispatches each event.

## Security / embedding

Either browser realm gives the program the full power of JavaScript there,
and there is no partial grant: from almost any object one reaches its
constructor and then `Function` (arbitrary code). Worker realm: `fetch` with
the embedding site's cookies (its own API, as the logged-in user; CORS only
stops other origins), the site's IndexedDB (the playground keeps users' files
there), `eval`, the interpreter's own memory. Page realm: the DOM besides.
Harmless when people run their own code (playground); it matters when an
embedder runs somebody else's Rexx (e.g. a course site grading students'
programs in the teacher's browser).

So:
- the embedder grants each realm explicitly:
  `ooRexx.run(..., { js: { worker: true, page: true } })`; **both off by
  default**, so an embedder who knows nothing of `.JSObject` keeps a
  harmless interpreter; without the grant `.js` raises a clear error;
- the playground grants both (users run their own code);
- Node: always on (Rexx there already has host files and processes);
- the documentation says it plainly: granting a realm gives the Rexx
  program all of JavaScript's power in it.

Grants are for whole realms. A narrower root (granting, say, only one DOM
subtree) is not a boundary in JavaScript without SES, so it is not offered.

## Performance

Worker/node realm: one sync proxy per call (µs). Page realm: two hops
(postMessage there and back), roughly 0.1–1 ms. Fine for UIs; a later
optimisation could batch property chains (`doc~body~style~color = "red"` is
four calls today). Measurements are in the phase sections.

## Where it lives

Patch 0007 (`wasm-js-objects`), outside the RFE like 0006:
`wasm/web-js.cpp` (native package "js": the handler-free equivalent of
web-jdor.cpp), `wasm/js-realm.js` (the realm side: handle tables, name
resolution, marshalling), `wasm/js-bridge.js` (the dispatcher on the main
runtime thread), the page side in `wasm/web/ooRexx.js`, and
`wasm/web/js.cls`. Linked into bin-web and bin-node.

## Phases

1. **Core, worker/node realm**: get/set/call/new, case-insensitive
   resolution, marshalling, handles + uninit, errors, `~await`. Under Node
   it is already useful (npm from Rexx).
2. **Page realm**: postMessage forwarding, opt-in, DOM samples in the
   playground.
3. **Events**: handlers, queue, `eventLoop`.
4. **On top**: `DO OVER`, event coalescing; batching and rxbrowsersys /
   ADDRESS DOM, FETCH later.

## Decisions

1. Names `.js` / `.JSObject` / `js.cls`, following the OLEObject precedent.
2. Rexx strings always go to JS as strings; `.js~num()` etc. when a real
   number matters, because automatic conversion would break values such as
   "007".
3. An unknown property on get answers `.js~undefined`, as in JavaScript.
   (The first version answered `.nil` for both null and undefined; see
   Phase 4.)
4. Default realm in the browser: the worker; the DOM through `.js~page`.
5. Events are pull-based (`.js~handler` + `.js~eventLoop`), because
   JavaScript cannot call into a possibly busy interpreter.
6. The worker realm is opt-in like the page realm, both off by default (see
   Security / embedding).

## Phase 1: core, worker and node realms

Files: `wasm/web-js.cpp`, `wasm/js-bridge.js`, `wasm/web/js.cls`,
`wasm/extra-packages.cpp` (the hook lists jdor and js through weak symbols,
since Node links js but not jdor), `ooRexx.js`/worker option
`js: {worker, page}`, docs in `wasm/README.md`. Tests at this stage:
`web-api.py` +5 cases (35), `qualify-node-cli.sh` +1 check (15: npm
`require` from the cwd, `import` of an .mjs, await, errors). The playground
grants both realms and has a "JavaScript" sample group. `qualify.sh` 35/35.

Changes from the proposal, found while building it:

- **Exact accessors renamed.** The proposed `get`/`set`/`call`/`has`/`keys`/
  `bytes` hid JavaScript's own methods of the same name (a Map's
  `m~set("a", 1)` ran the exact setter, so `m~size` stayed 0; Map/Set/
  Headers/URLSearchParams/FormData/Response all use them). Now: `o["name"]`,
  `o["name"] = v` (exact property; `[]`/`[]=` existed anyway),
  `o~invoke("name", args...)` (exact call; `o~invoke(.nil, ...)` calls o),
  `o~hasProperty`, `o~propertyNames`, `o~byteString`.
- **`.js~array` / `.js~object` renamed** `.js~newArray` / `.js~newObject`:
  they hid JavaScript's `Array` and `Object` (`.js~Array~from`,
  `.js~Object~keys`).
- **Constructors.** `o~name` with no arguments calls a function property,
  except a constructor (Capitalized name and an own `prototype`), which is
  returned, so `.js~Map~new` works (Rexx cannot tell `o~f` from `o~f()`).
- **`o~name = v`** on a property that does not exist is an error pointing to
  `o["exactName"] = v` (the case cannot be guessed).
- **Errors** are SYNTAX 98.900 "JavaScript error: Name: message" with the
  thrown value in `ADDITIONAL[2]`; the helpers in js.cls RAISE PROPAGATE so
  errors point at the caller's line.
- **Promises** handed to Rexx are marked handled (Node kills the process on
  an unhandled rejection before `~await` can attach).
- The MEMFS runtime of the CMake build (`bin/`) has no `.JSObject` (only
  bin-web and bin-node link it).

Measured: ~80 µs per round trip under Node (100 000 `.js~newObject` in 8 s,
handle ids stay in the hundreds, so release by UNINIT works); 8 Rexx threads
awaiting at once. Heap views: Emscripten 6 code uses `(growMemViews(),
HEAP32)`; the bridge calls `growMemViews()` before touching the heap. Tested
without it after growing the memory to 160 MB: still fine (the proxied-call
path refreshes the views), so JDOR's direct `HEAPU8` use in patch 0006 is not
a proven bug, at most a hardening for the asynchronous finish.

## Phase 2: the page realm

- `wasm/js-realm.js`: the realm itself (handles, names, values, ops) as
  `orxJsRealm(name)`, the same code in the worker, Node and the page;
  `wasm/js-bridge.js` is the dispatcher on the main runtime thread: the
  realm of a request comes from GLOBAL's name or from the target reference;
  page requests go to the page by postMessage (`Module.orxJsPage`, set by
  ooRexx-worker.js), the page answers (`jsReply` → `Module.jsPageReply`), and
  only then is the interpreter's call finished; X releases of page handles
  are forwarded. The worker never blocks.
- `ooRexx.js`: with `js: {page: true}` it loads `js-realm.js` (copied next
  to it by build-web.sh, and by playground/build-site.sh) on first use and
  makes one page realm per run, dropped when the run ends. Grants are per
  realm: `{page: true}` alone works (`.js` errors, `.js~page` works).
- **Name tie-break** (needed at once: `window.document` / `window.Document`,
  also location/Location, navigator/Navigator, crypto/Crypto,
  performance/Performance, event/Event): of two matches, the one starting
  in lowercase wins; otherwise still an error. Failing closed on every
  ambiguity was considered and rejected: it would break
  `.js~page~document`.
- Realms do not mix: a worker object as argument to a page method is an
  error ('a JavaScript object of realm "worker" cannot be used in realm
  "page"'). Copying values across realms could come later.
- Tests: web-api.py +3 (38): DOM create/identity/await in the page/2000
  elements released, page not granted, realms apart. Playground: group
  "JavaScript & the page" with `page-dom.rex` and `page-clock.rex`
  (checked by screenshots mid-run).
- Measured: ~0.3 ms per page round trip in headless Chromium (2000
  `createElement` in ~0.6 s).
- A stopped run leaves its page changes behind (the page cannot know what to
  undo).

## Phase 3: events

- `.js~handler(obj, msg [, options])` is a `.JSHandler`, a Rexx object of no
  realm: record H "id<tab>options" makes it a function of whatever realm it
  is passed to, one per handler and realm (cached by id), so
  `removeEventListener` works and one handler serves the worker and the page.
- Called, the function applies its options to its first argument (words
  `preventDefault`, `stopPropagation`, `stopImmediatePropagation`; others
  are an error at `.js~handler`), encodes H id + A (the call's arguments, as
  `.JSObject`s) and hands them to `js_event` in web-js.cpp (local realm
  directly; page: postMessage `jsEvent` to the worker, `Module.jsEvent`),
  then returns undefined. Synchronous callbacks that must answer (sort,
  map) are not possible; documented.
- Rexx gets the call's arguments unchanged; `event~currentTarget` is .nil by
  then (documented; `event~target` is fine). No `this` argument.
- Queue: one per interpreter, unbounded (mutex + condition variable).
  `.js~nextEvent([seconds])` (decimals; none or negative: no limit) returns a
  `.JSEvent` (`~handler`, `~target`, `~message`, `~arguments`, `~dispatch`)
  or .nil. `.js~eventLoop` dispatches on its own thread until
  `.js~stopEventLoop`, which ends every loop running at that moment (a
  generation counter; later loops are not affected). Each event goes to one
  waiting thread. An error in a handler propagates out of `eventLoop`.
- **Lifetime** (changed from the proposal, which unpinned a handler when its
  listener was removed): a handler is pinned (a global reference in
  web-js.cpp) from its first trip to JavaScript until `handler~release` (its
  later and still queued events are dropped, their objects released) or the
  end of the run. No FinalizationRegistry: knowing when no realm holds the
  function any more needs a per-realm count fed back asynchronously, and a
  function made again after its old one was collected races with the "gone"
  notice; explicit release + end of run cover the real cases (one handler
  per kind of event, `event~target` tells which element). Passing a released
  handler again pins it again.
- End of run: the page realm's `close()` (ooRexx.js `end`) makes its
  handler functions inert and drops its handles; a stopped run's listeners
  stay on the page but do nothing.
- **Node exit**: Emscripten's exit under Node only sets `process.exitCode`
  and lets the event loop drain, so a listening server or a pending timer
  kept the process alive after the Rexx program ended (it was so since
  phase 1). js-bridge.js chains `Module.onExit` to `process.exit(rc)`: the
  program's end is the process's end, as natively.
- **Unguarded**: `.js~eventLoop` running on one thread held `.js`'s object
  lock (guarded method), so `.js~stopEventLoop` from another thread waited
  forever. All of `.JSObject`'s and `.JSGlobal`'s methods are UNGUARDED
  (they keep no state of their own; the native ones never were meant to
  serialise threads).
- **`==` fixed** (a phase 1 bug): `o == .nil` raised Error 97 (`&` evaluates
  both sides); now `.false` for anything that is not a `.JSObject`.

Tests: `web-api.py` 40 cases (+2: worker timer with eventLoop/stop/release
and nextEvent timeouts; page checkbox click with preventDefault, target,
currentTarget, removeEventListener, unknown option). `qualify-node-cli.sh`
16 checks (+1: an HTTP server answered from Rexx with the loop on its own
thread and fetch from the main one; three threads taking 15 timer events;
release; exit with the server still listening). Playground sample
`page-events.rex` (a to-do panel: form submit with preventDefault, one
list handler for every item, Done stops the loop), driven by Playwright and
checked by screenshot. Found with it: listeners must be set up before the
form shows, or an early Enter really submits it and reloads the page (the
sample says so).

## Phase 4: iteration and event coalescing

Iteration and coalescing are built; batching and copying values across
realms are not. ADDRESS DOM and ADDRESS FETCH were designed separately
(`dom-fetch-design.md`; patches 0009 and 0010). The whole JS integration is
a prototype; it is a sister of Rony G. Flatscher's BSF4ooRexx, and good
documentation for developers is the next step.

- **Iteration.** `DO x OVER o` already worked through `~makeArray`
  (`Array.from`) for arrays, Set, NodeList, any iterable; a Map gives its
  `[key, value]` pairs (as `for...of`). `~makeArray` on a non-iterable is an
  error naming the alternatives (it was silently empty); `~supplier` makes
  `DO WITH INDEX i ITEM v OVER o` work: a Map's keys and values, an
  iterable's 1..n and values, any other object's own enumerable properties
  (so a plain object is walked like a Directory with DO WITH). JavaScript's
  meaning for `DO x OVER map` is kept (pairs, not keys as a Rexx Directory
  would give): the supplier covers the Rexx way.
- **Option `latest`** for `.js~handler`: the function marks its event
  (H "id<tab>L"); `js_event` replaces the handler's event still waiting in
  the queue, if any (in place, the old one's objects released), so at most
  one waits, the newest. For mousemove, scroll, resize.
- **Option `max n`**: at most n events of the handler wait; when n are
  waiting, the oldest is dropped (record H "id<tab>Mn"; `latest` is the
  one-event case and wins if both are given; `max 0` is an error).
- **`undefined` is not `.nil`** (changes decision 3 of the first version):
  null comes back as .nil, undefined as `.js~undefined`, a single object
  (`.JSTyped~undefined`, handed to web-js.cpp by `JsSetup`; record U both
  ways), whose string is "undefined". A property that does not exist reads
  as `.js~undefined`; `~hasProperty` tells the two apart. dom.cls (patch
  0010) checks JavaScript values with a `missing()` routine (null or
  undefined).
- Tests: qualify-node-cli.sh 17 (+1: Map/array/object with DO WITH, the
  error, latest keeps detail 5 of 5), later also `max 2` keeps events 4 and
  5 and `max 0` refused; web-api.py 41 (+1: 20 page events, only the 20th
  waits), later also null/undefined/hasProperty in the js core case.

The `max n` option and the `undefined` change were made after public review
of the specification on the developers' list. That review also confirmed two
choices that stay: the lower-case tie-break for names that differ only in
case, and whole-realm grants.

## Guarantees

Properties of the implementation worth stating in the specification:

- identity: the same JS object is always the same `.JSObject` (`==`);
- every operation runs on its realm's thread, so any Rexx thread may use
  any `.JSObject`;
- `~await` blocks only the Rexx thread that waits;
- name lookup is live;
- thrown values are kept (`ADDITIONAL[2]`);
- handles are reference-counted and released by `uninit`.
