# RFE #879 update (2), 18 October 2026: a Rexx number out of range is an error

## What changed

Only **patch 7** (`.JSObject`) changed.

### Why

Rexx strings always go to JavaScript as strings; Rexx code that wants a
JavaScript number asks for one, with `.js~num(x)` or `.js~box("Double", x)`
(also `"Float"` and `"Number"`, which read the same way). Until now, a Rexx
number that a double cannot hold became something else without a word:

| Rexx | JavaScript, before |
|---|---|
| `1E+999`, `1.8E+308` | `Infinity` |
| `-1E+999` | `-Infinity` |
| `1E-999` | `0` |
| `-1E-999` | `-0` |

`1E+999` is a finite Rexx number, and `1E-999` is not zero: the value
changed kind, which the bridge avoids everywhere else. The ooRexx bridges
(Python, .NET, Lua, JavaScript) now refuse it the same way.

### What it does now

- **Too large** (the double would be infinite) and **too small** (not zero,
  but the double would be zero) are a `RangeError` in JavaScript, SYNTAX
  98.900 in Rexx, and the message says which:
  `"1E+999" is out of range for a JavaScript number (too large)`,
  `"1E-999" is out of range for a JavaScript number (too small: not zero,
  but it would be 0)`.
- **Asked for by name, an infinity or NaN still works**: `+infinity`,
  `-infinity`, `nan` (the way ooRexx writes them, see the
  [update of this morning](../2026-10-18/update.md)), and JavaScript's
  `Infinity`, `-Infinity`, `NaN`.
- Everything in range converts as before: excess digits are rounded, and a
  number that becomes a subnormal double (`5E-324`) is fine; `0`, `-0`,
  `0E+999` are zeros.

It is one check, in the reading of a `.js~num` value in `wasm/js-realm.js`.

### Where it is written

The specification says so in
[*Values*](../../docs/ooRexx-WASM-and-JavaScript.md#values), with its table
of changes; `wasm/README.md` and the first comment of `wasm/web/js.cls` too.

## Tests

`wasm/tests/js-floats.rex` has 27 checks now (`qualify-node-cli.sh`, and
`web-api.py` in the browser's worker, case "js floats"): too large, too
small, in range, and the same errors through `.js~box`.

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases.

## The patches

[`patches/` at commit 1a48e9b](https://github.com/JosepMariaBlasco/oorexxwasm/tree/1a48e9b/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
