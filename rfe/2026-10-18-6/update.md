# RFE #879 update (6), 18 October 2026: arrays answer as Rexx Arrays

## What changed

Only **patch 7** (`.JSObject`) changed.

### Why

A JavaScript array or typed array reached from Rexx is presented as a Rexx
Array: it counts from 1 and answers `[]`, `at`, `[]=`, `put`, `makeArray`
and `supplier`, so `DO ... OVER` and `DO WITH ... OVER` work. But `items`,
`size`, `dimension`, `dimensions` and `hasIndex` were looked up as
JavaScript properties, which arrays do not have: they gave `.js~undefined`,
and `hasIndex` was an error. The ooRexx bridges now share one list of the
messages a host array answers (BSF4ooRexx's for Java's arrays, plus
`dimensions` and `hasIndex`).

### What it does now

On an array or typed array:

| Message | Gives |
|---|---|
| `o~items` | the slots present (a sparse array counts as a Rexx Array does: `['a', , 'c', 'd']` has 3) |
| `o~size`, `o~dimension(1)` | its length |
| `o~dimension` | 1 |
| `o~dimension(n)`, n > 1 | 0 |
| `o~dimensions` | an Array of its length |
| `o~hasIndex(i)` | 1 if 1 ≤ i ≤ length and the slot is present, else 0 |

On any other object these names are its own members, as before (a `Map`'s
`size`, an object's own `items`). None of them hides a member of
JavaScript's arrays or typed arrays.

### Where it is written

The specification, [*Messages*](../../docs/ooRexx-WASM-and-JavaScript.md#messages),
with its table of changes; `wasm/README.md` and the first comment of
`wasm/web/js.cls` too.

## Tests

`wasm/tests/js-arrays.rex` has 36 checks now (`qualify-node-cli.sh`, and
`web-api.py` in the browser's worker, case "js arrays"): a sparse array, a
typed array, `hasIndex` on a hole, before the start and past the end, and a
`Map` and an object that keep their own `size` and `items`. The
conversion probe measures `o~items` and `o~size` on an array.

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases.

## The patches

[`patches/` at commit aa4ea2a](https://github.com/JosepMariaBlasco/oorexxwasm/tree/aa4ea2a/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
