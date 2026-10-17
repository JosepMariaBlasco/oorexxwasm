# RFE #879 update, 17 October 2026: booleans are `.Boolean`, the class of RFE #880

## What changed

Only **patch 7** (`.JSObject`) changed, and it now depends on another
proposal: [RFE #880](https://sourceforge.net/p/oorexx/feature-requests/880/),
a class for logical values in the ooRexx core (`.Boolean`, name still
open: `.Boolean` or `.Logical`).

### Why

Rexx has no boolean: `.true` and `.false` are the strings "1" and "0". The
bridge sends a Rexx string as a JavaScript string, and JavaScript takes any
string but "" as true, "0" included, so `button~disabled = .false` disabled
the button. Until now a program had to say `.js~false` (or `.js~bool(x)`)
for a real boolean, and a JavaScript boolean came back to Rexx as "1" or
"0", so it went back to JavaScript as a string.

### What it does now

- A `.Boolean` (an instance of the class or of a subclass) goes to
  JavaScript as `true` or `false`.
- A JavaScript boolean comes back as `.Boolean~true` or `.Boolean~false`.
  For Rexx they are "1" and "0" (IF, operators, comparisons, stems,
  DATATYPE), so programs see no difference, and a boolean that goes
  through Rexx and back is still a boolean.
- `.js~bool(x)` is `.Boolean~of(x)`: x is a Rexx logical value, and
  anything but 1 or 0 is error 34.900 at that line (it used to accept
  "true" and "false" too, and failed later, when the value was used).
  `.js~bool(.true)` or `.js~bool(a > b)` say what is meant. `.js~true` and
  `.js~false` are `.Boolean~true` and `.Boolean~false`, so they are
  always the same two objects; `.js~box("BOolean", x)` is `.js~bool(x)`,
  and `.js~unbox` of a `.Boolean` gives "1" or "0".

### Until RFE #880 is accepted

Patch 7 carries a verbatim copy of the class proposed there,
`wasm/web/boolean.cls` (version 2, SHA-256 `080fd7e21beb…`; see
[Version 2](#version-2-of-booleancls) below), installed
next to `js.cls`, which requires it, with its tests,
`wasm/tests/boolean-test.rex`. When the core has the class, the copy goes
(a package's own class would otherwise take precedence over the core
one). RFE #880 makes JSON's and YAML's booleans (`JsonBoolean`,
`YamlBoolean`) subclasses of it; from then on they cross to JavaScript as
booleans too, without the bridge knowing about JSON or YAML.

### Where it is written

The specification says so in
[*Values*](../../docs/ooRexx-WASM-and-JavaScript.md#values) ("Booleans"),
*Pitfalls* and *Guarantees*, with its table of changes; `wasm/README.md`
and the first comment of `wasm/web/js.cls` too.

### Version 2 of `boolean.cls`

Later the same day the class went to version 2, and patch 7 carries it
instead of version 1 (the copy stays verbatim). Two changes:

- Its prolog puts the class in `.environment` as `BOOLEAN`, unless an entry
  of that name is already there: once some package has loaded the file,
  `.Boolean` is visible everywhere, with no `::requires`, as a core class
  would be, and it never replaces a `.Boolean` the core (or another
  package) put there first.
- `defaultName` returns the value, so an Array's `makeString` and
  `toString` show "1" and "0" instead of "a Boolean".

The header has a `Version: 2` line, and the class has 22 tests (two more,
for `makeString` and `toString`). With version 2, patches 1–6 and 0012 are
byte-identical to those of version 1, and 8–11 differ only in the hashes of
the files patch 7 also changes. Patches 1–8 alone still build and pass
(31 checks, 52 cases).

## Tests

`qualify-node-cli.sh` runs `boolean-test.rex` (the class's own 22 tests)
and a new portable test, `wasm/tests/js-booleans.rex` (22 checks), which
`web-api.py` runs in the browser's worker too (case "js booleans"): both
directions, the identity of the instances, Rexx's use of them, a subclass,
inside Arrays and Directories, the arguments of a call of Rexx from
JavaScript, `.js~bool`'s check, `.js~box` and `.js~unbox`. It also passes in
Firefox and WebKit. One check of `qualify-node-cli.sh` used
`.js~box("BOOLEAN", "true")`; it now says `.js~box("BOOLEAN", .true)`.

**Patches 1–6** are byte-identical. **Patch 8** and the example environments
0009–0012 differ only in the hashes and line numbers of the files patch 7
also changes (`wasm/README.md`, the build and test scripts). The patches
apply cleanly to trunk **r13268**, in order, with `svn patch` or
`git apply`. Patches 1–8 alone build and pass their tests:
`qualify-node-cli.sh` 31 checks, and `web-api.py` 52 cases.

## The patches

[`patches/` at commit 9cd3b47](https://github.com/JosepMariaBlasco/oorexxwasm/tree/9cd3b47/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
