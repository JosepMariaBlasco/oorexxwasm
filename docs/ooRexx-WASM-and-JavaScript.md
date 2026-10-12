# ooRexx/WASM and JavaScript

Working draft · Josep Maria Blasco

*This is the living version of the specification: it follows the implementation and changes with it. The version posted to the ooRexx developers' list on October 8, 2026 is kept as it was sent in [`posted/2026-10-08`](posted/2026-10-08/ooRexx-WASM-and-JavaScript.md); [Changes since the posted version](#changes-since-the-posted-version) lists what differs.*

## What this is

This document specifies a way for ooRexx programs to use JavaScript, both in the browser and under Node: `.JSObject`, which gives access to all of JavaScript as Rexx objects. All of it is implemented and can be tried in an online playground, [rexx.epbcn.com/oorexx-wasm](https://rexx.epbcn.com/oorexx-wasm/). It is offered for discussion.

Any JavaScript object, function, array or Promise reaches Rexx as a `.JSObject`, by reference, and is used with ordinary messages. The way in is `.js`, which `::requires "js.cls"` defines: it holds everything JavaScript knows by name, such as `Math`, `Map` or `fetch` (in JavaScript terms, the global object).

```rexx
say .js~Math~max(3, 7)                          -- 7
m = .js~Map~new; m~set("a", 1); say m~size      -- 1
resp = .js~fetch("data.json")~await             -- a Promise, waited for
doc = .js~page~document                         -- the browser page's DOM

p = doc~createElement("p")
p~textContent = "Hola"
doc~body~appendChild(p)

/* ... */
::requires "js.cls"
```

## Realms

JavaScript always runs in a "realm", a world with its own global objects. In the browser, ooRexx does not run in the page itself but in a background thread (a Web Worker), so that a long Rexx program never freezes the page. That thread is one realm, `.js`: it has the network (`fetch`), the browser's local database and WebSockets, but cannot touch what is on the screen. What the user sees, the DOM, belongs to another realm, the page's realm, `.js~page`. A JavaScript object of one realm cannot be given to the other (as an argument, or assigned to a property): strings, numbers and booleans travel as values, objects only within their realm.

Under Node there is a single realm, `.js`, which also gives Node's modules (`.js~require("node:fs")`).

In the browser, the page that runs ooRexx must grant each realm (`js: {worker: true, page: true}`). A grant gives the program everything JavaScript can do in that realm.

## Messages

`o~name` reads a property, or calls it when it is a function (a constructor, such as `Map`, is returned instead, so that `.js~Map~new` works); `o~name(a, b)` calls a method; `o~name = v` sets a property that exists. ooRexx uppercases message names, so they are resolved case-insensitively along the prototype chain. `o["name"]`, `o["name"] = v` (which also creates the property) and `o~invoke("name", ...)` are exact.

On an array or a typed array, `o[i]` and `o[i] = v` count from 1, as in a Rexx Array: `o[1]` is JavaScript's `o[0]`, 0 is an error, a position past the end reads `.js~undefined`, and `o[n + 1] = v` appends. `o~at(i)` and `o~put(v, i)` are the same as `o[i]` and `o[i] = v`, as AT and PUT are in Rexx's collections. `DO WITH INDEX i ITEM v OVER o` gives the same positions, 1 to n. Lists that are not arrays, such as the DOM's `NodeList`, keep JavaScript's indexing from 0, and so does `DO WITH` over them. JavaScript's own methods keep their meaning: `o~slice(1)`, `o~indexOf(x)`; JavaScript's `at` (which takes negative positions) is `o~invoke("at", i)`.

| Method | Does |
| --- | --- |
| `~at(i)`, `~put(v, i)` | the same as `o[i]` and `o[i] = v` |
| `~new(args...)` | `new o(args...)` |
| `~await` | waits for a Promise and gives its value; a rejection is an error |
| `~typeOf`, `~className`, `~instanceOf(c)` | JavaScript's `typeof`, the class name, `instanceof` |
| `~hasProperty(name)`, `~propertyNames` | JavaScript's `in`, with the exact name; `Object.keys` |
| `~makeArray`, `~supplier` | for `DO x OVER o` and `DO WITH INDEX i ITEM v OVER o`: arrays, Maps, Sets, lists and plain objects |
| `~byteString` | an ArrayBuffer's or typed array's bytes as a Rexx string |

## Values

JavaScript strings, numbers, booleans (1/0) and bigints come back as Rexx strings; null as `.nil`, and undefined as `.js~undefined`, a single object, so `x == .js~undefined` tests for it. A property that does not exist reads as `.js~undefined`; `~hasProperty` tells the two apart. Rexx strings always go as strings, so "007" stays "007": `.js~num(x)`, `.js~bool(x)`, `.js~bigint(x)` and `.js~bytes(x)` (a Uint8Array) force a type, and `.js~true`, `.js~false` and `.js~undefined` are those values. `.nil` goes as null. An Array goes as an array and a Directory or StringTable as a plain object, both as copies; `.js~newArray(items...)` and `.js~newObject(directory)` make them in JavaScript instead, held by reference.

`.js~box(type, x)` forces a type with the type indicators of BSF4ooRexx's `box()`: `BOolean`, `BYte`, `Char`, `Double`, `Float`, `Int`, `Long`, `Object`, `SHort` and `STring`, and JavaScript's own `Number` and `BIgint`. Case does not matter, and an indicator may be shortened down to its capitals, so `.js~box("bo", 1)` is `.js~box("Boolean", 1)`. The whole-number types check Java's ranges (`.js~box("BYte", 300)` is an error), `Long` within the integers JavaScript holds exactly; `BIgint` takes any whole number. `.js~unbox(o)` gives back the Rexx value of a box, or of a JavaScript `Number`, `String`, `Boolean` or `BigInt` object.

## Errors

A JavaScript exception is SYNTAX 98.900, "JavaScript error: TypeError: …", with what was thrown in `condition("O")~additional[2]`.

## Events

A callback is a `.JSHandler`, made with `.js~handler(object, message [, options])`. JavaScript gets it as a function that sends the message to the object with the call's arguments.

In the worker's realm and under Node a handler is synchronous, as `.net~handler` in ooRexx/.NET: the method runs at once. When JavaScript calls it while a Rexx thread is waiting for JavaScript, as `sort`, `forEach`, `map` or `dispatchEvent` do, it runs on that thread, and JavaScript gets its result:

```rexx
a = .js~newArray(.js~num(3), .js~num(1), .js~num(2))
a~sort(.js~handler(self, "COMPARE"))            -- COMPARE answers each comparison
say a~join(",")                                 -- 1,2,3

::method compare
  use arg x, y
  return .js~num(x - y)
```

A condition in the method is thrown to JavaScript as a `RexxError`. When JavaScript calls the handler on its own, as a timer, a Node server or a settling Promise do, the method runs at once on a thread of its own, one call at a time, and JavaScript does not wait for it: see [Waiting](#waiting).

In the page every handler is queued, and so is a handler with option `queued` anywhere. JavaScript gets a function that only queues the call and returns at once; a Rexx thread takes the calls when it is ready:

```rexx
btn~addEventListener("click", .js~handler(self, "CLICKED", "preventDefault"))
.js~eventLoop                     -- sends CLICKED for each call
```

`.js~eventLoop` sends the message to the object, with the call's arguments, for each call until `.js~stopEventLoop`, from a handler or another thread. `.js~nextEvent([seconds])` takes one event instead (a `.JSEvent`, which `~dispatch` sends; `.nil` when the time is over), so a program can run its own loop. Several threads may wait; each event goes to one.

Because a queued handler's function returns before Rexx sees the call, it cannot answer anything, and by then the browser has finished dispatching the event (`event~currentTarget` is `.nil`). What must happen during the dispatch goes in the options, for any handler: `preventDefault`, `stopPropagation`, `stopImmediatePropagation`. Option `latest` keeps only the newest event of the handler waiting, for mousemove or scroll; option `max n` keeps at most n, dropping the oldest. Both imply `queued`.

A handler stays alive from its first trip to JavaScript until `handler~release` or the end of the run.

## Waiting

Calling JavaScript from Rexx always works the same way: the Rexx thread sends the request to the thread of the realm and waits for the answer. Every Rexx thread is a thread of its own (a Web Worker in the browser, a worker thread under Node), and a worker may wait.

The other way round is where realms differ, because for JavaScript to call Rexx and use the answer, the JavaScript thread itself has to wait while a Rexx thread runs the method:

| Where the JavaScript runs | Can it wait? |
| --- | --- |
| The page's realm, `.js~page` | No. The page's thread also draws the screen and handles the mouse and keyboard, and browsers do not let it block (`Atomics.wait` throws there): while it waited, the page would freeze. |
| The worker's realm, `.js`, in the browser | Yes. A worker draws nothing, and may block. |
| Node, `.js` | Yes. Node's main thread may block. |

What the page *can* do is call Rexx without waiting: send the call, go on, and receive the answer later. In JavaScript that answer-to-come is a Promise. A Promise is enough wherever JavaScript accepts one (`await` in an `async` function, `then`), because the thread is free until the answer arrives. It is not enough where JavaScript needs a plain value at once, before the function it called returns: a comparator for `sort`, a callback for `filter` or `map`, a getter, an event listener that must decide during the dispatch whether to call `preventDefault`. In those places the page cannot use Rexx's answer, whatever the bridge does.

This is why a handler in the page is always queued, and why the browser has finished dispatching an event by the time Rexx sees it.

In the worker's realm and under Node, JavaScript does wait for a synchronous handler when a Rexx thread is waiting for JavaScript (a comparator for `sort`): that thread runs the method, and meanwhile it cannot wait for JavaScript in turn, since JavaScript is waiting for it. `~await` and the page are errors there. When JavaScript calls a handler on its own (a timer, a Node server), it does not wait: the realm's thread must stay free, because what finishes later (sockets, the page, the RexxAPI daemon under Node) needs it. So the method runs on a thread of its own, may wait for JavaScript, and JavaScript gets `undefined`. A condition there, or one an event listener does not pass on, is written on the standard error.

In the page, what can be done:

- **Say it in advance.** What must happen during the dispatch, and is always the same, goes in the handler's options: `.js~handler(self, "SUBMIT", "preventDefault")`.
- **Write the part that cannot wait in JavaScript, from Rexx.** `Function` makes a JavaScript function in any realm, and it runs at once, without Rexx:

  ```rexx
  cmp = .js~page~Function~new("a", "b", "return a - b")
  list~sort(cmp)                                    -- sorted in the page, no Rexx involved

  enter = .js~page~Function~new("e", "if (e.key === 'Enter') e.preventDefault()")
  field~addEventListener("keydown", enter)          -- decides during the dispatch
  field~addEventListener("keydown", .js~handler(self, "KEY"))   -- Rexx hears of it afterwards
  ```

- **Do the work in Rexx, or in the worker's realm.** Bring the data over, compute there, and hand the page the result: a sorted array instead of a comparator.
- **Let JavaScript take a Promise** where it can: code of one's own written with `async`/`await` waits for Rexx without blocking the page.

A queued handler given where JavaScript needs a value at once does not fail: JavaScript receives `undefined`, and Rexx receives the calls later, as events. `.js~page~Array~of(3, 1, 2)~sort(.js~handler(o, "COMPARE"))` leaves the array as it was, with three calls queued; in the worker's realm the same `sort` works.

## Pitfalls

- **Case-insensitive names can pick the wrong property.** `.js~page~Event` finds `window.event`, the current event, before `window.Event`, the constructor. Use the exact form: `w["Event"]~new("input")`.
- **Rexx methods win.** The methods in the table above, and those of Rexx's Object (`send`, `start`, `copy`, `run`, …), are not passed on to JavaScript. `el~className` names the JavaScript class (`HTMLDivElement`), not the element's `class` attribute: use `el["className"]`, and `o~invoke("send", x)`. Likewise `a~at(1)` is the first element, as `a[1]`: JavaScript's own `at` is `a~invoke("at", 0)`.
- **Directory keys are upper case.** `d~method = "POST"` stores `METHOD`, which a JavaScript options object does not know: use `d["method"] = "POST"`.

## Guarantees

- The same JavaScript object is always the same `.JSObject`: `o1 == o2` tests identity.
- Each operation runs on the thread of its realm, so any Rexx thread may use any `.JSObject`.
- `~await` blocks only the Rexx thread that waits.
- Names are looked up when the message arrives, so a property added later is found.
- What a JavaScript exception threw is kept, in `condition("O")~additional[2]`.
- A `.JSObject` keeps its JavaScript object alive while Rexx holds it, and no longer.

## Relation to BSF4ooRexx and OLEObject

The design follows Rony Flatscher's BSF4ooRexx, moved from Java to JavaScript: `.JSObject` is to JavaScript objects what `BSF.CLS` is to Java objects. Messages work as with OLEObject on Windows: names are case-insensitive, and `o~name` reads a property or calls a method. As in BSF4ooRexx, arrays count from 1 and `box` takes the same type indicators, so what holds in one bridge holds in the other.

## Questions to decide

1. **Names.** Case-insensitive resolution makes `doc~getElementById` work as written, at the price of the rare wrong pick shown above. Would you rather have exact names only?
2. **Values.** Rexx strings always go as strings, and a number is forced with `.js~num`. Would you rather have numbers converted automatically, at the price of "007" becoming 7?
3. **Events.** Handlers are synchronous where JavaScript can wait (the worker, Node), as in ooRexx/.NET, and queued in the page, taken by `.js~eventLoop` or `.js~nextEvent`. Does this model suit you, or would you expect another?

Replies on this list are very welcome.

## Changes since the posted version

| Change | Where |
| --- | --- |
| undefined comes back as `.js~undefined`, no longer `.nil`; a missing property reads as it | Values |
| Handler option `max n` | Events |
| Arrays and typed arrays count from 1 with `o[i]` and `DO WITH`; lists keep 0 | Messages |
| `.js~box(type, x)` with BSF4ooRexx's type indicators, and `.js~unbox(o)` | Values |
| What the implementation guarantees, stated | Guarantees |
| `~at(i)` and `~put(v, i)` are `o[i]` and `o[i] = v`, as in Rexx's collections (JavaScript's `at` is `o~invoke("at", i)`) | Messages, Pitfalls |
| Why JavaScript cannot wait for Rexx in the page, and what to do instead | Waiting |
| Handlers are synchronous in the worker's realm and under Node, as `.net~handler` (a comparator for `sort` works); option `queued` (implied by `latest` and `max`), and the page, keep them queued; a condition is a `RexxError` | Events, Waiting |
