# RFE #879 update, 16 October 2026: errors that keep their information, strings that stay text

## What changed

Only **patch 7** (`.JSObject`) changed, in two ways: errors keep more of
what they carry, in both directions, and a string that is not text is an
error instead of being changed on its way.

### Errors

- **A Rexx condition in JavaScript.** When JavaScript calls Rexx (a
  synchronous handler, a message to a `RexxProxy`, an override of a class
  made by `.js~extend`) and Rexx raises a condition, JavaScript gets a
  `RexxError`, as before, with the same message ("Error 41.1: …"). It now
  also has the condition's fields, as far as the condition has them:
  `condition` ("SYNTAX"), `code` ("41.1", a string), `rc` and `line`
  (numbers), `errorText`, `program`, and `traceback`, the lines Rexx shows,
  joined by "\n". A JavaScript program can act on *which* error it was
  without reading the message.
- **Through Rexx and back.** When JavaScript calls Rexx, which calls
  JavaScript, which throws, and Rexx does not trap it, the `RexxError` that
  comes back to the first JavaScript has the original exception as its
  `cause` (JavaScript's standard place for it): the very object thrown, so
  `e.cause instanceof TypeError` holds. Before, only its text came back.
- **A JavaScript exception in Rexx** is SYNTAX 98.900, as before, and
  `condition("O")~additional` now holds `[1]` the message, `[2]` what was
  thrown (as before) and `[3]` its stack, as text, when it has one. This is
  BSF4ooRexx's layout for a Java exception (message, then the exception
  object). The condition stays 98.900, not BSF4ooRexx's 40.900: calling
  JavaScript is not calling a routine.

### Strings are text

A Rexx string goes to JavaScript read as UTF-8, and a JavaScript string
comes to Rexx as UTF-8. Until now a Rexx string that was not valid UTF-8
was decoded leniently: `'ff'x` reached JavaScript as U+FFFD, and came back
to Rexx as `'EFBFBD'x`, with no error. The same happened the other way to a
JavaScript string that is not well-formed (a lone surrogate, as when
`"😀"` is cut in half). Now both are SYNTAX 98.900, naming the value:

    JavaScript error: TypeError: argument 2 is not valid UTF-8 (byte 1 is 'FF'x):
    a Rexx string goes to JavaScript as text; .js~bytes(s) passes its bytes

Binary data goes as `.js~bytes(s)`, a Uint8Array, as it already could, and
comes back with `~js.byteString`. A string JavaScript expects is text, and
a function that takes any data does not expect a string.

In the direction of JavaScript (a value returned by a Rexx method that
JavaScript called, an argument with a lone surrogate for a `RexxProxy`'s
method), the error is a `TypeError` thrown in JavaScript.

### Where it is written

The specification says so in
[*Values*](../../docs/ooRexx-WASM-and-JavaScript.md#values),
[*Errors*](../../docs/ooRexx-WASM-and-JavaScript.md#errors),
*Pitfalls* and *Guarantees*, with its table of changes;
`wasm/README.md`, the first comment of `wasm/web/js.cls`, and the
description of the records in `wasm/web-js.cpp` too.

## Tests

A new portable test, `wasm/tests/js-errors.rex` (35 checks), runs where
Rexx runs: `qualify-node-cli.sh` runs it under Node, and `web-api.py` in
the browser's worker (case "js errors"). It checks the `RexxError`'s
fields, the `cause` of a round trip (once, twice, and through
`RAISE PROPAGATE`), `additional[3]`, and the text rules both ways: the
byte or code unit named in the message, inside an Array or a Directory, a
property name, `.js~bytes`, and that a `RexxProxy`'s string (shown, not
passed) may still be any bytes. It also passes in Firefox and WebKit.

**Patches 1–6** are byte-identical. **Patch 8** and the example environments
0009–0012 differ only in the hashes and line numbers of the files patch 7
also changes (`wasm/README.md`, the test scripts). The patches apply cleanly
to trunk **r13268**, in order, with `svn patch` or `git apply`. Patches 1–8
alone build and pass their tests: `qualify-node-cli.sh` 29 checks,
and `web-api.py` 51 cases.

## The patches

[`patches/` at commit 42613e3](https://github.com/JosepMariaBlasco/oorexxwasm/tree/42613e3/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
