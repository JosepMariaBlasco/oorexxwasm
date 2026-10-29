# The official test suite on six platforms (test/trunk r13331, the series on trunk r13331)

GitHub Actions run 40897358349 (`.github/workflows/suite.yml`, test/trunk r13331), 29 October 2026, commit f72ca83 (base r13331: main/trunk identical to r13329, with #2129 r13326 and RFE #883's `RaiseConditionObject` r13329; test/trunk r13331, with their tests in `API/oo/METHOD`). 405 groups. Compared with r13325: no regressions. Two groups of category `flaky` failed under Node this time, and the reference CSV keeps their passing rows: `base/class/Ticker` (`TEST_TICKER_THREE_ARGS_TIMESPAN_TRIGGER`, a 0.5 s Ticker fired 5 times in a `SysSleep 0.75`; 10 of 10 pass in a session) and `base/keyword/TRACE` (`TEST_TRACE_LABEL_WITH_FORWARD`). Within their known causes: `base/class/File` counts 4 failures in Chromium and Firefox and 11 on Windows (category `flaky`/`memfs`).

| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native | 405 | 403 | 2 | 0 | 0 | 24467 | 358301 | 2 | 0 |
| node | 405 | 400 | 5 | 0 | 0 | 24415 | 344386 | 7 | 0 |
| chromium | 405 | 372 | 33 | 0 | 0 | 24407 | 343002 | 161 | 73 |
| firefox | 405 | 372 | 33 | 0 | 0 | 24407 | 343002 | 161 | 73 |
| webkit | 405 | 372 | 33 | 0 | 0 | 24407 | 343003 | 160 | 73 |
| windows | 405 | 393 | 12 | 0 | 0 | 24415 | 344211 | 35 | 0 |

| group | native | node | chromium | firefox | webkit | windows | category | why |
|---|---|---|---|---|---|---|---|---|
| API/oo/METHOD | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | TEST_REXXC_WITH_NEWROUTINE_LOADPACKAGEFROMDATA: rexxc RC 127 (the API groups need wasm/build-test.sh's bin-web-test) |
| API/oo/ProcessInvocation | ok | ok | fail 54/0 | fail 54/0 | fail 54/0 | ok | processes | runs testbinaries' rexxinstance as a command |
| API/oo/ProcessRexxStart | ok | ok | fail 20/0 | fail 20/0 | fail 20/0 | ok | processes | runs testbinaries' rexxinstance as a command |
| base/bif/ADDRESS | ok | ok | ok | ok | ok | fail 1/0 |  |  |
| base/bif/ARG | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | TEST_EXTERNAL_CALLS: RC 127 for an external command |
| base/bif/CHAROUT | fail 1/0 | fail 1/0 | fail 0/1 | fail 0/1 | fail 0/1 | fail 1/0 | processes | 'rexx delMe...rex' failed with RC 127 |
| base/bif/CONDITION | ok | ok | fail 2/1 | fail 2/1 | fail 2/1 | ok | processes | external command raises FAILURE (RC 127), test expects ERROR |
| base/bif/LINEIN | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | 'echo hello hello>' file: no command |
| base/bif/LINEOUT | fail 1/0 | fail 1/0 | ok | ok | ok | fail 1/0 |  |  |
| base/bif/QUALIFY | ok | ok | ok | ok | ok | fail 1/0 |  |  |
| base/bif/STREAM | ok | ok | fail 0/4 | fail 0/4 | fail 0/4 | fail 4/0 | processes | 'id -u' failed with RC 127 |
| base/class/CommandHandler | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | TEST_FORWARD_TO_NATIVE: "exit 3" in the default environment, RC 127 (no processes) |
| base/class/File | ok | fail 3/0 | fail 4/0 | fail 4/0 | fail 3/0 | fail 11/0 | processes, memfs, flaky | searchPath('sh'): no shell on PATH; *_FRACTIONS: MEMFS file times read back in whole ms (one of them passes by chance now and then: 3 or 4 failures) |
| base/class/Method | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | ok | processes | rexxc: RC 127 |
| base/class/RexxInfo | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | fail 1/0 | install | TEST_REXXINFO_EXECUTABLE: executable expected to be a File (it is .nil) |
| base/class/RexxQueue | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx -e ...' RC 127 |
| base/class/Routine | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | ok | processes | rexxc: RC 127 |
| base/class/Stream | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | fail 7/0 | processes | 'id -u' / 'rexx ...' RC 127 |
| base/class/Ticker | ok | fail 1/0 | ok | ok | ok | ok |  |  |
| base/directives/OPTIONS | ok | ok | fail 2/6 | fail 2/6 | fail 2/6 | fail 1/0 | processes | command results RC 127 |
| base/keyword/ADDRESS | ok | ok | fail 23/0 | fail 23/0 | fail 23/0 | fail 5/0 | processes | shell commands (cd, exit, cat, sort...) RC 127 |
| base/keyword/CALL | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | stack | TEST_STACKSIZE: Error 11 at ~900 (Chromium), ~1300 (Firefox) levels; WebKit passes (~5000) or not (3614 with the WebKit of the GitHub runners): it depends on the engine build |
| base/keyword/PARSE | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | external command RC 127 |
| base/keyword/SIGNAL | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | command FAILURE |
| base/keyword/TRACE | ok | fail 1/0 | ok | ok | ok | ok | flaky | TEST_TRACE_LABEL_WITH_FORWARD: trace line count depends on thread timing (also seen under Node) |
| base/rexxutil/Macrospace | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx -e ...' RC 127 |
| base/rexxutil/SysSearchPath | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | fail 1/0 | processes | SysSearchPath('PATH', 'sh'): no shell |
| base/rexxutil/SysStemSort | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | TEST_UNTRAPPED_ERRORS (test/trunk r13285, bug #2120): runs a second rexx, RC 127 |
| base/runtime.objects/environmentEntries | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | address '' 'exit': .rs -1 |
| base/source.file/incorrectCharacters | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx ...' RC 127 |
| base/special.variables/RESULT_RC_SIGL | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | external rexx RC 127 |
| extensions/rxsock/socketClass | ok | ok | fail 9/0 | fail 9/0 | fail 9/0 | ok | sockets | server/client tests (no listen) and socket options (.nil) |
| regressions/bug2003_guard_when | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx guard_when.rex' RC 127 |
| samples/samples | ok | ok | fail 29/0 | fail 29/0 | fail 29/0 | ok | processes | the samples are run as a rexx process (and are not in the browser's file system) |
| utilities/rexx/rexx_command | ok | ok | fail 0/28 | fail 0/28 | fail 0/28 | ok | processes | runs rexx as a command |
| utilities/rexxc/rexxc | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | ok | processes | runs rexxc as a command |
| utilities/rxqueue/rxQueue | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | fail 1/0 | processes | runs rxqueue as a command |
| utilities/rxsubcom/rxsubcom | ok | ok | fail 7/0 | fail 7/0 | fail 7/0 | ok | processes | runs rxsubcom as a command |

Browser groups not passing, by category: processes 29, processes, memfs, flaky 1, install 1, stack 1, sockets 1
