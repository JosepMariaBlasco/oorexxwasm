# RFE #879 update (5), 18 October 2026: past the end of a typed array

## What changed

Only **patch 7** (`.JSObject`) changed.

### Why

A JavaScript array or typed array reached from Rexx counts from 1, as a
Rexx Array. Past the end, a JavaScript array behaves as a Rexx Array, since
it can grow: `a[4]` of three reads `.js~undefined`, and `a[4] = v` appends.
A typed array (`Uint8Array` and the like) cannot grow, and it behaved as if
it could: `t[4]` read `.js~undefined`, and `t[4] = v` or `t~put(v, 4)` was
lost without a word (JavaScript ignores a write past the end of a typed
array).

The ooRexx bridges now share one rule: *past the end, a host array behaves
as its host allows*; if it cannot grow, reading and writing there are an
error that says which positions exist (as BSF4ooRexx does for Java arrays,
and the .NET bridge for .NET's).

### What it does now

Reading or writing past the end of a typed array is a `RangeError`,
SYNTAX 98.900 in Rexx: `position 4 is past the end of an Uint8Array of 3
elements (positions 1 to 3; a typed array cannot grow)`. Arrays are
unchanged. Position 0 was already an error for both.

### Where it is written

The specification, [*Messages*](../../docs/ooRexx-WASM-and-JavaScript.md#messages),
with its table of changes; `wasm/README.md` and the first comment of
`wasm/web/js.cls` too.

## Tests

`wasm/tests/js-arrays.rex` has 32 checks now (`qualify-node-cli.sh`, and
`web-api.py` in the browser's worker, case "js arrays"): an array grows
past its end; reading, writing and `PUT` past the end of a `Uint8Array`
are errors with that message, and its length stays 3.

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases.

## The patches

[`patches/` at commit 23a9272](https://github.com/JosepMariaBlasco/oorexxwasm/tree/23a9272/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
