# The official test suite on six platforms (test/trunk r13380, the series on trunk r13379)

GitHub Actions run 42069889241 (`.github/workflows/suite.yml`, test/trunk r13380), 5 November 2026, commit 74e7dfb (base r13379: #2075, #2134, #2136, #2084, #2018, #1317, #2137, #2138, #2009, #2011, #2014, #1890; test/trunk r13380, 406 groups, `base/bif/BuiltinArgumentErrors` new). Compared with r13358: no regressions of the port. `utilities/rexx/rexx_command` has r13370's two tests of #1317 (a `rexx` command line of more than 8192 characters): they pass natively and under Node, cannot run in the browsers (no processes; 30 errors instead of 28), and fail on Windows, where `cmd.exe` cannot pass a command line that long (the tests skip `WINDOWS`; this host says `EMSCRIPTEN`). WebKit's `base/keyword/CALL` (category `stack`) failed this time; WebKit's and Windows' `base/keyword/TRACE` (category `flaky`) failed, and their reference CSVs keep the passing row. Within its known causes: `base/class/File` counts 3 failures in Node, Firefox and WebKit, 4 in Chromium and 11 on Windows (category `flaky`/`memfs`).

| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native | 406 | 404 | 2 | 0 | 0 | 24523 | 358590 | 2 | 0 |
| node | 406 | 403 | 3 | 0 | 0 | 24469 | 344683 | 5 | 0 |
| chromium | 406 | 373 | 33 | 0 | 0 | 24461 | 343255 | 171 | 75 |
| firefox | 406 | 373 | 33 | 0 | 0 | 24461 | 343256 | 170 | 75 |
| webkit | 406 | 373 | 33 | 0 | 0 | 24461 | 343255 | 170 | 75 |
| windows | 406 | 393 | 13 | 0 | 0 | 24469 | 344484 | 37 | 0 |

| group | native | node | chromium | firefox | webkit | windows | category | why |
|---|---|---|---|---|---|---|---|---|
| API/oo/METHOD | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | TEST_REXXC_WITH_NEWROUTINE_LOADPACKAGEFROMDATA: rexxc RC 127 (the API groups need wasm/build-test.sh's bin-web-test) |
| API/oo/ProcessInvocation | ok | ok | fail 60/0 | fail 60/0 | fail 60/0 | ok | processes | runs testbinaries' rexxinstance and detach_root_terminate as commands |
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
| base/class/File | ok | fail 3/0 | fail 4/0 | fail 3/0 | fail 3/0 | fail 11/0 | processes, memfs, flaky | searchPath('sh'): no shell on PATH; *_FRACTIONS: MEMFS file times read back in whole ms (one of them passes by chance now and then: 3 or 4 failures) |
| base/class/Method | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | ok | processes | rexxc: RC 127 |
| base/class/RexxInfo | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | fail 1/0 | install | TEST_REXXINFO_EXECUTABLE: executable expected to be a File (it is .nil) |
| base/class/RexxQueue | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx -e ...' RC 127 |
| base/class/Routine | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | ok | processes | rexxc: RC 127 |
| base/class/Stream | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | fail 7/0 | processes | 'id -u' / 'rexx ...' RC 127 |
| base/directives/OPTIONS | ok | ok | fail 2/6 | fail 2/6 | fail 2/6 | fail 1/0 | processes | command results RC 127 |
| base/keyword/ADDRESS | ok | ok | fail 27/0 | fail 27/0 | fail 27/0 | fail 5/0 | processes | shell commands (cd, exit, cat, sort...) RC 127 |
| base/keyword/CALL | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | stack | TEST_STACKSIZE: Error 11 at ~900 (Chromium), ~1300 (Firefox) levels; WebKit passes (~5000) or not (3614 with the WebKit of the GitHub runners): it depends on the engine build |
| base/keyword/PARSE | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | external command RC 127 |
| base/keyword/SIGNAL | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | command FAILURE |
| base/rexxutil/Macrospace | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx -e ...' RC 127 |
| base/rexxutil/SysSearchPath | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | fail 1/0 | processes | SysSearchPath('PATH', 'sh'): no shell |
| base/rexxutil/SysStemSort | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | TEST_UNTRAPPED_ERRORS (test/trunk r13285, bug #2120): runs a second rexx, RC 127 |
| base/runtime.objects/environmentEntries | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | address '' 'exit': .rs -1 |
| base/source.file/incorrectCharacters | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx ...' RC 127 |
| base/special.variables/RESULT_RC_SIGL | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | external rexx RC 127 |
| extensions/rxsock/socketClass | ok | ok | fail 9/0 | fail 9/0 | fail 9/0 | ok | sockets | server/client tests (no listen) and socket options (.nil) |
| regressions/bug2003_guard_when | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx guard_when.rex' RC 127 |
| samples/samples | ok | ok | fail 29/0 | fail 29/0 | fail 29/0 | ok | processes | the samples are run as a rexx process (and are not in the browser's file system) |
| utilities/rexx/rexx_command | ok | ok | fail 0/30 | fail 0/30 | fail 0/30 | fail 2/0 | processes | runs rexx as a command |
| utilities/rexxc/rexxc | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | ok | processes | runs rexxc as a command |
| utilities/rxqueue/rxQueue | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | fail 1/0 | processes | runs rxqueue as a command |
| utilities/rxsubcom/rxsubcom | ok | ok | fail 7/0 | fail 7/0 | fail 7/0 | ok | processes | runs rxsubcom as a command |

Browser groups not passing, by category: processes 29, processes, memfs, flaky 1, install 1, stack 1, sockets 1
