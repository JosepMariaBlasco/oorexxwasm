# RFE #879 update (3), 17 October 2026: copies keep cycles and sharing

## What changed

Only **patch 7** (`.JSObject`) changed.

### Why

A Rexx Array, Directory or StringTable goes to JavaScript as a copy, made
item by item. A Rexx Array holds references, so it can contain itself
(`a = .array~of(1, 2); a~append(a)`), two Arrays can contain each other, and
an Array can appear twice (`.array~of(x, x)`). Until now the copy:

- cut a cycle at 64 levels and put `null` there, without an error; any
  nesting deeper than 64 levels was cut the same way;
- made two arrays of an Array that appeared twice, where Rexx has one
  object.

Information was lost silently, which the bridge avoids everywhere else.

### What it does now

- **The structure is reproduced.** While one value is copied, each Array,
  Directory and StringTable is copied once, and met again it is the same
  JavaScript object: an Array that contains itself is an array that
  contains itself (`v[2] === v`); Arrays that contain each other, or any
  longer cycle, keep it, also through Directories and StringTables; an
  object that appears twice is one object (`v[0] === v[1]`). A
  multi-dimensional Array that contains itself, too.
- Each value sent starts afresh: two arguments, or two calls, give two
  copies.
- **A depth limit**, since the copy recurses: copies nested more than 1000
  deep are an error, a `RangeError` in JavaScript, SYNTAX 98.900 in Rexx
  ("Arrays, Directories or StringTables nested more than 1000 deep cannot be
  copied to JavaScript"). 1000 levels pass, in Node and in the browser's
  worker.

How: the copy keeps a memo that gives each Array, Directory and StringTable
an id. The records `A` and `T` carry it after the size, and an object met
again is sent as a new record `C` with its id, which the JavaScript side
resolves to the copy it already made; too deep is a record `G`. The format
is described at the top of `wasm/web-js.cpp`.

### Big copies

Each item the copy reads is a local reference of the native method in
progress, kept until the method returns. The copy now releases it once the
item is copied (the container keeps the item alive), except the value being
sent itself. Measured under Node: an Array of 1,000,000 strings sent three
times left the process at about 430 MB, now about 338 MB; a Directory of
200,000 entries, 20–50 MB less.

### Where it is written

The specification says so in
[*Values*](../../docs/ooRexx-WASM-and-JavaScript.md#values), with its table
of changes; `wasm/README.md` and the first comment of `wasm/web/js.cls` too.

## Tests

`wasm/tests/js-arrays.rex` has 21 checks now (`qualify-node-cli.sh`, and
`web-api.py` in the browser's worker, case "js arrays"): an Array that
contains itself, two that contain each other, a cycle of three, an Array
that appears twice, a cycle through a Directory, a StringTable that appears
twice, a multi-dimensional Array that contains itself, two arguments copied
on their own, a Rexx method's result through a `RexxProxy`, and 1000 and
1001 levels.

**Patches 1–6** are byte-identical (and so are 8–12 to those of the
cycles change, which the release of local references does not touch). **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 32 checks, and `web-api.py` 53 cases.

## The patches

[`patches/` at commit a838e37](https://github.com/JosepMariaBlasco/oorexxwasm/tree/a838e37/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
