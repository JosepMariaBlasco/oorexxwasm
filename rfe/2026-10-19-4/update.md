# RFE #879 update (4), 19 October 2026: no Rexx runs while a condition goes past JavaScript

## What changed

Only **patch 7** (`.JSObject`) changed, completing
[update (3)](../2026-10-19-3/update.md).

Update (3) made a `SIGNAL ON` trap in the Rexx code that called JavaScript
answer the call JavaScript is in before Rexx unwinds. Until the unwinding
reaches the trap, the activations it leaves stay on the activity's stack
(the trap's activation takes them off), so Rexx code that JavaScript called
meanwhile ran on top of them, and crashed. Now any further call of Rexx on
that thread is answered with a `RexxError` ("a condition of Rexx is on its
way to a trap of the code that called JavaScript") until the trap is
reached.

## Tests

`wasm/tests/js-errors.rex` has 47 checks: after the `SIGNAL ON`, a further
call of Rexx from JavaScript is refused, not run.

**Patches 1–6 and 8** are byte-identical. The patches apply cleanly to
trunk **r13275**, in order, with `svn patch` or `git apply`. Patches 1–8
alone build and pass their tests: `qualify-node-cli.sh` 33 checks, and
`web-api.py` 55 cases. The example environments differ only in hashes and
line numbers.

## The patches

[`patches/` at commit 29ada16](https://github.com/JosepMariaBlasco/oorexxwasm/tree/29ada16/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.
