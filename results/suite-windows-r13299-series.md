# The official test suite under Node on Windows (test/trunk r13299)

The Node test variant (`wasm/build-test.sh`'s `bin-node-test`, patches
0001–0012) on GitHub's `windows-latest`, run from Git Bash with
`tests/run-suite.sh` (`.github/workflows/suite.yml`, platform `windows`).
Reference CSV: [`suite-windows-r13299-series.csv`](suite-windows-r13299-series.csv).

| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| windows | 404 | 392 | 12 | 0 | 0 | 24326 | 343946 | 35 | 0 |

(Run 40216938647, trunk r13299 with test/trunk r13299. `base/class/MutexSemaphore`,
a timeout on r13291 (category `flaky`), passes. `base/rexxutil/SysSleep` failed
once (`TEST_SLEEP_CONCURRENT`, a 2.4 s sleep took 2.450 s on a loaded runner,
category `flaky`) and passed when run again (run 40217931065), whose row the
reference CSV keeps.)

`.RexxInfo~platform` is `EMSCRIPTEN` on every host, and the test suite takes
EMSCRIPTEN for a Unix: most of what does not pass is a Unix expectation that a
Windows host does not meet by design (file names written `C:/dir/file`, the
initial environment `CMD`, `cmd.exe` instead of `sh`). None of it is a crash
or a timeout.

| group | failures | category | why |
|---|---|---|---|
| base/bif/ADDRESS | 1 | windows | the initial environment is `CMD`; the test expects `sh` |
| base/bif/CHAROUT | 1 | also native | TEST_STDOUT_START fails on every platform (also native) |
| base/bif/LINEOUT | 1 | also native | fails on every platform (also native) |
| base/bif/QUALIFY | 1 | windows | `qualify('~')` is `C:/Users/...`; the test compares with `HOME` as Windows spells it (backslashes) |
| base/bif/STREAM | 4 | windows | the root check runs `id -u > /dev/null` with `cmd.exe` |
| base/class/File | 11 | windows, host | `/usr` is `D:/usr` (the current drive), two roots (C:/ and D:/), names not case-sensitive, `sh` not in `PATH` (`cmd.exe`), `TMPDIR` test for Unix; file times: a time before 1970 cannot be set, fractions of a microsecond are lost (10 or 11 failures from run to run: a fraction test passes by chance now and then) |
| base/class/RexxInfo | 1 | windows | `.RexxInfo~executable` is `rexx.cmd`; the test expects `rexx` |
| base/class/Stream | 7 | windows | the root check runs `id -u > /dev/null` with `cmd.exe` |
| base/directives/OPTIONS | 1 | windows | an unknown command gives RC 1 with `cmd.exe`, 127 with `sh` |
| base/keyword/ADDRESS | 5 | windows | `sh`, `echo $0`, `set` and `cd ~` as a Unix shell has them |
| base/rexxutil/SysSearchPath | 1 | windows | looks for `sh` in `PATH` |
| utilities/rxqueue/rxQueue | 1 | windows | compares `pwd` of Git Bash (`/d/a/...`) with `directory()` (`D:/a/...`) |

Fixed on the way (patch 0008 and the scripts): the RexxAPI daemon on a named
pipe (queues across processes), `.cmd` launchers (`cmd.exe` took `rexx.js` for
`rexx`, `.JS` being in `PATHEXT`), `ADDRESS PATH` running `.cmd` files, `CD`
with backslashes, `SysFileCopy` of a file onto itself, `File~parent` of
`C:/name`, environment names in upper case.

Since r13268: `base/class/RexxInteger` passes (bug #2110, fixed in r13269:
`time('O')` and `date('F')`/`time('F' | 'T')` give a RexxInteger on 32-bit
too).
