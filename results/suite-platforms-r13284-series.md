# The official test suite on six platforms (test/trunk r13284, the series on trunk r13284)

GitHub Actions run 39966321675 (`.github/workflows/suite.yml`), 23 October 2026, commit f2b92bd. 403 groups. Compared with r13282: no regressions on native, Node, Chromium, Firefox or WebKit. On Windows `base/rexxutil/SysSleep` (`SysSleep(0.5)` took 0.528 s, the test allows up to 0.526) and `base/keyword/TRACE_TraceObject` (the order of two threads' trace lines) failed once and passed in a rerun of those two groups (run 39973159334), whose rows are the ones kept in `suite-windows-r13284-series.csv`; `base/class/RexxContext` (category `flaky`) failed once; `base/class/MutexSemaphore`, which timed out on r13282, passed.

| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native | 403 | 401 | 2 | 0 | 0 | 24304 | 357825 | 2 | 0 |
| node | 403 | 400 | 3 | 0 | 0 | 24252 | 343925 | 5 | 0 |
| chromium | 403 | 372 | 31 | 0 | 0 | 24244 | 342535 | 159 | 73 |
| firefox | 403 | 372 | 31 | 0 | 0 | 24244 | 342536 | 157 | 73 |
| webkit | 403 | 373 | 30 | 0 | 0 | 24244 | 342535 | 158 | 73 |
| windows | 403 | 388 | 15 | 0 | 0 | 24252 | 343716 | 38 | 0 |

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
| base/class/File | ok | fail 3/0 | fail 4/0 | fail 2/0 | fail 4/0 | fail 11/0 | processes, memfs, flaky | searchPath('sh'): no shell on PATH; *_FRACTIONS: MEMFS file times read back in whole ms (one of them passes by chance now and then: 3 or 4 failures) |
| base/class/Method | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | ok | processes | rexxc: RC 127 |
| base/class/RexxContext | ok | ok | ok | ok | ok | fail 1/0 | flaky | TEST_INTERPRETER_THREAD_INVOCATION: compares with a value a START thread records, read before that thread wrote it ('.nil'); once in Chromium (r13254 run), 6 reruns pass |
| base/class/RexxInfo | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | fail 1/0 | install | TEST_REXXINFO_EXECUTABLE: executable expected to be a File (it is .nil) |
| base/class/RexxQueue | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx -e ...' RC 127 |
| base/class/Routine | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | ok | processes | rexxc: RC 127 |
| base/class/Stream | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | fail 7/0 | processes | 'id -u' / 'rexx ...' RC 127 |
| base/directives/OPTIONS | ok | ok | fail 2/6 | fail 2/6 | fail 2/6 | fail 1/0 | processes | command results RC 127 |
| base/keyword/ADDRESS | ok | ok | fail 23/0 | fail 23/0 | fail 23/0 | fail 5/0 | processes | shell commands (cd, exit, cat, sort...) RC 127 |
| base/keyword/CALL | ok | ok | fail 1/0 | fail 1/0 | ok | ok | stack | TEST_STACKSIZE: Error 11 at ~900 (Chromium), ~1300 (Firefox) levels; WebKit passes (~5000) or not (3614 with the WebKit of the GitHub runners): it depends on the engine build |
| base/keyword/PARSE | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | ok | processes | external command RC 127 |
| base/keyword/SIGNAL | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | command FAILURE |
| base/keyword/TRACE_TraceObject | ok | ok | ok | ok | ok | fail 1/0 |  |  |
| base/rexxutil/Macrospace | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | ok | processes | 'rexx -e ...' RC 127 |
| base/rexxutil/SysSearchPath | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | fail 1/0 | processes | SysSearchPath('PATH', 'sh'): no shell |
| base/rexxutil/SysSleep | ok | ok | ok | ok | ok | fail 1/0 |  |  |
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

Browser groups not passing, by category: processes 27, processes, memfs, flaky 1, install 1, stack 1, sockets 1
