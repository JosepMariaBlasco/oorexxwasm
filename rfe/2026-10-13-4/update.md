# RFE #879 update, 13 October 2026 (4): the UNINIT of a `.js~extend` pair sees its variables

## What changed

Only **patch 7** (`.JSObject`) changed, and only in `js.cls`, a test and the
README.

When a pair of `.js~extend` is over, the bridge runs its class's `UNINIT`
(see [update (2)](../2026-10-13-2/update.md)). It saved that method when
the pair was made, and ran it with `self~run(method)`. `Object`'s `RUN`
runs a method without the scope of the class that defines it, which had two
consequences:

- the `UNINIT` did not see the object's variables, which is usually what it
  needs, for example to close what the object holds;
- if the class had a method named `RUN` (for example, an override of a
  JavaScript `run()`), that method was called instead.

The bridge now sends `UNINIT` with the class that defines it as the scope.
The method runs in its own scope, also when a superclass defines it, and
the `NOP` that stands in for the object's own `UNINIT` is passed over.

The ooRexx/Python bridge, which ported the scheme of the pairs, found the
problem.

The specification says so in
[*Classes*](../../docs/ooRexx-WASM-and-JavaScript.md#classes) ("Lifetime"),
with a row in its table of changes.

## Tests

`wasm/tests/js-extend-gc.rex` has 9 checks (it had 8). The `UNINIT` of its
class now counts a pair only if it sees a variable that the `INIT` set. A
new check uses a subclass that inherits that `UNINIT` and has a method
named `RUN` of its own. Before the change, 4 checks failed: the `UNINIT`
never counted, and `RUN` was called 50 times. Now all 9 pass.

**Patches 1–6** are byte-identical, and **patch 8** differs only in the
hashes of two files it also changes. The patches apply cleanly to trunk
**r13268**, in order, with `svn patch` or `git apply`. Patches 1–8 alone
build and pass their tests: `qualify-node-cli.sh` 28 checks, and
`web-api.py` 49 cases.

## The patches

[`patches/` at commit 428a68a](https://github.com/JosepMariaBlasco/oorexxwasm/tree/428a68a/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3)](../2026-10-13-3/update.md) still hold.
