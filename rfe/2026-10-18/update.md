# RFE #879 update, 18 October 2026: the text of a number

## What changed

Only **patch 7** (`.JSObject`) changed.

### Why

A JavaScript number that reaches Rexx becomes a Rexx string, and until now
that string was JavaScript's own, `String(n)` with the exponent in
uppercase. JavaScript's rule for the exponent is not Rexx's: it writes
plain digits up to 1e21 and switches to an exponent below 1e-6, so
`1e17` arrived as `100000000000000000` (18 significant digits for a value
that has one) and `1e-7` as `1E-7`. Negative zero arrived as `0`, and NaN
and the infinities as `NaN`, `Infinity` and `-Infinity`, which are not how
ooRexx itself writes them.

The ooRexx bridges (Python, .NET, Lua, JavaScript) now write a host float
the same way, as ooRexx itself would.

### What it does now

A JavaScript number arrives as follows.

- **The digits** are the shortest that read back as the same double
  (`0.30000000000000004`, `0.3333333333333333`, `5E-324`), as before.
- **The exponent** is where ooRexx puts it: the text is exactly what ooRexx
  writes for `x + 0` under `NUMERIC DIGITS 17`, on those digits. Plain
  digits unless the integer part needs more than 17 places or the decimals
  more than 34; with an exponent, one digit before the point, `E`, the sign
  always written:

  | JavaScript | Rexx, before | Rexx, now |
  |---|---|---|
  | `1e16` | `10000000000000000` | `10000000000000000` |
  | `1e17` | `100000000000000000` | `1E+17` |
  | `1.5e17` | `150000000000000000` | `1.5E+17` |
  | `1e21` | `1E+21` | `1E+21` |
  | `1e-7` | `1E-7` | `0.0000001` |
  | `1e-34` | `1E-34` | `0.0000000000000000000000000000000001` |
  | `1e-35` | `1E-35` | `1E-35` |
  | `Number.MAX_VALUE` | `1.7976931348623157E+308` | `1.7976931348623157E+308` |

- **No `.0`**: JavaScript does not tell integers from floats by their text,
  so `1.0` arrives as `1`, as before.
- **Negative zero is kept**: `-0` (it arrived as `0`). It is a Rexx number,
  equal to 0 with `=`, but not with `==`.
- **NaN and the infinities** are `nan`, `+infinity` and `-infinity`, the
  strings ooRexx itself writes for them (`DoubleToObject`) and reads back
  (`ObjectToDouble`). They are not Rexx numbers.

The way back: `.js~num(x)` reads every one of these forms back as the same
double, `-0`, `nan`, `+infinity` and `-infinity` included, and also
JavaScript's own `NaN`, `Infinity` and `-Infinity` (case does not matter for
these words). `inf` is still not a number.

All of it is one function of `wasm/js-realm.js`, `number()`, and the
reading of a `.js~num` value in the same file.

### Where it is written

The specification says so in
[*Values*](../../docs/ooRexx-WASM-and-JavaScript.md#values), with its table
of changes; `wasm/README.md` and the first comment of `wasm/web/js.cls` too.

## Tests

A new portable test, `wasm/tests/js-floats.rex`, 23 checks
(`qualify-node-cli.sh`, and `web-api.py` in the browser's worker, case
"js floats"): the values of the table above and a few more, `-0`, NaN and
the infinities both ways, and 2000 doubles of every magnitude, for each of
which the text must equal ooRexx's own `x + 0` under `NUMERIC DIGITS 17`
and `.js~num` must read it back as the same double. The same comparison was
run on 20,000 doubles while the change was made: all equal.

**Patches 1–6** are byte-identical. **Patch 8** and the example
environments 0009–0012 differ only in the hashes and line numbers of the
files patch 7 also changes. The patches apply cleanly to trunk **r13268**,
in order, with `svn patch` or `git apply`. Patches 1–8 alone build and pass
their tests: `qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases.

## The patches

[`patches/` at commit d1bc9f9](https://github.com/JosepMariaBlasco/oorexxwasm/tree/d1bc9f9/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results

The official test suite does not use `.JSObject`, and nothing else changed:
the results of [update (3) of 13 October](../2026-10-13-3/update.md) still
hold.
