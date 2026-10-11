| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native | 402 | 400 | 2 | 0 | 0 | 24283 | 357745 | 2 | 0 |
| node | 402 | 397 | 5 | 0 | 0 | 24231 | 343841 | 7 | 0 |
| chromium | 402 | 371 | 31 | 0 | 0 | 24223 | 342460 | 158 | 73 |
| firefox | 402 | 371 | 31 | 0 | 0 | 24223 | 342459 | 159 | 73 |
| webkit | 402 | 371 | 31 | 0 | 0 | 24223 | 342460 | 158 | 73 |

| group | native | node | chromium | firefox | webkit | category | why |
|---|---|---|---|---|---|---|---|
| API/oo/METHOD | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | TEST_REXXC_WITH_NEWROUTINE_LOADPACKAGEFROMDATA: rexxc RC 127 (the API groups need wasm/build-test.sh's bin-web-test) |
| API/oo/ProcessInvocation | ok | ok | fail 54/0 | fail 54/0 | fail 54/0 | processes | runs testbinaries' rexxinstance as a command |
| API/oo/ProcessRexxStart | ok | ok | fail 20/0 | fail 20/0 | fail 20/0 | processes | runs testbinaries' rexxinstance as a command |
| base/bif/ARG | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | TEST_EXTERNAL_CALLS: RC 127 for an external command |
| base/bif/CHAROUT | fail 1/0 | fail 1/0 | fail 0/1 | fail 0/1 | fail 0/1 | processes | 'rexx delMe...rex' failed with RC 127 |
| base/bif/CONDITION | ok | ok | fail 2/1 | fail 2/1 | fail 2/1 | processes | external command raises FAILURE (RC 127), test expects ERROR |
| base/bif/LINEIN | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | 'echo hello hello>' file: no command |
| base/bif/LINEOUT | fail 1/0 | fail 1/0 | ok | ok | ok |  |  |
| base/bif/STREAM | ok | ok | fail 0/4 | fail 0/4 | fail 0/4 | processes | 'id -u' failed with RC 127 |
| base/class/File | ok | fail 3/0 | fail 3/0 | fail 4/0 | fail 3/0 | processes, memfs | searchPath('sh'): no shell on PATH; *_FRACTIONS: MEMFS file times read back in whole ms |
| base/class/Method | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | processes | rexxc: RC 127 |
| base/class/RexxContext | ok | fail 1/0 | ok | ok | ok | flaky | TEST_INTERPRETER_THREAD_INVOCATION: compares with a value a START thread records, read before that thread wrote it ('.nil'); once in Chromium (r13254 run), 6 reruns pass |
| base/class/RexxInfo | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | install | TEST_REXXINFO_EXECUTABLE: executable expected to be a File (it is .nil) |
| base/class/RexxQueue | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | 'rexx -e ...' RC 127 |
| base/class/Routine | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | processes | rexxc: RC 127 |
| base/class/Stream | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | processes | 'id -u' / 'rexx ...' RC 127 |
| base/directives/OPTIONS | ok | ok | fail 2/6 | fail 2/6 | fail 2/6 | processes | command results RC 127 |
| base/keyword/ADDRESS | ok | ok | fail 23/0 | fail 23/0 | fail 23/0 | processes | shell commands (cd, exit, cat, sort...) RC 127 |
| base/keyword/CALL | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | stack | TEST_STACKSIZE: Error 11 at ~900 (Chromium), ~1300 (Firefox) levels; WebKit passes (~5000) or not (3614 with the WebKit of the GitHub runners): it depends on the engine build |
| base/keyword/PARSE | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | external command RC 127 |
| base/keyword/SIGNAL | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | command FAILURE |
| base/keyword/TRACE | ok | fail 1/0 | ok | ok | ok | flaky | TEST_TRACE_LABEL_WITH_FORWARD: trace line count depends on thread timing (also seen under Node) |
| base/rexxutil/Macrospace | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | 'rexx -e ...' RC 127 |
| base/rexxutil/SysSearchPath | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | SysSearchPath('PATH', 'sh'): no shell |
| base/runtime.objects/environmentEntries | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | address '' 'exit': .rs -1 |
| base/source.file/incorrectCharacters | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | 'rexx ...' RC 127 |
| base/special.variables/RESULT_RC_SIGL | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | external rexx RC 127 |
| extensions/rxsock/socketClass | ok | ok | fail 9/0 | fail 9/0 | fail 9/0 | sockets | server/client tests (no listen) and socket options (.nil) |
| regressions/bug2003_guard_when | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | 'rexx guard_when.rex' RC 127 |
| samples/samples | ok | ok | fail 29/0 | fail 29/0 | fail 29/0 | processes | the samples are run as a rexx process (and are not in the browser's file system) |
| utilities/rexx/rexx_command | ok | ok | fail 0/28 | fail 0/28 | fail 0/28 | processes | runs rexx as a command |
| utilities/rexxc/rexxc | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | processes | runs rexxc as a command |
| utilities/rxqueue/rxQueue | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | processes | runs rxqueue as a command |
| utilities/rxsubcom/rxsubcom | ok | ok | fail 7/0 | fail 7/0 | fail 7/0 | processes | runs rxsubcom as a command |

Browser groups not passing, by category: processes 27, processes, memfs 1, install 1, stack 1, sockets 1
