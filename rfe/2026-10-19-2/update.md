# RFE #879 update (2), 19 October 2026: a Rexx condition through JavaScript comes back as itself

## What changed

In the RFE, only **patch 7** (`.JSObject`) changed.

### Why

A JavaScript exception that goes through Rexx and back to JavaScript was
already the very object thrown (the `RexxError`'s `cause`). The other
direction was not symmetric: a condition of Rexx that went through
JavaScript untrapped (Rexx calls JavaScript, which calls Rexx, which raises
it, and JavaScript lets the `RexxError` through) reached Rexx as a new
SYNTAX 98.900, "JavaScript error: RexxError: Error 41.1: ...", with the
`RexxError` in `additional[2]`, instead of the 41.1 it was. The ooRexx bridges
now agree that a condition of Rexx raised again through the host is itself
(the .NET bridge already did so).

### What it does now

The `RexxError` of a SYNTAX condition carries the condition itself, by
reference and out of sight (it is not one of its properties). When
JavaScript lets it through, or catches it and throws it again, Rexx raises
that condition again: the same code, message and `additional`.

```rexx
f = .js~Function~new("o", "o.add('lots')")      -- o~add does 1 + "lots"
signal on syntax
f~call(.nil, .Thing~new)
syntax: say condition("O")~code                  -- 41.1 (it was 98.900)
```

The two round trips now meet: a JavaScript exception that crosses Rexx and
JavaScript any number of times is still the one SYNTAX 98.900, with the very
object thrown in `additional[2]` and as the `cause` in JavaScript (it used to
pile up as a chain of `RexxError`s, one per crossing). A `RexxError` that
JavaScript makes itself (`new RexxError(...)`) is a JavaScript exception like
any other.

### Where it is written

The specification, [*Errors*](../../docs/ooRexx-WASM-and-JavaScript.md#errors)
and *Guarantees*, with its table of changes; `wasm/README.md`; the reply
record `J` in the first comment of `wasm/web-js.cpp`.

## Tests

`wasm/tests/js-errors.rex` has 41 checks now (`qualify-node-cli.sh`, and
`web-api.py` in the browser's worker, case "js errors"): a 41.1 through
JavaScript and back, a 98.900 raised by Rexx itself, a `RexxError` caught
and thrown again, a JavaScript exception through Rexx and JavaScript twice,
and a `RexxError` made in JavaScript. The case "js handlers sync" of
`web-api.py` now expects the 41.1 of a synchronous handler's method.

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments differ only in the hashes and line numbers of the files patch 7
also changes. The patches apply cleanly to trunk **r13275**, in order, with
`svn patch` or `git apply`. Patches 1–8 alone build and pass their tests:
`qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases.

## Outside the RFE

The example environments changed too, with the ooRexx bridges' common rules
for command handlers:

- **0009** (JDOR): an exception the Java handler does not throw (a bug of
  the port, or a failure of the browser) is now SYNTAX 98.900, with the
  thrown object and its stack, instead of ERROR -102; what the Java handler
  throws stays ERROR -102.
- **0010** (`cmdhandler`): `.CommandHandler~unregister(name)` removes a
  handler (the name then answers FAILURE, RC 30, as an unknown
  environment), and registering `.nil` is an error (it removed the
  handler); the native handler is added once per name.
- **0013** (new): command environments written in JavaScript,
  `.js~addCommandEnvironment(name, fn)` and
  `.js~removeCommandEnvironment(name)`, on `cmdhandler`; see
  [*Command environments*](../../docs/ooRexx-WASM-and-JavaScript.md#command-environments).

## The patches

[`patches/` at commit cd5145e](https://github.com/JosepMariaBlasco/oorexxwasm/tree/cd5145e/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [the update of 19 October](../2026-10-19/update.md) still
hold.
