# RFE #879 update, 13 October 2026: Node on Windows, patch 8 of the RFE

## What changed

The RFE now has eight patches. The new **patch 8** (`[PATCH 8/8]`) lets the
Node command-line build run on Windows. It is the same `rexx.js` and
`rexx.wasm`: nothing is compiled for Windows. At run time,
`SysProcess::isWindowsHost()` tells the Unix platform code that the host is
Windows, and it adapts as follows:

- **File names** are Windows names written with forward slashes:
  `C:/dir/file`, `//server/share/dir`. Backslashes are accepted on input.
  `qualify()`, `.File`, `FILESPEC`, `SysFileTree` and the program search
  handle drive letters, and the roots are the drives. `rexx.img` is found
  next to `rexx.js`.
- **`PATH`-like lists** are separated by `;`. `.File~pathSeparator` and
  `.RexxInfo~pathSeparator` are now asked at run time: the image is the same
  for every host, so a value fixed when the image was made would be wrong
  on one of them.
- **Environment variable names** are not case-sensitive, as on Windows.
- **Commands** go to `cmd.exe /d /s /c "command"`, and the initial
  environment is `CMD`, as with ooRexx for Windows. `ADDRESS PATH` looks a
  program up as `cmd.exe` would, so `.cmd` and `.bat` files run too.
  `WITH OUTPUT` and `ERROR` to the same target keep their order.
- **The RexxAPI daemon** listens on a named pipe, Node's local sockets on
  Windows. Queues, registrations and the macrospace are shared between
  processes as on Linux and macOS.
- **Launchers**: `wasm/build-node.sh` and `wasm/build-test.sh` also write
  `rexx.cmd`, `rexxc.cmd`, `rxqueue.cmd`, `rxsubcom.cmd` (and
  `rexxinstance.cmd`).

`.RexxInfo~platform` is still `EMSCRIPTEN`. The code is guarded by
`#ifdef __EMSCRIPTEN__` and the run-time test, except in one place:
`StreamClasses.orx` now defines `.File~pathSeparator` as a method instead of
a constant, which returns the same value on every other platform. The native
test suite runs as before (below).

The Windows work also brought a bug to light. A logic error in the
interpreter (for example, no `rexx.img`) ended the Node process with status
0. It now ends with a non-zero status, and `qualify-node-cli.sh` checks it.
The fix is in patch 7, where the cause was (`wasm/js-bridge.js`).

**Patches 1–6** are unchanged except for the subject, which now says `n/8`.
Patch 7 has the fix above and has lost a stray `.pyc` file that the previous
version added.

The patches apply cleanly to trunk **r13268**, in order, with `svn patch` or
`git apply`. Patches 1–8 alone build and pass their tests:
`qualify-node-cli.sh` 24 checks, `qualify-node.sh`, the API test groups (796
tests, no failures) and `web-api.py` 49 cases.

## The npm package

The package [`oorexxwasm`](https://www.npmjs.com/package/oorexxwasm) is made
from the Node build. From version 0.2.0 it installs on Windows as well as on
Linux and macOS. Its checks (a smoke test, `js-proxy.rex`, `js-extend.rex`)
run on all three systems with Node 22 and 24.

## The rest of the series

The example environments move up one number: **0009** `ADDRESS JDOR`,
**0011** `ADDRESS FETCH`, **0012** `ADDRESS DOM`. **0010**, `cmdhandler`,
is the portable package that 0011 and 0012 use. None of them is part of the
RFE.

## The patches

[`patches/` at commit cad8e2d](https://github.com/JosepMariaBlasco/oorexxwasm/tree/cad8e2d/patches):
0001–0008 are the RFE, and `SHA256SUMS` lists their hashes.

## Results on r13268

The official test suite, test/trunk r13268, ran on GitHub's runners with the
whole series applied. Under WebAssembly it ran on the variants with the test
libraries. The new platform is the Node variant on Windows (`windows-latest`):

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 400 | 24,283 | 2 | 0 |
| Node.js command line (Linux) | 399 | 24,231 | 5 | 0 |
| Node.js command line (Windows) | 388 | 24,231 | 36 | 0 |
| Chromium | 371 | 24,223 | 159 | 73 |
| Firefox | 371 | 24,223 | 159 | 73 |
| WebKit | 371 | 24,223 | 158 | 73 |

There were no crashes on any platform. Native, Linux Node and the browsers
fail for the same reasons as on 12 October, listed group by group in
[`results/suite-platforms.md`](results/suite-platforms.md).

On Windows, the test suite takes `EMSCRIPTEN` for a Unix, and most of what
does not pass is a Unix expectation that a Windows host does not meet by
design:

- the initial environment is `CMD`, not `sh`;
- `echo $0`, `id -u > /dev/null` and `cd ~` are Unix shell commands;
- `/usr` is `D:/usr`, on the current drive;
- `qualify('~')` is `C:/Users/...`, written with forward slashes.

Two failures come from the host: a file time before 1970 cannot be set, and
file times lose their last fraction of a microsecond. As on Linux, CHAROUT
and LINEOUT fail natively too. MutexSemaphore timed out once. It now and then
hangs at interpreter termination under load, natively too, and it passed in
the previous Windows run. Every group is explained in
[`results/suite-windows.md`](results/suite-windows.md).

## Files

- [`results/suite-platforms.md`](results/suite-platforms.md): the
  side-by-side table of the six platforms (also as
  [CSV](results/suite-platforms.csv)). Its causes come from
  [`tests/suite-browser/known.tsv`](../../tests/suite-browser/known.tsv) and
  explain the browsers.
- [`results/suite-windows.md`](results/suite-windows.md): the Windows
  results, group by group.
- The results of each platform as CSV:
  [native](results/suite-native.csv), [Node](results/suite-node.csv),
  [Windows](results/suite-windows.csv), [Chromium](results/suite-chromium.csv),
  [Firefox](results/suite-firefox.csv), [WebKit](results/suite-webkit.csv).
