# RFE #879 update, 11 October 2026 (2): a sixth patch, and the API test groups run

## What changed

The eight API test groups of the test suite (`API/classic`, `API/oo`, 796
tests) load the native libraries of `testbinaries/`, and two of them run
`testbinaries/rexxinstance` as a command. With no `dlopen` in WebAssembly,
none of their tests could run, so the RFE could not show that the RexxAPI
works under WebAssembly as it does natively. Making them run also uncovered
a bug in patch 1.

- **Patch 1, a fix.** The WASM runtime skipped `RexxResolveRoutine()` in
  `PackageManager` (`createRegisteredRoutine` and
  `resolveRegisteredRoutineEntry`). This was left over from the original
  port, which had no RexxAPI at all. Since patch 1 links the API server in,
  the call is safe, and without it two things did not work under
  WebAssembly: `RxFuncAdd` of a classic library function, and functions
  registered with `RexxRegisterFunctionExe`. Both work now, under Node and in
  the browsers. Resolving an unknown function costs no measurable time more.
- **Patch 1, linked-in libraries.** `SysLibrary` now looks up a table of
  libraries linked into the executable, `orx_wasm_static_libraries()`, before
  `dlopen`/`dlsym`. It is a weak symbol, absent in the standard builds, so
  nothing changes for them. A build that links libraries in and describes
  them there finds them with `::METHOD ... EXTERNAL "LIBRARY name ..."`,
  `RxFuncAdd()` and the `RexxRegister*Dll()` registrations, unchanged.
- **New patch 6** (`[PATCH 6/6]`): `wasm/build-test.sh [BUILD_DIR]
  [node|web|both]` builds, for testing only, variants of the Node and
  browser builds with the test libraries linked in (`bin-node-test`,
  `bin-web-test`):
  - The libraries are compiled as they are. The names that more than one of
    them defines get a prefix per library, mapped back in the table.
  - In the Node variant, `rexxinstance` is one more tool in `rexx.wasm`, as
    `rexxc` is. This goes through a weak hook in `rexx.cpp`'s dispatcher.
  - `build-node.sh` and `build-web.sh` accept `EXTRA_OBJECTS`.
  - `wasm/README.md` has a new section on running the API groups:
    `bin-node-test/rexx testOORexx.rex -R ooRexx/API` from the test suite's
    directory.
- **Patches 2–5**: no change (only the index lines differ, and the subject
  now says `n/6`).

The patches apply cleanly to trunk **r13268**, in order, with `svn patch`
or `git apply`.

A correction to the morning's update: it said that File now passes under
Node. It does not; it fails the same three tests on file times as above,
as it did then.

## The patches

[`patches/` at commit d3e4d6b](https://github.com/JosepMariaBlasco/oorexxwasm/tree/d3e4d6b/patches):
0001–0006 are the RFE, and `SHA256SUMS` lists their hashes. 0007–0011 build
on them and are not part of the RFE (they were 0006–0010).

## Results on r13268

Official test suite, test/trunk r13268. Under WebAssembly it ran on the
variants with the test libraries:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 400 | 24,283 | 2 | 0 |
| Node.js command line | 397 | 24,231 | 7 | 0 |
| Chromium | 371 | 24,223 | 158 | 73 |
| Firefox | 371 | 24,223 | 159 | 73 |
| WebKit | 371 | 24,223 | 158 | 73 |

There were no crashes and no timeouts on any platform. Compared with the
morning's update:

- **Node**: all eight API groups pass, as natively (796 more tests).
  The five groups that fail are CHAROUT and LINEOUT (they fail natively
  too), File (three tests on file times: below the microsecond, Node's file
  system rounds them, and a time before 1970 is not kept), and RexxContext
  and TRACE, which depend on timing.
- **Browsers**: five of the API groups pass. ProcessInvocation and
  ProcessRexxStart run `rexxinstance` as a command, and one METHOD test runs
  `rexxc`. A browser has no processes, so these fail like the other groups
  that run commands. That is why the browsers show more failures than
  before: these tests used to stop at the first error, and now they run.

## Files

- [`results/suite-platforms.md`](results/suite-platforms.md): the
  side-by-side table, with the cause of every group that does not pass
  everywhere (also as [CSV](results/suite-platforms.csv)). The causes come
  from [`tests/suite-browser/known.tsv`](../../tests/suite-browser/known.tsv).
- The results of each platform as CSV:
  [native](results/suite-native.csv), [Node](results/suite-node.csv),
  [Chromium](results/suite-chromium.csv), [Firefox](results/suite-firefox.csv),
  [WebKit](results/suite-webkit.csv).
