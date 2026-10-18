# RFE #879 update (4), 18 October 2026: a subclass is read by `SUPPLIER`

## What changed

Only **patch 7** (`.JSObject`) changed, in how the copy of the
[previous update](../2026-10-18-3/update.md) reads a subclass.

### Why

A subclass of Array, Directory or StringTable is copied to JavaScript. The
previous update read it with `ALLINDEXES` and `AT`. A copy should hold what
ooRexx itself enumerates as the object's (index, item) pairs, what
`DO WITH INDEX k ITEM v OVER x` sees, which is what `SUPPLIER` gives; the
ooRexx bridges now agree on this.

### What it does now

- A subclass of **Directory or StringTable** is read with `SUPPLIER`. A
  `SUPPLIER` of its own is honoured; an `AT` of its own only as far as its
  `SUPPLIER` uses it; what it only computes, in `UNKNOWN`, is not copied.
- A subclass of **Array** is read with `DIMENSIONS`, its shape, and
  `SUPPLIER`, its items. `SUPPLIER` gives only the stored items, so the
  shape comes from `DIMENSIONS`, and a slot `SUPPLIER` does not give is
  empty (`undefined`): a 2×3 subclass with only `m[1,1]` is
  `[["a", undefined, undefined], [undefined, undefined, undefined]]`, a
  size-4 one with items at 1 and 3 keeps its size 4.
- The exact classes keep their path. Cycles and sharing are kept as for
  any copy.

## Tests

`wasm/tests/js-arrays.rex` has 30 checks now (`qualify-node-cli.sh`, and
`web-api.py` in the browser's worker, case "js arrays"): besides the
previous ones, an `AT` of its own (not read), a `SUPPLIER` of its own (a
Directory and an Array subclass), and trailing empty slots (2×3 with one
item, 2×3 empty, size 4 with items at 1 and 3).

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases.

## The patches

[`patches/` at commit bb28af4](https://github.com/JosepMariaBlasco/oorexxwasm/tree/bb28af4/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
