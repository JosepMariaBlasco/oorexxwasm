# ooRexx/WASM and JavaScript

October 19, 2026

*Version 2. [Version 1](posted/2026-10-08/ooRexx-WASM-and-JavaScript.md) was posted to the ooRexx developers' list on October 8, 2026; [Changes since version 1](#changes-since-version-1) lists what differs.*

**What is new.** Version 1 described one direction, Rexx using JavaScript, and asked three questions. Version 2 answers them (see [Questions decided](#questions-decided)) and adds the other direction: Rexx objects reach JavaScript, which sends them messages; a page runs Rexx as it runs JavaScript; and a Rexx class can extend a JavaScript class. Readers of version 1 may go straight to the sections that are new, [Waiting](#waiting), [Rexx objects in JavaScript](#rexx-objects-in-javascript), [Rexx from the page](#rexx-from-the-page), [Classes](#classes) and [Command environments](#command-environments), and to the summary of changes at the end. Names changed too: the bridge's own methods now start with `js.`, and arrays count from 1.

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

JavaScript always runs in a "realm", a world with its own global objects. In the browser, ooRexx does not run in the page itself but in a background thread (a Web Worker), so that a long-running Rexx program can never freeze the page. That thread is one realm, `.js`: it has the network (`fetch`), the browser's local database and WebSockets, but cannot touch what is on the screen. What the user sees, the DOM, belongs to another realm, the page's realm, `.js~page`. A JavaScript object of one realm cannot be given to the other (as an argument, or assigned to a property): strings, numbers and booleans travel as values, objects only within their realm.

Under Node there is a single realm, `.js`, which also gives Node's modules (`.js~require("node:fs")`).

In the browser, the page that runs ooRexx must grant each realm (`js: {worker: true, page: true}`). A grant gives the program everything JavaScript can do in that realm.

## Messages

`o~name` reads a property, or calls it when it is a function (a constructor, such as `Map`, is returned instead, so that `.js~Map~new` works); `o~name(a, b)` calls a method; `o~name = v` sets a property that exists. ooRexx uppercases message names, so they are resolved case-insensitively along the prototype chain. Where that is not enough, as with two members whose names differ only in case, the exact name is always available, as with BSF4ooRexx's `bsf.invokeStrict`: `o~js.getStrict("name")`, `o~js.setStrict("name", v)` (which also creates the property) and `o~js.invokeStrict("name", args...)`; on an object that is not an array, `o["name"]` and `o["name"] = v` are exact too. A function is called with JavaScript's own `call`: `f~call(this, args...)`.

The bridge's own methods start with `js.`, as BSF4ooRexx's start with `bsf.`, so that they never hide a JavaScript member of the same name: `el~className` is the element's `className`, and `el~js.className` the name of its JavaScript class. The exceptions are the messages Rexx itself sends for its syntax and protocols (`[]`, `[]=`, `at`, `put`, `new`, `makeArray`, `supplier`), `await`, and, on an array or a typed array, the messages of a Rexx Array that JavaScript's arrays do not have (`items`, `size`, `dimension`, `dimensions`, `hasIndex`; on any other object they are its own members, as before).

On an array or a typed array, `o[i]` and `o[i] = v` (the messages `[]` and `[]=`) count from 1, as in a Rexx Array: `o[1]` is JavaScript's `o[0]`, and 0 is an error. Past the end, an array behaves as a Rexx Array, since it can grow: a position past the end reads `.js~undefined`, and `o[n + 1] = v` appends. A typed array cannot grow, so reading or writing past its end is an error that names its positions (a `RangeError`: "position 4 is past the end of an Uint8Array of 3 elements (positions 1 to 3; a typed array cannot grow)"). `o~at(i)` and `o~put(v, i)` are the same as `o[i]` and `o[i] = v`, as AT and PUT are in Rexx's collections. An array or typed array also answers as a Rexx Array: `o~items` (the slots present, so a sparse array counts as a Rexx Array does), `o~size` and `o~dimension(1)` (its length), `o~dimension` (1), `o~dimensions` (an Array of its length) and `o~hasIndex(i)`. `DO WITH INDEX i ITEM v OVER o` gives the same positions, 1 to n. Lists that are not arrays, such as the DOM's `NodeList`, keep JavaScript's indexing from 0, and so does `DO WITH` over them. JavaScript's own methods keep their meaning: `o~slice(1)`, `o~indexOf(x)`; JavaScript's `at` (which takes negative positions) is `o~js.invokeStrict("at", i)`.

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

JavaScript strings, numbers and bigints come back as Rexx strings, and booleans as `.Boolean~true` and `.Boolean~false` (see below); null as `.nil`, and undefined as `.js~undefined`, a single object, so `x == .js~undefined` tests for it. A number comes back with the shortest digits that read back as the same double, written as ooRexx writes `x + 0` under `NUMERIC DIGITS 17`: plain digits unless the integer part needs more than 17 places or the decimals more than 34 (`1E+17`, `0.0000001`, `1E-35`), and no `.0`, since JavaScript does not tell integers from floats by their text (`1.0` is `1`); `-0` is kept, and NaN and the infinities are `nan`, `+infinity` and `-infinity`, as ooRexx itself writes them (they are not Rexx numbers). `.js~num` reads every one of these forms back, and JavaScript's own `NaN`, `Infinity` and `-Infinity` too. A Rexx number that does not fit a JavaScript number is an error, not an infinity or a zero: `.js~num("1E+999")` and `.js~num("1E-999")` (and `.js~box("Double", x)` and the like) throw a `RangeError`, SYNTAX 98.900 in Rexx, whose message says whether it is too large or too small; an infinity or NaN is asked for by name (`+infinity`, `nan`). A property that does not exist reads as `.js~undefined`; `~js.hasProperty` tells the two apart. Rexx strings always go as strings, so "007" stays "007": `.js~num(x)`, `.js~bigint(x)` and `.js~bytes(x)` (a Uint8Array) force a type, and `.js~undefined` is that value. `.nil` goes as null. An Array goes as an array and a Directory or StringTable as a plain object, both as copies; an Array keeps its size (an empty slot is undefined), and a multi-dimensional Array goes as arrays nested by dimension, the first outermost, so `m[i, j]` is `a[i-1][j-1]` (a 2×3 Array is an array of 2 arrays of 3). A copy keeps the structure: an Array that contains itself is an array that contains itself, Arrays that contain each other keep the cycle, and an Array, Directory or StringTable that appears twice in a value is one object in JavaScript; each value sent (each argument) is copied on its own, and copies nested more than 1000 deep are an error (a RangeError, SYNTAX 98.900 in Rexx). Subclasses of Array, Directory and StringTable are copied too, read with `SUPPLIER`, as `DO WITH INDEX k ITEM v OVER x` sees them (and an Array subclass's shape with `DIMENSIONS`), so a `SUPPLIER` of their own is honoured; what a subclass only computes (in `UNKNOWN`) is not in the copy. Keys go as stored: `d~method` stores `METHOD`, `d["method"]` keeps the case. `.js~ref(x)` sends any Rexx object by reference instead, as a `RexxProxy`: the way to share an Array, Directory or StringTable with JavaScript; `.js~newArray(items...)` and `.js~newObject(directory)` make them in JavaScript instead, held by reference. `.js~newObject(name, value, ...)` makes a plain object from names and values, the names exactly as written: `.js~newObject("method", "POST", "cache", "no-store")`. Any other Rexx object goes by reference, as a `RexxProxy`: see [Rexx objects in JavaScript](#rexx-objects-in-javascript).

Booleans. Rexx has no boolean of its own: `.true` and `.false` are the strings "1" and "0", and JavaScript takes any string but "" as true, "0" too. A boolean is a `.Boolean`: `.Boolean~true` and `.Boolean~false` are "1" and "0" wherever Rexx uses a string (IF, operators, stems), and they go to JavaScript as `true` and `false`; JavaScript's booleans come back as them, so a boolean that goes through Rexx and back is still one. `.js~bool(x)` is `.Boolean~of(x)`, for a Rexx logical value (`.js~bool(a > b)`; anything but 1 or 0 is error 34.900), and `.js~true` and `.js~false` are `.Boolean~true` and `.Boolean~false`. `.Boolean` is the class proposed for the ooRexx core in [RFE #880](https://sourceforge.net/p/oorexx/feature-requests/880/), with JSON's and YAML's booleans as its subclasses; any instance of it or of a subclass goes as a boolean. Until the core has it, `js.cls` requires a verbatim copy of it, `boolean.cls`, which, once loaded, makes `.Boolean` visible everywhere, as a core class would be: also in packages that do not require it themselves.

Strings are text. A Rexx string goes to JavaScript read as UTF-8, and a JavaScript string comes to Rexx as UTF-8. A string that is not text is an error, not a guess: a Rexx string that is not valid UTF-8 (`'ff'x`) and a JavaScript string that is not well-formed (a lone surrogate, as when `"😀"` is cut in half) are SYNTAX 23.900, an invalid data string, naming the value ("argument 2 is not valid UTF-8 (byte 1 is 'FF'x)"); nothing is replaced by U+FFFD. It is not a JavaScript exception, so `additional` has only that message. Binary data goes as `.js~bytes(x)`, a Uint8Array, and comes back with `~js.byteString`.

`.js~box(type, x)` forces a type with the type indicators of BSF4ooRexx's `box()`: `BOolean`, `BYte`, `Char`, `Double`, `Float`, `Int`, `Long`, `Object`, `SHort` and `STring`, and JavaScript's own `Number` and `BIgint`. Case does not matter, and an indicator may be shortened down to its capitals, so `.js~box("bo", 1)` is `.js~box("Boolean", 1)`, which is `.js~bool(1)`. The whole-number types check Java's ranges (`.js~box("BYte", 300)` is an error), `Long` within the integers JavaScript holds exactly; `BIgint` takes any whole number. `.js~unbox(o)` gives back the Rexx value of a box (of a `.Boolean`, "1" or "0"), or of a JavaScript `Number`, `String`, `Boolean` or `BigInt` object.

## Errors

Errors cross the bridge both ways, and what was thrown is kept.

- **JavaScript to Rexx.** A JavaScript exception is SYNTAX 98.900, "JavaScript error: TypeError: …". So is a rejected Promise under `~await`. `condition("O")~additional` holds `[1]` that message, `[2]` what was thrown, and `[3]` its stack, as text, when it has one (an `Error` has; `throw 42` has not).
- **Rexx to JavaScript.** A condition in Rexx code that JavaScript called (a synchronous handler, a message to a `RexxProxy`, an override of a class made by `.js~extend`) is thrown to JavaScript as a `RexxError`, an `Error` whose message is Rexx's ("Error 41.1: …") and whose properties are the condition's, as far as it has them: `condition` ("SYNTAX"), `code` ("41.1", a string), `rc` and `line` (numbers), `errorText`, `program`, and `traceback`, the lines Rexx shows, joined by "\n". In the page, where a call gives a Promise, the Promise is rejected with it. `RexxError` is a global of the realm, for `instanceof`. (A HALT nobody traps reaches JavaScript as SYNTAX 4.1, as it reaches any caller of Rexx.)
- **Through Rexx and back.** A JavaScript exception that goes through Rexx untrapped (JavaScript calls Rexx, which calls JavaScript, which throws) comes back to JavaScript as a `RexxError` whose `cause` is the very object thrown, so `e.cause instanceof TypeError` holds; a thrown primitive comes back as its string. A condition of Rexx's own has no `cause`.
- **Through JavaScript and back.** A condition of Rexx that goes through JavaScript untrapped (Rexx calls JavaScript, which calls Rexx, which raises it; JavaScript lets the `RexxError` through, or catches it and throws it again) is raised in Rexx as itself: the same code, message, `additional`, description and result, not a JavaScript error. So the two round trips meet: a JavaScript exception that crosses Rexx and JavaScript any number of times is still the 98.900 with the very object thrown in `additional[2]`, and its `cause` in JavaScript. A `RexxError` that JavaScript makes itself (`new RexxError(...)`) is a JavaScript exception like any other.
- **Other conditions.** A condition other than SYNTAX (`RAISE USER ... RETURN`, NOTREADY) goes, as in any Rexx program, to the trap of the code that called the code that raised it, past JavaScript if JavaScript is in between: what JavaScript called returns its result (a `CALL ON` trap runs, and JavaScript goes on), and when the trap is a `SIGNAL ON` in the Rexx code that called JavaScript, the call JavaScript is in answers with a `RexxError` ("a condition of Rexx went past this call"), JavaScript finishes (meanwhile any further call of Rexx it makes is refused with a `RexxError`), and then Rexx goes to its trap. If nobody traps the condition, JavaScript gets the result.
- **Nobody to tell.** When JavaScript calls Rexx on its own (a timer, a Node server) it does not wait for the answer, so a condition there is written on the standard error, and so is a `RexxError` an event listener does not pass on.

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

A Rexx object that is not converted (not a string or number, an Array, a Directory or a StringTable, or a subclass of these), or any object given as `.js~ref(x)`, reaches JavaScript by reference, as a `RexxProxy`, the name BSF4ooRexx gives it in Java. JavaScript sends it messages:

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
| `s.addCommandEnvironment(name, fn)`, `s.removeCommandEnvironment(name)` | `.js~addCommandEnvironment(name, fn)`, `.js~removeCommandEnvironment(name)`, `fn` a function of the page (see [Command environments](#command-environments)) |

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

**Debugging the scripts.** With `rexx-debug=1` in the page's address (`page.html?rexx-debug=1`), `ooRexx.js` first loads `ooRexx-debugger.js` from its own directory. That file is a debugger, and it is not part of ooRexx: without it, a warning goes to the console and the scripts run as usual. It sets `ooRexx.debugger`, an object with three methods, each of which may return a Promise: `prepare(options)`, before the session starts, may add to the session's options (files, for instance); `attach(session)` is called once the session has started; and `instrument(name, source)` gives the source to run for each script. The browser distribution of ooRexx/WASM has one, a panel at the foot of the page built on Dom Wise's ooRexx debugger: breakpoints in the scripts and in their handlers, step, the stack and the variables.

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

## Command environments

A JavaScript function can serve an `ADDRESS` environment, as a Rexx object can with `cmdhandler.cls` (command environments written in Rexx) and as the other bridges' host functions do:

```rexx
calc = .js~Function~new("command", "ctx", "return eval(command)")
.js~addCommandEnvironment("CALC", calc)
address calc "6 * 7"; say rc                 -- 42
.js~removeCommandEnvironment("CALC")         -- CALC is an unknown environment again
```

- **The call.** For each command, the function is called as `fn(command, ctx)`, on the Rexx thread that issued the command, which waits for it. What it returns is `RC` (`undefined` or `null`: 0); a Promise (of any realm, or any object with a `then` method) is waited for, and what it gives is `RC`. The function may be of any realm: one of the page's runs in the page.
- **The context.** `ctx` is a `RexxProxy` of the command's context, valid while the command runs: `ctx.lineIn()` (the next line of `WITH INPUT`, `null` at its end), `ctx.lines()`, `ctx.output(x)` and `ctx.error(x)` (a string or an array of lines, to `WITH OUTPUT` and `WITH ERROR`; without them, to the console, as a command's own output), `ctx.isRedirected(kind)` (`"Input"`, `"Output"`, `"Error"`), `ctx.getVar(name)` (`null` when the variable has no value), `ctx.hasVar(name)`, `ctx.setVar(name, value)`, `ctx.dropVar(name)` (simple, stem and compound names), `ctx.variables()`, `ctx.environment()`, `ctx.isValid()`. The tests answer booleans. `return ctx.raiseError(rc)` and `return ctx.raiseFailure(rc)` raise ERROR and FAILURE in the code that issued the command, and `return ctx.raise(condition, rc)` any other condition, as `cmdhandler`'s `raise`; one per command (a second is SYNTAX 93.900); `RC` alone, whatever its sign, raises nothing. In the page, as every call of Rexx there, each call gives a Promise: `await ctx.getVar("X")`.
- **Errors.** A JavaScript exception in the function (or a rejected Promise) is SYNTAX 98.900 in the code that issued the command, with `additional` as for any JavaScript exception; a SYNTAX condition of Rexx that it lets through, from a call of `ctx` or of any Rexx object, is raised there as itself (see [Errors](#errors)). Another condition (`RAISE USER ... RETURN`) raised by Rexx code that the function calls stays in the handler and does not reach the code that issued the command: an open point, with a finding about ooRexx's native API (it does not hand such conditions to native code that calls Rexx).
- **Registering.** `.js~addCommandEnvironment(name, fn)` registers it for the interpreter instance, and registering a name again replaces its handler; `.js~removeCommandEnvironment(name)` removes it, and the name then answers FAILURE with `RC` 30, as an unknown environment; removing a name that has no handler is an error (SYNTAX 93.900). A handler that is `.nil`, or anything but a function, is an error (SYNTAX 93.900). From the page, a session has the same two (see [Rexx from the page](#rexx-from-the-page)), and `rexx.start({commandEnvironments: {CALC: fn}})` registers them before it hands the session over (if one fails, the session is stopped and `start` is rejected with the error).

This is built on `cmdhandler.cls`: a JavaScript handler is a `.CommandHandler`, and `.CommandHandler~deregister(name)` removes it too. `ctx` keeps this JavaScript-style API on top of the context that `cmdhandler` gives a Rexx handler (`caller[name]`, and `caller~input`, `caller~output`, `caller~error` as streams, which exist only with the matching `WITH`).

## Pitfalls

Each of these has a way out, as in BSF4ooRexx:

- **Case-insensitive names can pick the wrong property.** `.js~page~Event` finds `window.event`, the current event, before `window.Event`, the constructor. Use the exact name: `w~js.getStrict("Event")~new("input")`.
- **Rexx's own methods win.** Those of Rexx's Object (`send`, `start`, `copy`, `run`, …) and the few the bridge leaves without `js.` (`at`, `put`, `new`, `makeArray`, `supplier`, `await`) are not passed on to JavaScript. Use the exact form for JavaScript's: `o~js.invokeStrict("send", x)`, and JavaScript's own `at` is `a~js.invokeStrict("at", 0)`.
- **`.true` is a string.** `o~disabled = .false` sends "0", which JavaScript takes as true. Send `.Boolean~false` (or `.js~bool(cond)`).
- **Binary strings are not text.** A Rexx string of bytes (an image, a file read with `charin`) is not UTF-8, and passing it as a string is an error: pass `.js~bytes(s)`, and come back with `~js.byteString`.
- **Directory keys are upper case.** `d~method = "POST"` stores `METHOD`, which a JavaScript options object does not know: use `.js~newObject("method", "POST")`, or `d["method"] = "POST"`.

## Guarantees

- The same JavaScript object is always the same `.JSObject`: `o1 == o2` tests identity.
- Each operation runs on the thread of its realm, so any Rexx thread may use any `.JSObject`.
- `~await` blocks only the Rexx thread that waits; meanwhile that thread runs the page's calls of Rexx, if any come.
- Names are looked up when the message arrives, so a property added later is found.
- What a JavaScript exception threw is kept, in `condition("O")~additional[2]`, and comes back to JavaScript as the `cause` of the `RexxError` if Rexx does not trap it; a condition of Rexx that JavaScript does not trap comes back to Rexx as itself.
- No string is changed on its way: what is not text is an error.
- A JavaScript boolean that goes through Rexx and back is still a boolean.
- A `.JSObject` keeps its JavaScript object alive while Rexx holds it, and no longer.

## Relation to BSF4ooRexx and OLEObject

The design follows Rony Flatscher's BSF4ooRexx, moved from Java to JavaScript: `.JSObject` is to JavaScript objects what `BSF.CLS` is to Java objects. Messages work as with OLEObject on Windows: names are case-insensitive, and `o~name` reads a property or calls a method. As in BSF4ooRexx, arrays count from 1 and `box` takes the same type indicators, so what holds in one bridge holds in the other.

## Questions decided

Version 1 asked three questions. The answers adopted:

1. **Names.** Case-insensitive resolution stays, with an exact form for every operation where it is not enough: `js.getStrict`, `js.setStrict`, `js.invokeStrict`.
2. **Values.** Rexx strings always go as strings, since a Rexx string that looks like a number need not be one; `.js~box` and `.js~unbox` (and `.js~num` and the like) say what is meant.
3. **Events.** The model stays, with the event queue explained and `.js~runEventLoop` named after what it does.

Further replies on the list are very welcome.

## Changes since version 1

| Change | Where |
| --- | --- |
| **Names.** The bridge's own methods start with `js.` (`js.typeOf`, `js.className`, `js.instanceOf`, `js.hasProperty`, `js.propertyNames`, `js.byteString`), as BSF4ooRexx's with `bsf.`; exact names with `js.getStrict`, `js.setStrict`, `js.invokeStrict` (was `invoke`); a function is called with JavaScript's `f~call(this, args...)`; `ooRexx.js`'s global is `ooRexx` (was `OoRexx`) | Messages, Pitfalls, Rexx from the page |
| **Arrays.** Arrays and typed arrays count from 1 with `o[i]`, `~at(i)`, `~put(v, i)` and `DO WITH`; lists keep 0; JavaScript's `at` is `o~js.invokeStrict("at", i)` | Messages, Pitfalls |
| **Values.** undefined comes back as `.js~undefined` (was `.nil`), and a missing property reads as it; `.js~box(type, x)` with BSF4ooRexx's type indicators, and `.js~unbox(o)`; `.js~newObject(name, value, ...)`, with exact names; a string that is not text (not UTF-8, a lone surrogate) is SYNTAX 23.900 (it was changed to U+FFFD); booleans are `.Boolean` both ways (RFE #880; they came back as 1/0), and `.js~bool`, `.js~true`, `.js~false` give `.Boolean`; a multi-dimensional Array goes as nested arrays (it was flattened), and copies keep cycles and sharing (a cycle was cut at 64 levels, silently, as was any deeper nesting); a number's text follows ooRexx's `x + 0` under `NUMERIC DIGITS 17` (it followed JavaScript's `String()`: `1E-7`, `100000000000000000`), `-0` is kept (it became `0`), and NaN and the infinities are `nan`, `+infinity`, `-infinity` (they were `NaN`, `Infinity`, `-Infinity`, which `.js~num` still reads); a Rexx number out of range for a JavaScript number is a `RangeError` for `.js~num` and `.js~box` (it became an infinity or a zero, silently); subclasses of Array, Directory and StringTable are copied, read with `SUPPLIER` (they went by reference), and `.js~ref(x)` sends any object by reference (new); reading or writing past the end of a typed array is an error (it read `.js~undefined`, and a write was lost silently); an array or typed array answers `items`, `size`, `dimension`, `dimensions` and `hasIndex` as a Rexx Array (they read JavaScript properties it does not have) | Messages, Values, Pitfalls, Rexx objects in JavaScript, Guarantees |
| **Errors.** Gathered in one section; a condition in Rexx called by JavaScript is a `RexxError` with the condition's fields (`condition`, `code`, `rc`, `errorText`, `program`, `line`, `traceback`); a JavaScript exception that goes through Rexx and back is its `cause`; `additional[3]` is a JavaScript exception's stack; a condition of Rexx that goes through JavaScript and back is raised again as itself (it became a 98.900 "JavaScript error: RexxError: ..."), with its description and result; a `SIGNAL ON` past JavaScript no longer leaves JavaScript waiting | Errors, Guarantees |
| **Handlers.** Synchronous in the worker's realm and under Node, as `.net~handler` (a comparator for `sort` works), and may use the RexxAPI there; queued in the page and with option `queued`, `latest` or `max n` (new); released when JavaScript collects their function; `.js~eventLoop` is `.js~runEventLoop`, and the event queue is explained | Events, Waiting |
| **Waiting.** Why JavaScript cannot wait for Rexx in the page, and what to do instead | Waiting |
| **Rexx objects in JavaScript.** Any other Rexx object goes as a `RexxProxy` (it went as its string): messages, BSF4ooRexx's `sendMessage` names, identity both ways; from the page, a call gives a Promise of the result | Values, Rexx objects in JavaScript, Rexx from the page |
| **Rexx from the page.** Sessions, `rexx.start()`: `eval`, `routine`, `loadPackage`; and `<script type="text/rexx">`, which `?rexx-debug=1` runs under a debugger (`ooRexx-debugger.js`, `ooRexx.debugger`) | What this is, Rexx from the page |
| **Command environments.** A JavaScript function serves an `ADDRESS` environment: `.js~addCommandEnvironment(name, fn)`, `.js~removeCommandEnvironment(name)`, and from the page `s.addCommandEnvironment` and `start({commandEnvironments})` (new) | Command environments, Rexx from the page |
| **Classes.** A Rexx class extends a JavaScript class with `.js~extend(class, base [, names...])`, as `.net~extend`; the pairs are released by the collectors, and the class's `UNINIT` runs in its scope | Classes |
| **Guarantees** stated, and the three questions of version 1 answered | Guarantees, Questions decided |
