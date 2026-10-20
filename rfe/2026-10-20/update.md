# RFE #879 update, 20 October 2026: on r13278, booleans are ooRexx's `.LogicalWrapper`

## What changed

[RFE #880](https://sourceforge.net/p/oorexx/feature-requests/880/) is in
trunk: r13276–r13278 add `.LogicalWrapper`
(`extensions/logicalwrapper/logicalwrapper.cls`), with `json.cls`'s
`.JSONBoolean` and `yaml.cls`'s `.YamlBoolean` as its subclasses. The
series now has **trunk r13278** as its base, and patch 7 uses that class
instead of carrying its own copy.

- **Patch 7** (`.JSObject`): `js.cls` requires `logicalwrapper.cls`.
  Booleans are `.LogicalWrapper` both ways: a JavaScript boolean comes back
  as `.LogicalWrapper~true` or `.LogicalWrapper~false`, and any
  `.LogicalWrapper` goes to JavaScript as a boolean, a subclass included,
  so `.json~true` and the booleans `json.cls` and `yaml.cls` read do too.
  `.js~bool(x)`, `.js~true` and `.js~false` give `.LogicalWrapper`. The copy
  of the proposed class (`wasm/web/boolean.cls`), its tests
  (`wasm/tests/boolean-test.rex`) and the rules that installed it are gone;
  there is no `.Boolean` any more. One difference: the copy put `.Boolean`
  in `.environment`, so every package saw it; `.LogicalWrapper` is seen by
  a program that requires `js.cls` (or `logicalwrapper.cls`), as any
  extension class.
- **Patches 2 and 5**: the Node and browser builds carry
  `logicalwrapper.cls` next to `json.cls` and `yaml.cls`, which require it
  since r13277 (the in-memory build gets it from CMake).
- The other patches differ only in hashes and line numbers.

## Tests

`wasm/tests/js-booleans.rex` has 25 checks (`.json~true` and what
`json.cls` reads go to JavaScript as booleans; `.LogicalWrapper~of(1)` is
`.js~true`). The patches apply cleanly to trunk **r13278**, in order, with
`svn patch` or `git apply`. Patches 1–8 alone build and pass their tests:
`qualify-node-cli.sh` 32 checks (one fewer: the copy's own tests), and
`web-api.py` 55 cases. The official test suite on trunk r13278 (402 groups;
[`results/suite-platforms-r13278-series.md`](../../results/suite-platforms-r13278-series.md)):
no regressions against r13275 on any platform.

## The patches

[`patches/` at commit dac1e34](https://github.com/JosepMariaBlasco/oorexxwasm/tree/dac1e34/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.
