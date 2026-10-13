# RFE #879 update, 13 October 2026 (2): no `.js~detach`, the collectors release everything

## What changed

Only **patch 7** (`.JSObject`) changed. A Rexx class can extend a JavaScript
class (`.js~extend`), and each of its instances is a pair: the Rexx object
and its JavaScript object. Until now the two kept each other alive, because
the Rexx object held its JavaScript object and the JavaScript object held
the Rexx object, which its overrides call. Each garbage collector saw only
its own half of that cycle, so the program had to end the link with
`.js~detach(o)`. That is not always possible: for example, the class may
be public, and be used by programs its author does not know.

`.js~detach` is gone. A pair lives while Rexx holds the Rexx object or
JavaScript holds its JavaScript object, and the two collectors release it.
At any moment, the link that keeps the other half alive points only one
way:

- **While Rexx holds the Rexx object**, the Rexx object holds its
  JavaScript object, and the bridge knows the Rexx object without holding
  it.
- **When Rexx no longer holds it**, the bridge holds the Rexx object, and
  holds the JavaScript object only weakly (`WeakRef`,
  `FinalizationRegistry`), so JavaScript's collector decides:
  - if JavaScript does not hold it either, the pair is over;
  - if JavaScript hands it to Rexx again, Rexx holds it again, and the
    first case applies.

The class's own `UNINIT`, if it has one, runs once, when the pair is over.

The bridge learns that Rexx no longer holds the Rexx object from an
`UNINIT`. It is not the object's own, because an object's `UNINIT` runs only
once. Instead, the Rexx object holds a small sentinel object, which holds
the Rexx object in turn, and a new sentinel is made for each round.

The bridge counts the times the object has crossed over to Rexx (when it is
handed over, and when an override is called). When it asks JavaScript to
hold its object weakly, it says how many crossings it has seen. JavaScript
ignores the request if a crossing it sent has not arrived yet.

The JavaScript class that `.js~extend` makes is now kept by the Rexx class
itself, not in a table of the bridge's, which kept every extended class
alive. Two places that pinned objects for JavaScript called the Rexx API
while holding a lock of the bridge's own. They no longer do: an API call may
run `UNINIT` methods on the same thread, and those may need that lock.

The specification says so, in
[*Classes*](../../docs/ooRexx-WASM-and-JavaScript.md#classes) ("Lifetime"),
with a row in its table of changes.

## Tests

`wasm/tests/js-extend.rex` still has 31 checks. The three that tested
`.js~detach` now check an object that JavaScript holds alone and that then
comes back to Rexx. The new `wasm/tests/js-extend-gc.rex` (8 checks) runs
under Node with `--expose-gc` and forces both collectors. It checks that:

- pairs that neither side holds are released, and their class's `UNINIT`
  runs once each;
- pairs that JavaScript holds alone live, and JavaScript still calls their
  overrides;
- a pair that Rexx holds alone lives;
- a pair taken back by Rexx after JavaScript let it go lives, and is
  released when Rexx lets it go too.

`qualify-node-cli.sh` runs it.

**Patches 1–6 and 8** are unchanged: 1–6 are byte-identical, and 8 differs
only in its line numbers. The patches apply cleanly to trunk **r13268**, in
order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 27 checks, `qualify-node.sh`, and
`web-api.py` 49 cases.

## The patches

[`patches/` at commit e370f6e](https://github.com/JosepMariaBlasco/oorexxwasm/tree/e370f6e/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes. The example
environments 0009–0012 only moved down by a few lines.

## Results on r13268

The official test suite, test/trunk r13268, ran on GitHub's runners with the
whole series applied:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 400 | 24,283 | 2 | 0 |
| Node.js command line (Linux) | 399 | 24,231 | 5 | 0 |
| Chromium | 371 | 24,223 | 159 | 73 |
| Firefox | 371 | 24,223 | 159 | 73 |
| WebKit | 372 | 24,223 | 157 | 73 |

These are the same results as in the morning's update. The test suite does
not use `.JSObject`, and nothing else changed. WebKit passed one more group
this time, CALL, whose stack depth test depends on the engine build. The
Windows results of the morning still hold, since patch 8 did not change.
There were no crashes.

## Files

- [`results/suite-platforms.md`](results/suite-platforms.md): the
  platforms side by side (also as [CSV](results/suite-platforms.csv)), with
  the cause of every difference.
- The results of each platform as CSV:
  [native](results/suite-native.csv), [Node](results/suite-node.csv),
  [Chromium](results/suite-chromium.csv), [Firefox](results/suite-firefox.csv),
  [WebKit](results/suite-webkit.csv).
