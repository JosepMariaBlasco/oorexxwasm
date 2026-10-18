# RFE #879 update (3), 18 October 2026: subclasses are copied; `.js~ref`

*How a subclass is read changed the same day: by `SUPPLIER`, not `AT`; see [update (4)](../2026-10-18-4/update.md).*

## What changed

Only **patch 7** (`.JSObject`) changed.

### Why

A Rexx Array goes to JavaScript as an array, and a Directory or StringTable
as a plain object, both as copies: that is what JavaScript's APIs expect of
an options object, what structured clone (`postMessage`, IndexedDB) can
take, and the only thing the page's realm, which cannot wait for Rexx, can
read. But a **subclass** of these classes went by reference, as a
`RexxProxy`, only because the bridge tested the exact classes: a
`.Properties` (a Directory) or `.MyArray~of(1, 2)` arrived as something
`JSON.stringify` shows as `{}`. And there was no way to send a plain
Directory by reference when sharing it was what one wanted.

### What it does now

- **Subclasses are copied too**: of Array (any number of dimensions),
  Directory and StringTable. A subclass is read **by messages**,
  `ALLINDEXES` and `AT` for Directory and StringTable, `DIMENSIONS` and
  `AT` for Array, so an `AT` of its own is honoured (an `AT` that
  upper-cases gives `{"a": "X"}`). What a subclass only computes, in
  `UNKNOWN`, is not one of its entries and is not in the copy. The exact
  classes keep the native path, which is faster.
- **`.js~ref(x)`** sends any Rexx object by reference, as a `RexxProxy`: the
  way to share an Array, Directory or StringTable with JavaScript. What
  JavaScript does through it (`x.put("v", "k")`) is done to the Rexx
  object; the same object is the same `RexxProxy`, and given back to Rexx
  it is the object itself.
- **Keys go as stored**, as before: `d~method = "POST"` stores `METHOD`,
  `d["method"] = "POST"` keeps the case.

The ooRexx bridges (Python, .NET, Lua, JavaScript) agree on this: where a
bridge copies a Directory or StringTable, it copies their subclasses the
same way.

### Where it is written

The specification says so in
[*Values*](../../docs/ooRexx-WASM-and-JavaScript.md#values) and in
[*Rexx objects in JavaScript*](../../docs/ooRexx-WASM-and-JavaScript.md#rexx-objects-in-javascript),
with its table of changes; `wasm/README.md` and the first comment of
`wasm/web/js.cls` too.

## Tests

`wasm/tests/js-arrays.rex` has 28 checks now (`qualify-node-cli.sh`, and
`web-api.py` in the browser's worker, case "js arrays"): Array subclasses
of one and two dimensions, sparse; Directory and StringTable subclasses; an
`AT` of its own in a Directory and in an Array subclass; an entry computed
in `UNKNOWN`; `.js~ref` of a Directory (JavaScript's change seen in Rexx)
and of an Array, identity both ways.

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases.

## The patches

[`patches/` at commit 572afee](https://github.com/JosepMariaBlasco/oorexxwasm/tree/572afee/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
