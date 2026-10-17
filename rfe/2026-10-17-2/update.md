# RFE #879 update (2), 17 October 2026: a multi-dimensional Array keeps its shape

## What changed

Only **patch 7** (`.JSObject`) changed.

### Why

A Rexx Array goes to JavaScript as an array, a copy. A multi-dimensional
Array went flattened, in the order of its storage, without an error and
without a word in the documentation: JavaScript received a list of 4 where
Rexx had a 2×2 matrix, and could not tell. The shape of an Array is
information, and the bridge chooses the JavaScript type itself, so it
should not lose it.

### What it does now

- A multi-dimensional Array goes as arrays **nested by dimension**, the
  first outermost: `m[i, j]` is `a[i-1][j-1]`, and a 2×3 Array is an array
  of 2 arrays of 3 (three levels for three dimensions, and so on). This is
  how JavaScript writes a matrix, so nothing has to be learned.
- An empty slot is `undefined`, as in a one-dimensional Array, and a
  dimension of size 0 gives empty arrays: `.array~new(2, 0)` is `[[], []]`.
- An Array that grew (`m[3, 1] = x` on a 2×2) goes with its dimensions as
  they are then.
- A one-dimensional Array is unchanged: it keeps its size, its empty slots
  are `undefined`.
- The way back is unchanged: a JavaScript array (of arrays or not) comes to
  Rexx by reference, as a `.JSObject`.

The items are read with `AT` by their indexes, not by their place in the
Array's storage (where the first index varies fastest).

### Where it is written

The specification says so in
[*Values*](../../docs/ooRexx-WASM-and-JavaScript.md#values), with its table
of changes; `wasm/README.md` and the first comment of `wasm/web/js.cls` too.

## Tests

A new portable test, `wasm/tests/js-arrays.rex` (10 checks), run by
`qualify-node-cli.sh` and, in the browser's worker, by `web-api.py` (case
"js arrays"): one-dimensional and sparse Arrays, 2×2, 2×3 (which index is
outermost), 2×2×2, a dimension of size 0, an Array that grew, inside a
Directory and inside an Array, and a JavaScript array of arrays coming back
by reference.

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 32 checks, and `web-api.py` 53 cases.

## The patches

[`patches/` at commit a9ddbf3](https://github.com/JosepMariaBlasco/oorexxwasm/tree/a9ddbf3/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
