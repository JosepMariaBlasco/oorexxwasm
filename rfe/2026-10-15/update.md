# RFE #879 update, 15 October 2026: the page's Rexx scripts under a debugger

## What changed

Only **patch 7** (`.JSObject`) changed: `ooRexx.js` has a hook for a
debugger, and there is a test for it.

A page runs Rexx with `<script type="text/rexx">` (see
[update of 12 October](../2026-10-12/update.md)). Rony Flatscher asked for
a way to debug those scripts in the browser itself, as the browser's
developer tools debug JavaScript. Such a debugger does not belong in
ooRexx, but ooRexx has to let one in. That is what the hook does.

When the page's address has `rexx-debug=1` in it
(`page.html?rexx-debug=1`), `ooRexx.js` first loads `ooRexx-debugger.js`
from its own directory. That file sets `ooRexx.debugger`, an object with
three methods, each of which may return a Promise:

- `prepare(options)`, before the session for the page's scripts starts,
  may add to the session's options (files, for instance);
- `attach(session)` is called once the session has started;
- `instrument(name, source)` gives the source to run for each script.

Without `rexx-debug=1` nothing changes, and nothing more is loaded. With
it, but without the file, a warning goes to the console and the scripts run
as usual; if `prepare` or `attach` fails, the error goes to the console and
the scripts run without the debugger.

The specification says so in
[*Rexx from the page*](../../docs/ooRexx-WASM-and-JavaScript.md#rexx-from-the-page)
("Debugging the scripts"), with a row in its table of changes.
`wasm/README.md` and the first comment of `wasm/web/ooRexx.js` describe it
too.

## A debugger that uses it

This repository has one, outside the patches: [`debugger/`](../../debugger/README.md),
a panel at the foot of the page built on Dom Wise's
[ooRexx debugger](https://sourceforge.net/p/oorexxdebugger/), with a web
front end. It has breakpoints in the scripts and in the handlers they set up,
step, the stack, the variables, and Rexx run where the program is paused.
The browser distribution and the playground include it. The example page
shows it at
[rexx.epbcn.com/oorexx-wasm/example/?rexx-debug=1](https://rexx.epbcn.com/oorexx-wasm/example/?rexx-debug=1).

## Tests

`web-api.py` has a new case, "rexx scripts debug". It installs a stand-in
debugger, `wasm/tests/web-debugger.js`, as `ooRexx-debugger.js`, and opens
the page of the "rexx scripts" case with `?rexx-debug=1`. The stand-in
records the calls it gets, adds a file to the session in `prepare`, sets a
variable in `attach`, and makes each script count itself in `instrument`.
The case checks the order of the calls, that the session sees the file and
the count, and that the page's output is the same as without the debugger.

**Patches 1–6** are byte-identical, and **patch 8** differs only in the
hash of `wasm/README.md`, which it also changes. The patches apply cleanly
to trunk **r13268**, in order, with `svn patch` or `git apply`. Patches 1–8
alone build and pass their tests: `qualify-node-cli.sh` 28 checks, and
`web-api.py` 50 cases.

## The patches

[`patches/` at commit 1563cae](https://github.com/JosepMariaBlasco/oorexxwasm/tree/1563cae/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes. Of the example
environments, 0009 (JDOR) has new methods and follows the corrections
accepted for the Java handler, for the JDOR test suite; 0010–0012 only
moved down by a few lines.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
