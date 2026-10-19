# RFE #879 update, 19 October 2026: the patches on trunk r13275

## What changed

**No patch changed.** The base moved from trunk r13268 to **r13275**, and
everything was built and tested again on it.

### Why

Trunk has six fixes since r13268: bugs #2110 (r13269), #2114 (r13270),
#2113 (r13271), #2117 (r13272), #2111 (r13274) and #2112 (r13275). The last
two are the ones the command handlers of the example environments needed
(`AddCommandEnvironment` takes the interpreter lock; resolving an unknown
`ADDRESS` environment no longer writes into an unanchored object): with
them in trunk, nothing has to be applied by hand any more for any test.

### The patches on r13275

The twelve patches apply to r13275 unchanged, in order, with `svn patch` or
`git apply`, without fuzz (a few hunks at an offset); their hashes in `SHA256SUMS` are the same.
**Patches 1–8 alone** build on r13275 and pass their tests:
`qualify-node-cli.sh` 33 checks, and `web-api.py` 54 cases. With the whole
series, `tests/qualify.sh` passes its 41 checks, `qualify-node-cli.sh` 35,
and `web-api.py` 73.

The torture cases of the command handlers (`tests/cmdhandler-torture/`,
patch 10), natively at full scale on r13275 with the series: all 8 pass,
and `t03-threads` (32 threads, an environment registered and removed under
fire), which needed #2111 and #2112, passed 30 runs out of 30.

## The patches

[`patches/` at commit 703c544](https://github.com/JosepMariaBlasco/oorexxwasm/tree/703c544/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes (the same as in
the [previous update](../2026-10-18-6/update.md)).

## Results on r13275

The official test suite, test/trunk r13275, ran on GitHub's runners with the
whole series applied:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 400 | 24,285 | 2 | 0 |
| Node.js command line (Linux) | 398 | 24,233 | 6 | 0 |
| Node.js command line (Windows) | 390 | 24,233 | 35 | 0 |
| Chromium | 371 | 24,225 | 158 | 73 |
| Firefox | 371 | 24,225 | 157 | 73 |
| WebKit | 372 | 24,225 | 157 | 73 |

There were no crashes, and no regressions against r13268 on any platform.
test/trunk r13275 has two tests more than r13268. The groups that differ
from r13268 all do better:

- Windows: RexxInteger passes now (bug #2110, `TIME('O')` on 32-bit).
- Under Node, RexxContext, and in WebKit, CALL: groups whose results vary
  from run to run (a thread's timing; the engine's stack depth).
- In Firefox, File fails 2 tests instead of 4: MEMFS keeps file times in
  whole milliseconds, and one of the fraction tests passes by chance now
  and then.

## Files

- [`results/suite-platforms.md`](results/suite-platforms.md): the
  platforms side by side (also as [CSV](results/suite-platforms.csv)).
  The cause of every difference with native is in the repository's
  [`results/suite-platforms-r13275-series.md`](../../results/suite-platforms-r13275-series.md)
  and, for Windows,
  [`results/suite-windows-r13275-series.md`](../../results/suite-windows-r13275-series.md).
- The results of each platform as CSV:
  [native](results/suite-native.csv), [Node](results/suite-node.csv),
  [Windows](results/suite-windows.csv), [Chromium](results/suite-chromium.csv),
  [Firefox](results/suite-firefox.csv), [WebKit](results/suite-webkit.csv).
