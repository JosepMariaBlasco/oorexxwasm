# ADDRESS DOM and ADDRESS FETCH

*Written 07/10/2026; describes patches 0008 (cmdhandler: command environments
written in Rexx), 0009 (ADDRESS FETCH) and 0010 (ADDRESS DOM) of the current
series, none of which is part of the RFE. Context: `jsobject-design.md`.
Model: Rony G. Flatscher's JDOR (an ADDRESS environment over Java2D, part of
BSF4ooRexx; its web version is patch 0006).*

## Why ADDRESS when there is `.JSObject`

`.JSObject` is for people who think in objects and know JavaScript's APIs.
ADDRESS is classic Rexx: commands as text, RC, `WITH INPUT/OUTPUT`, no
objects, no case to respect, no need to know `document.querySelector`
exists. It is what JDOR does over Java2D; ADDRESS DOM and FETCH are its
cousins. A Rexx student who has never seen JavaScript can make an
interactive page.

## Three layers

1. `.JSObject` (patch 0007), the base.
2. Command handlers written in Rexx (patch 0008), a general mechanism,
   useful far beyond JavaScript.
3. ADDRESS FETCH and ADDRESS DOM (patches 0009 and 0010), written in Rexx
   on top of the two.

FETCH and DOM are **samples**: they show what the two general layers make
possible, and are not proposed as standard environments. Their conventions
(below) belong to them, not to every handler. Their files currently install
next to `js.cls` (`/usr/lib/ooRexx`); where samples like these should live
is an open question.

## Layer 1: command handlers written in Rexx (patch 0008)

ooRexx command handlers are native only (`RexxContextCommandHandler`,
`RexxRedirectingCommandHandler` in oorexxapi.h), but they can be registered
at run time with `AddCommandEnvironment` (as `web-jdor.cpp` does for JDOR).
A small native piece makes any Rexx object a command environment. This is
what BSF4ooRexx exposes from Java (`RexxRedirectingCommandHandler`
implemented in Java, used by JDOR). Something like `::COMMAND` /
`::ENVIRONMENT` directives would be a core RFE of its own; this layer needs
none of that.

### Not a BIF: an extension package

BIFs are the language's closed set (a core change, documented as language,
and a new BIF would shadow existing external routines of the same name:
silent breakage). Everything layer 1 needs is public native API
(`AddCommandEnvironment` at run time, the exit context's
Get/Set/DropContextVariable, the I/O redirector context), so it is an
**extension package with a native library**, like rxsock:
`extensions/cmdhandler/` (`cmdhandler.cpp` + `cmdhandler.cls`). No line of
the interpreter proper is touched, only the WASM embedded-package table
(`interpreter/package/PackageManager.cpp`) and CMake. It could be proposed
to ooRexx as an optional extension, and moved to the core later if wanted.

### API

```rexx
::requires "cmdhandler.cls"
.CommandHandler~register("DEMO", obj)    -- obj isA .CommandHandler; .nil removes
-- each command: obj~command(command, context) -> RC (0 if nothing returned)
```

- **`.CommandHandler` is a required mixin**: `::class CommandHandler public
  mixinclass Object`, with COMMAND abstract. `register` refuses (SYNTAX
  93.900) any handler that is not `isA(.CommandHandler)`, even one that
  understands COMMAND. A handler with another superclass is written
  `subclass X inherit CommandHandler`; the hierarchy documents itself.
- **Input, output and error**: all three redirections (ooRexx 5 has WITH
  ERROR); input read line by line (`ReadInput`).
- **The caller's variables**: a handler can read and change them, as
  classic subcommand handlers could through the variable pool (JDOR
  resolves nicknames through them). No convention restricts a handler to
  the variables its command names: classic designs such as a SQL fetch that
  sets one variable per column, or ISPF's tables and panels, do not follow
  one. (FETCH and DOM happen to touch only FROM / INTO / stem names.)

