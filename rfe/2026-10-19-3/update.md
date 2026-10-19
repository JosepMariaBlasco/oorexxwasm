# RFE #879 update (3), 19 October 2026: conditions through JavaScript, the rest

## What changed

In the RFE, only **patch 7** (`.JSObject`) changed, completing
[update (2)](../2026-10-19-2/update.md).

### A SYNTAX condition keeps its description and result

A SYNTAX condition of Rexx that goes through JavaScript and back was raised
again with its code and `additional`, so with the same message, but without
the description and result that `RAISE SYNTAX ... DESCRIPTION ... RETURN`
can give it. It has them now: the condition Rexx sees is the one it would
see with no JavaScript in between.

### Other conditions, and SIGNAL ON past JavaScript

A condition other than SYNTAX (`RAISE USER ... RETURN`, NOTREADY) goes, as
in any Rexx program, to the trap of the Rexx code that called the code that
raised it, past the native code of the bridge and past JavaScript: what
JavaScript called returns its result, and a `CALL ON` trap runs and lets
JavaScript go on. This was already so; it is now tested and written down.

But a `SIGNAL ON` trap in the Rexx code that called JavaScript made Rexx
unwind through the bridge while JavaScript was still waiting for the call
it was in: JavaScript went on waiting, and the request of the thread that
had called JavaScript was left half done (a later JavaScript `await`
misbehaved). Now the call JavaScript is in answers with a `RexxError`
("a condition of Rexx went past this call, to a trap of the code that
called JavaScript"), JavaScript finishes what it was doing, and then Rexx
goes to its trap. The same holds for a call from the page, taken by a
thread that waits for the page or for events.

### Where it is written

The specification, [*Errors*](../../docs/ooRexx-WASM-and-JavaScript.md#errors),
with its table of changes.

## Tests

`wasm/tests/js-errors.rex` has 46 checks now: a SYNTAX condition with a
description and a result through JavaScript and back; a USER condition
through JavaScript with the caller's `SIGNAL ON` and `CALL ON`, and with no
trap (JavaScript gets the result); after the `SIGNAL ON`, JavaScript was
told and goes on. `web-api.py` has a case "js page signal": the same `SIGNAL
ON` past a call from the page.

**Patches 1–6 and 8** are byte-identical. The patches apply cleanly to
trunk **r13275**, in order, with `svn patch` or `git apply`. Patches 1–8
alone build and pass their tests: `qualify-node-cli.sh` 33 checks,
and `web-api.py` 55 cases.

## Outside the RFE

- **0009** (JDOR): a thrown value that is not an object (`throw "x"`,
  `throw null`) is SYNTAX 98.900 too, as any unexpected exception.
- **0013**: a Promise of another realm or context, or any object with a
  `then` method, is waited for; `start({commandEnvironments})` stops the
  session and is rejected when a registration fails. More tests: a negative
  RC, `ctx.error` to the console, the page's handlers letting a Rexx
  condition through and calling `ctx.raiseError`, a negative RC from the
  page, removing a missing name from the page, a Rexx handler raising a
  USER condition. A USER condition raised by Rexx code that a JavaScript
  handler calls does not reach the code that issued the command yet (an
  open point, with a finding about ooRexx's native API).

## The patches

[`patches/` at commit c135bf1](https://github.com/JosepMariaBlasco/oorexxwasm/tree/c135bf1/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`: the results of
[the update of 19 October](../2026-10-19/update.md) still hold (the suite
ran again today on the six platforms, on the patches of update (2): no
regressions; a timing check of BEEP failed once under Node and passed when
run again, and is now listed as flaky).
