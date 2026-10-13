# ooRexx/WASM and JavaScript

Working draft · Josep Maria Blasco

*This is the living version of the specification: it follows the implementation and changes with it. The version posted to the ooRexx developers' list on October 8, 2026 is kept as it was sent in [`posted/2026-10-08`](posted/2026-10-08/ooRexx-WASM-and-JavaScript.md); [Changes since the posted version](#changes-since-the-posted-version) lists what differs.*

## What this is

This document specifies a way for ooRexx programs to use JavaScript, both in the browser and under Node: `.JSObject`, which gives access to all of JavaScript as Rexx objects. All of it is implemented and can be tried in an online playground, [rexx.epbcn.com/oorexx-wasm](https://rexx.epbcn.com/oorexx-wasm/). It is offered for discussion.

It works both ways. Rexx objects reach JavaScript too, which sends them messages, and a page can run Rexx as it runs JavaScript, with its own `<script type="text/rexx">` or by calling an interpreter it keeps (see [Rexx from the page](#rexx-from-the-page)).

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

`o~name` reads a property, or calls it when it is a function (a constructor, such as `Map`, is returned instead, so that `.js~Map~new` works); `o~name(a, b)` calls a method; `o~name = v` sets a property that exists. ooRexx uppercases message names, so they are resolved case-insensitively along the prototype chain. Where that is not enough, as with two members whose names differ only in case, the exact name is always available, as with BSF4ooRexx's `bsf.invokeStrict`: `o~js.getStrict("name")`, `o~js.setStrict("name", v)` (which also creates the property) and `o~js.invokeStrict("name", args...)`; on an object that is not an array, `o["name"]` and `o["name"] = v` are exact too. A function is called with JavaScript's own `call`: `f~call(this, args...)`.

The bridge's own methods start with `js.`, as BSF4ooRexx's start with `bsf.`, so that they never hide a JavaScript member of the same name: `el~className` is the element's `className`, and `el~js.className` the name of its JavaScript class. The exceptions are the messages Rexx itself sends for its syntax and protocols (`[]`, `[]=`, `at`, `put`, `new`, `makeArray`, `supplier`), and `await`.

On an array or a typed array, `o[i]` and `o[i] = v` (the messages `[]` and `[]=`) count from 1, as in a Rexx Array: `o[1]` is JavaScript's `o[0]`, 0 is an error, a position past the end reads `.js~undefined`, and `o[n + 1] = v` appends. `o~at(i)` and `o~put(v, i)` are the same as `o[i]` and `o[i] = v`, as AT and PUT are in Rexx's collections. `DO WITH INDEX i ITEM v OVER o` gives the same positions, 1 to n. Lists that are not arrays, such as the DOM's `NodeList`, keep JavaScript's indexing from 0, and so does `DO WITH` over them. JavaScript's own methods keep their meaning: `o~slice(1)`, `o~indexOf(x)`; JavaScript's `at` (which takes negative positions) is `o~js.invokeStrict("at", i)`.

| Method | Does |
| --- | --- |
| `~at(i)`, `~put(v, i)` | the same as `o[i]` and `o[i] = v` (the messages `[]` and `[]=`) |
| `~js.getStrict(name)`, `~js.setStrict(name, v)`, `~js.invokeStrict(name, args...)` | the property or method with exactly that name |
| `~new(args...)` | `new o(args...)` |
| `~await` | waits for a Promise and gives its value; a rejection is an error |
| `~js.typeOf`, `~js.className`, `~js.instanceOf(c)` | JavaScript's `typeof`, the class name, `instanceof` |
| `~js.hasProperty(name)`, `~js.propertyNames` | JavaScript's `in`, with the exact name; `Object.keys` |
| `~makeArray`, `~supplier` | for `DO x OVER o` and `DO WITH INDEX i ITEM v OVER o`: arrays, Maps, Sets, lists and plain objects |
| `~js.byteString` | an ArrayBuffer's or typed array's bytes as a Rexx string |

## Values

JavaScript strings, numbers, booleans (1/0) and bigints come back as Rexx strings; null as `.nil`, and undefined as `.js~undefined`, a single object, so `x == .js~undefined` tests for it. A property that does not exist reads as `.js~undefined`; `~js.hasProperty` tells the two apart. Rexx strings always go as strings, so "007" stays "007": `.js~num(x)`, `.js~bool(x)`, `.js~bigint(x)` and `.js~bytes(x)` (a Uint8Array) force a type, and `.js~true`, `.js~false` and `.js~undefined` are those values. `.nil` goes as null. An Array goes as an array and a Directory or StringTable as a plain object, both as copies; `.js~newArray(items...)` and `.js~newObject(directory)` make them in JavaScript instead, held by reference. `.js~newObject(name, value, ...)` makes a plain object from names and values, the names exactly as written: `.js~newObject("method", "POST", "cache", "no-store")`. Any other Rexx object goes by reference, as a `RexxProxy`: see [Rexx objects in JavaScript](#rexx-objects-in-javascript).

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

In the page every handler is queued, and so is a handler with option `queued` anywhere. The page cannot wait for Rexx (see [Waiting](#waiting)), so when JavaScript calls such a handler, the call is put in the **event queue** and JavaScript goes on at once. The event queue is where events wait until Rexx is ready for them: a Rexx thread takes them from it, one at a time, in the order they came. `.js~runEventLoop` takes them until `.js~stopEventLoop`; `.js~nextEvent` takes one. It is the mirror image of BSF4ooRexx's AWT and JavaFX queues, where Rexx leaves messages for the GUI thread; here the page leaves events for Rexx:

```rexx
btn~addEventListener("click", .js~handler(self, "CLICKED", "preventDefault"))
.js~runEventLoop                     -- sends CLICKED for each call
```

`.js~runEventLoop` takes the events from the event queue, and sends each one's message to its object, with the call's arguments, until `.js~stopEventLoop`, from a handler or another thread; it runs on the thread that calls it, and returns when the loop is stopped. `.js~nextEvent([seconds])` takes one event instead (a `.JSEvent`, which `~dispatch` sends; `.nil` when the time is over), so a program can run its own loop. Several threads may wait; each event goes to one. The page's calls of Rexx come through the same event queue: the thread that takes them runs them in turn, and `~nextEvent` goes on waiting (see [Rexx from the page](#rexx-from-the-page)).

Because a queued handler's function returns before Rexx sees the call, it cannot answer anything, and by then the browser has finished dispatching the event (`event~currentTarget` is `.nil`). What must happen during the dispatch goes in the options, for any handler: `preventDefault`, `stopPropagation`, `stopImmediatePropagation`. Option `latest` keeps only the newest event of the handler waiting in the event queue, for mousemove or scroll; option `max n` keeps at most n, dropping the oldest. Both imply `queued`.

A handler needs no care: it stays alive while JavaScript holds its function, and is released when JavaScript collects it (its events still in the event queue are taken first). `handler~release` releases it earlier, dropping its waiting events.

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

In the worker's realm and under Node, JavaScript does wait for a synchronous handler when a Rexx thread is waiting for JavaScript (a comparator for `sort`): that thread runs the method, and meanwhile it cannot wait for JavaScript in turn, since JavaScript is waiting for it. `~await` and the page are errors there. Everything else may be used, the RexxAPI under Node included (queues, the lookup of external functions): its daemon's replies do not go through the realm's thread. When JavaScript calls a handler on its own (a timer, a Node server), it does not wait: the realm's thread must stay free, because what finishes later (sockets, the page) needs it. So the method runs on a thread of its own, may wait for JavaScript, and JavaScript gets `undefined`. A condition there, or one an event listener does not pass on, is written on the standard error.

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
- **Let JavaScript take a Promise** where it can: code of one's own written with `async`/`await` waits for Rexx without blocking the page. Every call from the page to a Rexx object gives one (see [Rexx from the page](#rexx-from-the-page)).

A queued handler given where JavaScript needs a value at once does not fail: JavaScript receives `undefined`, and Rexx receives the calls later, as events. `.js~page~Array~of(3, 1, 2)~sort(.js~handler(o, "COMPARE"))` leaves the array as it was, with three calls queued; in the worker's realm the same `sort` works.

## Rexx objects in JavaScript

A Rexx object that is not converted (not a string or number, an Array, a Directory or a StringTable) reaches JavaScript by reference, as a `RexxProxy`, the name BSF4ooRexx gives it in Java. JavaScript sends it messages:

```rexx
acct = .Account~new(100)
f = .js~Function~new("a", "a.deposit(50); return a.sendMessage0('balance')")
say f~call(.nil, acct)                         -- 150
```

| JavaScript | Rexx |
| --- | --- |
| `o.name(a, b)` | `o~name(a, b)`: any property is a function that sends the message, its name upper-cased |
| `o.sendMessage(name, [args])` | the same, with the arguments in an array |
| `o.sendMessage0(name)` … `o.sendMessage5(name, a1, …, a5)` | the same, with 0 to 5 arguments |
| `o.sendMessageScope(name, scope, [args])` | `o~name:scope(args)`: the method search starts at the class `scope` (a `RexxProxy` of a Rexx class) |
| `String(o)`, `` `${o}` `` | the object's string when it last came over; `o.string()` asks Rexx now |

- **Values.** The arguments go to Rexx as anything JavaScript gives Rexx (see [Values](#values)), and the result comes back as anything Rexx gives JavaScript; a method with no result gives `undefined`.
- **The call** is a synchronous call of Rexx, as a synchronous handler's (see [Events](#events) and [Waiting](#waiting)): on the Rexx thread waiting for JavaScript, with its result, or, when JavaScript calls on its own (a timer), on a thread of its own, and JavaScript gets `undefined`. A condition is a `RexxError`. In the page, which cannot wait, a call gives a Promise of the result: see [Rexx from the page](#rexx-from-the-page).
- **Identity.** The same Rexx object is the same `RexxProxy` while JavaScript holds it (`a === b`), and a `RexxProxy` given back to Rexx is the Rexx object itself.
- **Classes.** A Rexx class is a Rexx object too: `C.new(args)` in JavaScript makes an instance.
- **Not a property bag, not a thenable.** Setting a property is a `TypeError`; `then` and `toJSON` are not messages, so `await` and `JSON.stringify` treat a `RexxProxy` as a plain object. `RexxProxy` and `RexxError` are globals of the realm, for `instanceof`.
- **Lifetime.** JavaScript holding a `RexxProxy` keeps the Rexx object alive; when JavaScript collects it, Rexx may collect the object.

## Rexx from the page

The page cannot wait (see [Waiting](#waiting)), so a call it makes to Rexx is queued, as the events of its handlers are, and gives a Promise of the result at once:

```js
const v = await o.deposit(50);        // o a RexxProxy in the page: a Promise
```

- **Who runs it.** The Rexx thread that takes events (`.js~runEventLoop`, `.js~nextEvent`) runs the calls in turn, as it runs the handlers' events. So does a Rexx thread waiting for JavaScript (`~await`, a request to the page), for the calls that come while it waits: what it waits for may be the page's code that called Rexx. As with `await` in JavaScript, other code may run while one waits.
- **The result.** The Promise is resolved with the method's result (`undefined` when there is none), or rejected with a `RexxError` for a condition. While nobody takes events it stays pending; when the run ends, it is rejected.

**Sessions.** `ooRexx.js` gives the page an interpreter that stays, to call when it needs Rexx:

```js
const rexx = await ooRexx.load();
const s = await rexx.start({ js: { page: true } });     // the options of run()
await s.eval('use arg a, b; return a + b', 2, 3);       // '5'
const r = await s.routine('double', 'use arg x; return x * 2');
await r.call(21);                                       // '42'
const p = await s.loadPackage('bank.cls', '::class Account public ...');
const acct = await (await p.findClass('Account')).new(100);
await acct.deposit(50);                                 // '150'
s.stop();
```

| JavaScript | Rexx |
| --- | --- |
| `s.eval(source, ...args)` | `source` run as a routine (`USE ARG`, `RETURN`): its result |
| `s.routine(name, source)` | a `Routine`: `r.call(...args)` |
| `s.loadPackage(name, source)` | a `Package`, its prolog run; without `source`, the file `name` (`'dom.cls'`) |

A session is a run whose program, `.js~session`, hands the page a `.JSSession` and then takes events for good: the session's calls, and the events of the handlers its code sets up, run one at a time, in the order they come. What a session makes sees `js.cls`, and the public classes and routines of what it made before, as the scripts of a page see each other's globals. `s` has what `run()` returns besides (`done`, `stop`, `write`, `close`); `s.rexx` is the `.JSSession` itself.

**Rexx scripts.** A page that loads `ooRexx.js` can hold Rexx as it holds JavaScript:

```html
<script src="ooRexx.js"></script>
<script type="text/rexx">
  .js~page~document~getElementById("greeting")~textContent = "Hello from Rexx"
</script>
<script type="text/rexx" src="app.rex"></script>
```

When the page has any, `ooRexx.js` starts a session once the document is parsed, with both realms granted (they are the page's own scripts), and runs them in order, each as a routine named after its `src`. A script sees what the scripts before it defined, its handlers run once the scripts are done, its output goes to the console, and an error is logged and does not stop the next script. `ooRexx.scripts` is a Promise of that session. [*ooRexx in a web page*](https://rexx.epbcn.com/oorexx-wasm/example/) is such a page.

## Classes

A Rexx class can extend a JavaScript class, so that JavaScript calls the Rexx methods where it would call the class's own, as `.net~extend` does in ooRexx/.NET:

```rexx
c = .MyCar~new("Seat", 2020)
say c~describe                    -- Car's describe() calls this.age(): "Seat is 7"

::requires "js.cls"
::class MyCar subclass JSObject
::method activate class
  .js~extend(self, "Car")         -- a JavaScript class, or its name
::method init
  use arg name, year
  self~init:super(name, year)     -- new Car(name, year)
::method age
  return self~age:super + 1       -- Car's own age()
```

`.js~extend(class, base [, names...])`, once per class (its `ACTIVATE` class method is the natural place), makes a JavaScript class that extends `base`, named as the Rexx class, and answers it. `base` is a `.JSObject` or the name of a class as a script sees it, also one declared with `class Car {}`. The class must be a subclass of `JSObject`.

- **What is overridden.** Every method of `base` and of its prototype chain whose name matches a method of the Rexx class, case-insensitively, as messages are; a getter is the method `NAME`, a setter `"NAME="`. The Rexx class's methods count with those of its superclasses below `JSObject`, but not `INIT`, `UNINIT` and `UNKNOWN`, nor private ones, and they are looked at when `extend` runs. The `names` are exact JavaScript names that `base` does not have, added as methods, for code that looks for them (a custom element's `connectedCallback`).
- **The call.** JavaScript calls an override as it calls a synchronous handler (see [Events](#events) and [Waiting](#waiting)): on the Rexx thread that is waiting for JavaScript, with its result; or, when JavaScript calls on its own, on a thread of its own, without waiting. A condition is a `RexxError`.
- **Making one.** `.MyCar~new(args...)` makes the JavaScript object with `new`, passing `args` to the base's constructor; the Rexx class's `INIT` calls `self~init:super(args...)`. A base constructor that calls an override reaches the Rexx method, and `self` can already be used there.
- **The base's members.** `self~name:super(args)` is the base's own member, not the override: its method, its getter, `self~"NAME=":super(v)` its setter. A member that is not overridden is reached as with any `.JSObject`: `c~honk`.
- **Identity.** The JavaScript object comes back to Rexx as the Rexx object itself: `.js~newArray(c)[1] == c`, and it is a `MyCar`.
- **Lifetime.** The Rexx object and its JavaScript object are a pair, which lives while Rexx holds the one or JavaScript holds the other, and the collectors release it, as they release everything else: nothing needs a hand. Each collector sees only its own side, so the bridge lets the link that keeps the other half alive point one way at a time. While Rexx holds the Rexx object, it holds its JavaScript object. When Rexx no longer does, the bridge holds the Rexx object, and the JavaScript object only weakly, so that JavaScript's collector decides: if JavaScript no longer holds it either, the pair is over; if JavaScript hands it to Rexx again, Rexx holds it again. The class's `UNINIT`, if it has one, runs once, when the pair is over, not when only Rexx lets it go, and as any `UNINIT` runs: in the scope of the class that defines it, with the object's variables. A class that extends a JavaScript class, and the JavaScript class it makes, are released as any class is. For an object JavaScript makes itself (`new MyCar(...)` in JavaScript), the overrides run the base's members.

This needs a realm where JavaScript can wait for Rexx: the worker's and Node's. In the page, `extend` is an error.

## Pitfalls

Each of these has a way out, as in BSF4ooRexx:

- **Case-insensitive names can pick the wrong property.** `.js~page~Event` finds `window.event`, the current event, before `window.Event`, the constructor. Use the exact name: `w~js.getStrict("Event")~new("input")`.
- **Rexx's own methods win.** Those of Rexx's Object (`send`, `start`, `copy`, `run`, …) and the few the bridge leaves without `js.` (`at`, `put`, `new`, `makeArray`, `supplier`, `await`) are not passed on to JavaScript. Use the exact form for JavaScript's: `o~js.invokeStrict("send", x)`, and JavaScript's own `at` is `a~js.invokeStrict("at", 0)`.
- **Directory keys are upper case.** `d~method = "POST"` stores `METHOD`, which a JavaScript options object does not know: use `.js~newObject("method", "POST")`, or `d["method"] = "POST"`.

## Guarantees

- The same JavaScript object is always the same `.JSObject`: `o1 == o2` tests identity.
- Each operation runs on the thread of its realm, so any Rexx thread may use any `.JSObject`.
- `~await` blocks only the Rexx thread that waits; meanwhile that thread runs the page's calls of Rexx, if any come.
- Names are looked up when the message arrives, so a property added later is found.
- What a JavaScript exception threw is kept, in `condition("O")~additional[2]`.
- A `.JSObject` keeps its JavaScript object alive while Rexx holds it, and no longer.

## Relation to BSF4ooRexx and OLEObject

The design follows Rony Flatscher's BSF4ooRexx, moved from Java to JavaScript: `.JSObject` is to JavaScript objects what `BSF.CLS` is to Java objects. Messages work as with OLEObject on Windows: names are case-insensitive, and `o~name` reads a property or calls a method. As in BSF4ooRexx, arrays count from 1 and `box` takes the same type indicators, so what holds in one bridge holds in the other.

## Questions decided

The posted version asked three questions. The answers adopted:

1. **Names.** Case-insensitive resolution stays, with an exact form for every operation where it is not enough: `js.getStrict`, `js.setStrict`, `js.invokeStrict`.
2. **Values.** Rexx strings always go as strings, since a Rexx string that looks like a number need not be one; `.js~box` and `.js~unbox` (and `.js~num` and the like) say what is meant.
3. **Events.** The model stays, with the event queue explained and `.js~runEventLoop` named after what it does.

Further replies on the list are very welcome.

## Changes since the posted version

| Change | Where |
| --- | --- |
| undefined comes back as `.js~undefined`, no longer `.nil`; a missing property reads as it | Values |
| Handler option `max n` | Events |
| Arrays and typed arrays count from 1 with `o[i]` and `DO WITH`; lists keep 0 | Messages |
| `.js~box(type, x)` with BSF4ooRexx's type indicators, and `.js~unbox(o)` | Values |
| What the implementation guarantees, stated | Guarantees |
| `~at(i)` and `~put(v, i)` are `o[i]` and `o[i] = v`, as in Rexx's collections (JavaScript's `at` is `o~js.invokeStrict("at", i)`) | Messages, Pitfalls |
| Why JavaScript cannot wait for Rexx in the page, and what to do instead | Waiting |
| Handlers are synchronous in the worker's realm and under Node, as `.net~handler` (a comparator for `sort` works); option `queued` (implied by `latest` and `max`), and the page, keep them queued; a condition is a `RexxError` | Events, Waiting |
| Any other Rexx object goes to JavaScript as a `RexxProxy` (it went as its string): messages, BSF4ooRexx's `sendMessage` names, identity both ways | Values, Rexx objects in JavaScript |
| Rexx classes extending JavaScript classes: `.js~extend(class, base [, names...])`, as `.net~extend` | Classes |
| Calls from the page to a Rexx object give a Promise of the result, queued as events (they were rejected) | Rexx objects in JavaScript, Rexx from the page |
| Sessions, `rexx.start()`: `eval`, `routine`, `loadPackage`; and `<script type="text/rexx">` | What this is, Events, Rexx from the page, Guarantees |
| `.js~eventLoop` is `.js~runEventLoop`; the event queue explained | Events, Rexx from the page |
| The bridge's own methods start with `js.` (`js.typeOf`, `js.className`, `js.instanceOf`, `js.hasProperty`, `js.propertyNames`, `js.byteString`), as BSF4ooRexx's with `bsf.`; exact names with `js.getStrict`, `js.setStrict`, `js.invokeStrict` (was `invoke`); a function is called with JavaScript's `f~call(this, args...)` | Messages, Pitfalls |
| `.js~newObject(name, value, ...)`, with exact names | Values, Pitfalls |
| A handler is released when JavaScript collects its function (`handler~release` is optional) | Events |
| The pairs of `.js~extend` are released by the collectors, as everything else: no `.js~detach` (it was needed for them) | Classes |
| `ooRexx.js`'s global is `ooRexx` (was `OoRexx`) | Rexx from the page |
| Questions to decide: answered | Questions decided |
| The class's `UNINIT` of a `.js~extend` pair runs in the scope of its class, with the object's variables (it ran without them) | Classes |
| A synchronous handler under Node may use the RexxAPI (queues, external functions) while JavaScript waits for it, and so may other Rexx threads meanwhile (it could hang) | Waiting |