`.CommandContext` (valid only while its command runs; afterwards SYNTAX
98.900): `~lineIn` (.nil at end / no WITH INPUT), `~lines`, `~output(s|coll)`,
`~error(s|coll)` (to .output / .error when not redirected, like a real
command's console output), `~isRedirected("Input"|"Output"|"Error"|"Same")`,
`~getVar` (.nil if unset), `~hasVar`, `~setVar`, `~dropVar` (simple, stem,
compound; tails resolved in the caller; bad names raise SYNTAX 93.900, since
the API silently ignores them), `~variables` (Directory), `~raiseError(rc)` /
`~raiseFailure(rc)` (return rc; the native handler raises the condition
after the method returns, with RC), `~environment`, `~isValid`. A SYNTAX
error in `~command` reaches the caller. Unregistered name: FAILURE RC 30
(RXSUBCOM_NOTREG, as the core does for an unknown environment).

Registrations are per interpreter instance, as the environments themselves:
they are kept in `.local~CommandHandlers` (Directory name -> object), with
the current context in `.local~CommandContext`. A first version used a C++
map keyed by (RexxInstance*, name) with global references; `.local` leaves
no stale entries when an instance ends and nothing for the GC to miss
(ooRexx does not protect .local / .environment from programs anyway).
`extensions/cmdhandler/tests/instances.cpp` checks two instances in one
process, interleaved, one terminated, and a new one (RC 30), natively.

Tests: `wasm/tests/cmdhandler.rex`, 33 checks (RC, variables incl. compound
tails / stems / procedures, the three redirections, Same, ERROR / FAILURE
trapped and untrapped, SYNTAX propagation, stale context, nested handlers,
another thread, re-register, unregister, refusal of objects that are not
`.CommandHandler`s even when they understand COMMAND). Also native: all
pass.

## Conventions shared by FETCH and DOM

### `.CommandWords`, the shared tokenizer

`wasm/web/commandwords.cls` (patch 0009) is the tokenizer both environments
use. It is deliberately not part of cmdhandler: anybody can PARSE, and FROM /
INTO are these samples' conventions, not every handler's, so cmdhandler
stays only the mechanism.

- arguments separated by blanks; **quotes** for arguments with blanks
  (`"..."` or `'...'`, the quote doubled to escape it); strict tokenizing,
  as Rexx's; no "rest of the line" rule; quoted words are never keywords;
- **`FROM name`** (`~takeValue`): a value taken from the caller's variable,
  wherever a value goes, e.g. `'TEXT FROM msg'` (no quoting problems at
  all);
- **`INTO name`** (`~takeInto`): a value returned into the caller's
  variable. It may stand anywhere after the command's name
  (`POST url INTO answer JSON FROM order`); it is a keyword only unquoted and
  followed by an unquoted name (a quoted "INTO" is data); one per command (a
  second is refused, -3). An earlier design required INTO to come last; with
  FROM allowed anywhere, tying INTO to the end was inconsistent.
- case: Rexx users know unquoted words are uppercased, so this is not a
  trap.

### Values come back through INTO, not RC

**RC is always numeric** (an object in RC is possible, as JDOR sometimes
does, but awkward). Values come back through `INTO name`, or, without INTO,
through WITH OUTPUT, or the console when not redirected (useful in rexxtry).
`INTO stem.` gives collections as a stem (EXECIO's .0 .. .n). Otherwise
**INTO gives the most natural ooRexx value**, not a Classic Rexx one:
strings for scalars, a `.JSObject` for an element (`LOCATE #map INTO el`: a
bridge to .JSObject), Arrays for collections, json.cls objects for JSON.

### RC

0 ok; **positive** = the command was right but the outcome is not the
expected one, raises ERROR (LOCATE not found = 2, as XEDIT; an HTTP status);
**negative** = the program is wrong (unknown command, bad arguments, unknown
element in a label), raises FAILURE (in line with JDOR's -1 / -3).

### WITH belongs to the ADDRESS instruction

A bare `"GET" url with output stem b.` is a concatenation and reaches the
handler as "GET url WITH OUTPUT STEM B.". Commands that redirect must be
written `address fetch "GET" url with output stem b.` (or set default
redirections with `address fetch with output stem b.`, which then apply to
every command). With INTO this is rarely needed.

## ADDRESS FETCH (patch 0009; browser and Node)

`wasm/web/fetch.cls`, Rexx over `cmdhandler.cls`, `commandwords.cls` and
`js.cls`; the whole command set is documented in its header.

```rexx
address fetch
"HEADER Accept application/json"
"GET https://api.example.com/items INTO body"
"JSON items.1.name INTO first"
"POST https://api.example.com/items INTO answer JSON FROM order"
"SAVE https://example.com/logo.png logo.png"      -- binary to a file
"HEADERS INTO h"                                  -- last response's headers
```

- headers persist in the environment (as JDOR's current colour);
- **URL and file names are one word each**; extra words are an error
  (FAILURE -3), never part of a URL;
- `TIMEOUT seconds` (AbortSignal.timeout);
- browser: CORS applies (the worker's fetch), and the site's cookies go with
  it: the same grant as `.js` (worker realm).

Values:

- `GET url INTO v` gives the body as text; `INTO v.` as lines. Without INTO
  the body goes only to WITH OUTPUT: when not redirected it is just kept (for
  JSON), since printing it, as a command's console output would, flooded the
  console in practice. (cmdhandler's `~output` still writes to .output when
  not redirected; FETCH checks `isRedirected` itself.)
- `STATUS INTO s`; `HEADERS INTO v` gives a StringTable; `HEADERS name INTO
  v` gives one header ("" when absent, RC 0).
- **JSON uses ooRexx's json.cls**: `JSON INTO data` gives the whole body as
  `.json~fromJSON` gives it (Directory / Array / .nil / .JsonBoolean);
  `JSON path INTO v` is a shortcut over those objects, the path being names
  and 1-based indexes separated by dots. Without INTO, strings are output as
  they are and anything else as JSON text (`null`, `true`). FETCH's JSON part
  is pure Rexx; only the HTTP request needs JavaScript. json.cls speed: 20001
  numbers in 0.23 s under WASM, 0.14 s native.
- `POST url JSON FROM d` serializes with `.json~toJSON` and sets
  Content-Type application/json unless a HEADER set one; `POST url value` /
  `POST url FROM var` send a string.

RC: 0 for 2xx; the HTTP status otherwise (ERROR); 1 JSON path missing, 2 no
JSON body / not JSON / no response yet (ERROR); -1 network error, with the
reason on WITH ERROR or the console; -3 unknown command or bad arguments;
-4 SAVE cannot write (FAILURE).

Tests: `wasm/tests/fetch.rex` + `fetch-server.py`, 44 checks (methods,
bodies, request/response headers, JSON INTO and paths, INTO anywhere, 404 →
ERROR, network error, TIMEOUT, unknown command, SAVE bytes, HEAD), run under
Node by `qualify-node-cli.sh` and in the browser by `web-api.py`
(cross-origin, with CORS preflight). Browser tests against real public APIs
proved unreliable behind an intercepting HTTPS proxy that randomly answered
cross-origin requests with an error lacking CORS headers; the same tests
under Node work.

## ADDRESS DOM (patch 0010; browser, page realm)

`wasm/web/dom.cls`, Rexx over `cmdhandler.cls`, `commandwords.cls` and
`js.cls`.

```rexx
address dom
'NEW "My panel"'                   -- a floating panel, the root
'CREATE out p'                     -- an element with the nickname OUT
'out: TEXT "Hola desde Rexx"'
'out: STYLE color red'
'BUTTON ok "Press me" OK'          -- a button; its click is event OK
'FIELD name "Your name"'
'WAIT INTO ev'                     -- waits for an event
if ev~name = "OK" then do
  'name: VALUE INTO v'; say "you typed" v
end
```

### Audience

A core close to the DOM (elements, attributes, styles) plus a few
high-level commands (tables, lists, forms) on top.

### Where it draws: a root

Every command works inside the current root, and selectors only search
inside it. The default root is chosen by the embedder: on one's own page the
body, or `dom: {root: "#app"}` in ooRexx.js; it reaches the program as the
environment variable ORX_DOM_ROOT ("none" for null). The playground uses
`dom: {root: null}`: no root until NEW, which makes programs more readable.

- `NEW [title] [AS nickname] [INTO el]` creates a floating panel (title,
  movable, closable; several allowed, as JDOR's windows) in a **Shadow DOM**
  (CSS isolated both ways, selectors naturally confined) and makes it the
  root. AS names the panel so that `ROOT nickname` can go back to it.
- `ROOT PAGE` is the explicit way out to the whole page.

### Naming: a current element, as in XEDIT

There is a *current element*; an element can be referred to by nickname or
by CSS selector, and `LOCATE` moves the current element there.

**Label syntax for a one-off target**: `'out: TEXT hola'`,
`'#id: TEXT hola'`, `'"#form input": TEXT x'`. The label is the first token,
ending at its last `:` before the first blank (so `li:first-child: TEXT x`
works); a nickname is looked up first, else it is a selector; **the label
does not move the current element** (LOCATE does). To be documented
prominently: a label written outside the quotes (`out: 'TEXT hola'`) is a
real Rexx label, and the command silently goes to the current element.

Nicknames are upper case, as Rexx words are.

### Command set

About 23 commands, aimed at three demos (weather with a UI, a to-do panel, a
simple form):

- root and navigation: `NEW`, `ROOT PAGE | nickname`, `LOCATE ref [INTO el]`
  (RC 2 not found), `UP`, `TOP`, `CLOSE`;
- core: `[ref:] CREATE nickname tag [text] [INTO el]` (nickname `-` for
  none), `REMOVE`, `CLEAR`, `TEXT`, `VALUE`, `ATTR name` (each
  `v | FROM var | INTO var`), `STYLE property value`, `CLASS +a -b c` (`+a`
  and `c` add, `-b` removes; no toggle), `SHOW` / `HIDE`, `ENABLE` /
  `DISABLE`, `FOCUS`, `CSS`;
- high level: `FIELD nickname [label] [type]`, with type TEXT (default),
  PASSWORD, NUMBER, EMAIL, DATE, CHECKBOX (VALUE 1/0) or TEXTAREA;
  `BUTTON nickname "text" [NAME]` (with NAME: its ON click);
  `[ref:] TABLE [HEADER] FROM var` (an Array of Arrays, an Array of
  tab-separated lines, a stem, or WITH INPUT with tab-separated columns);
  `[ref:] LIST FROM var`. TABLE / LIST on a table / ul element replace its
  rows; on anything else they append a new one;
- events: `ON`, `OFF`, `WAIT`.

CREATE, FIELD, BUTTON, TABLE and LIST **do not move the current element**:
having to write UP after each one would be tedious.

There is no HTML command: this is a proof of concept, and it would bring an
injection risk.

### Events: build, WAIT, look, act

The ISPF DISPLAY / XEDIT READ model, with no callbacks:

```rexx
do forever
  'WAIT INTO ev'
  select
    when ev~name = "OK"    then ...
    when ev~name = "CLOSE" then leave
  end
end
```

- `[ref:] ON event NAME [options]` (the name is mandatory; one name may
  serve several elements), `OFF event`. Options: LATEST (only the latest
  event kept, for mousemove), PREVENT (preventDefault), STOP
  (stopPropagation). Defaults: a form's `submit` is always
  preventDefault'ed; the pseudo-event `enter` is Enter in a field; NEW's
  panel raises `CLOSE`.
- `WAIT [seconds] INTO ev`: RC 0 an event, 1 time over (no condition).
  **`ev` is an object**, a `.DomEvent`: `~name`, `~target` (nickname or
  .nil), `~value`, `~key`, `~x`, `~y`, and `~element` and `~jsEvent`
  (.JSObjects: the bridge for whatever the commands do not give). Event
  names and nicknames are upper case (`ev~name = "OK"`, `ev~target`).
- Underneath, ON is `.js~handler` and WAIT is `.js~nextEvent`. WAIT
  dispatches (`~dispatch`) events that are not its own (`.js~handler`,
  another DOM handler) and keeps waiting; a DOM event taken by someone
  else's `.js~eventLoop` is queued (`~fire`) for the next WAIT. So ADDRESS
  DOM and `.js` handlers coexist.

### Appearance and panels

The Shadow DOM keeps the page's CSS out, so:

- a small built-in stylesheet makes FIELD / BUTTON / TABLE / LIST look good
  with no styling at all (IBM Plex, as the playground; light/dark by
  prefers-color-scheme; zebra tables; sober fields and buttons; class `row`
  for side by side; empty p / headings / tables hidden). It is kept in
  dom.cls as a `::RESOURCE` (panel.css);
- the `CSS` command adds rules to the panel's sheet (WITH INPUT or FROM), so
  that `CLASS` is useful; `STYLE` is for one-off touches.

Panels are built by a small JavaScript function kept in dom.cls as a
`::RESOURCE` (panel.js) and made with the page's `Function` constructor. A
page with a Content Security Policy without 'unsafe-eval' therefore cannot
show panels (to be noted in the documentation). The close button removes
the panel at once (even after the run ends) and then raises CLOSE. Panels
follow the system's light/dark preference (prefers-color-scheme), not the
playground's own switch. In the playground, panels stay after a run and are
removed when the next run starts.

### RC

0 ok; 1 WAIT time over (no condition); 2 LOCATE not found / UP at the root
(ERROR); -1 no page realm, -2 no root / current element, -3 wrong command
or arguments (including a bad selector), -4 a label / ref that names
nothing, -5 a JavaScript error (FAILURE).

### Tests and samples

`wasm/tests/dom.rex`, 64 checks in Chromium (events made from Rexx, so
nobody is needed at the page), plus 3 cases in `web-api.py` (no page realm
→ RC -1; default root = body; `dom: {root: "#log"}`). The playground has a
group "The page, the classic way (ADDRESS)" with three samples: A form
(`dom-form.rex`), To do (`dom-todo.rex`) and Weather, DOM + FETCH
(`fetch-weather.rex`, Open-Meteo geocoding + forecast, a table of 5 days).
The `.JSObject` to-do sample ("Events from the page") remains alongside the
ADDRESS DOM one.

## Pitfalls (for the documentation)

- `.JSObject~className` is the JavaScript class name, not the `class`
  attribute: use `el["className"]`.
- Case-insensitive names pick `window.event` over `window.Event`: use
  `w["Event"]`.
- A Directory built with `d~method = x` has upper-case keys: JavaScript
  options objects need `d["method"] = x`.
- Rexx `|` and `&` evaluate both sides.
- A Rexx label outside the quotes (`out: 'TEXT hola'`) is not a DOM label
  (see above), and `WITH` outside the ADDRESS instruction is just text.
