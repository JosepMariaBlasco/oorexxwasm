| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| native | 402 | 397 | 5 | 0 | 0 | 24319 | 357891 | 9 | 0 |
| node | 402 | 388 | 14 | 0 | 0 | 23471 | 340681 | 9 | 8 |
| chromium | 402 | 365 | 37 | 0 | 0 | 23463 | 339568 | 85 | 81 |
| firefox | 402 | 366 | 36 | 0 | 0 | 23463 | 339580 | 84 | 81 |
| webkit | 402 | 367 | 35 | 0 | 0 | 23463 | 339581 | 83 | 81 |

| group | native | node | chromium | firefox | webkit | category | why |
|---|---|---|---|---|---|---|---|
| API/classic/CLASSIC | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| API/oo/CONVERSION | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| API/oo/FUNCTION | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| API/oo/INVOCATION | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| API/oo/METHOD | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| API/oo/ProcessInvocation | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| API/oo/ProcessRexxStart | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| API/oo/RexxStart | ok | fail 0/1 | fail 0/1 | fail 0/1 | fail 0/1 | api-libs | native test library |
| base/bif/ARG | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | TEST_EXTERNAL_CALLS: RC 127 for an external command |
| base/bif/CHAROUT | fail 1/0 | fail 1/0 | fail 0/1 | fail 0/1 | fail 0/1 | processes | "rexx delMe...rex" failed with RC 127 |
| base/bif/CONDITION | ok | ok | fail 2/1 | fail 2/1 | fail 2/1 | processes | external command raises FAILURE (RC 127), test expects ERROR |
| base/bif/LINEIN | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | 'echo hello hello>' file: no command |
| base/bif/LINEOUT | fail 1/0 | fail 1/0 | ok | ok | ok |  |  |
| base/bif/STREAM | ok | ok | fail 0/4 | fail 0/4 | fail 0/4 | processes | "id -u" failed with RC 127 |
| base/class/File | fail 2/0 | fail 4/0 | fail 4/0 | fail 4/0 | fail 4/0 | processes, memfs | searchPath("sh"): no shell on PATH; *_FRACTIONS: MEMFS file times read back in whole ms |
| base/class/Method | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | processes | rexxc: RC 127 |
| base/class/RexxInfo | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | install | TEST_REXXINFO_EXECUTABLE: executable expected to be a File (it is .nil) |
| base/class/RexxQueue | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | "rexx -e ..." RC 127 |
| base/class/Routine | ok | ok | fail 0/2 | fail 0/2 | fail 0/2 | processes | rexxc: RC 127 |
| base/class/Stream | fail 1/0 | fail 1/0 | fail 0/8 | fail 0/8 | fail 0/8 | processes | "id -u" / "rexx ..." RC 127 |
| base/directives/OPTIONS | ok | ok | fail 2/6 | fail 2/6 | fail 2/6 | processes | command results RC 127 |
| base/keyword/ADDRESS | ok | ok | fail 23/0 | fail 23/0 | fail 23/0 | processes | shell commands (cd, exit, cat, sort...) RC 127 |
| base/keyword/CALL | ok | ok | fail 1/0 | fail 1/0 | ok | stack | TEST_STACKSIZE: Error 11 at ~900 (Chromium), ~1300 (Firefox) levels; WebKit passes (~5000) |
| base/keyword/PARSE | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | external command RC 127 |
| base/keyword/SIGNAL | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | command FAILURE |
| base/keyword/TRACE | ok | fail 1/0 | fail 1/0 | ok | ok | flaky | TEST_TRACE_LABEL_WITH_FORWARD: trace line count depends on thread timing (also seen under Node) |
| base/rexxutil/Macrospace | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | "rexx -e ..." RC 127 |
| base/rexxutil/SysFileXXX | fail 4/0 | fail 1/0 | ok | ok | ok |  |  |
| base/rexxutil/SysSearchPath | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | SysSearchPath("PATH", "sh"): no shell |
| base/runtime.objects/environmentEntries | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | address "" "exit": .rs -1 |
| base/source.file/incorrectCharacters | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | "rexx ..." RC 127 |
| base/special.variables/RESULT_RC_SIGL | ok | ok | fail 1/0 | fail 1/0 | fail 1/0 | processes | external rexx RC 127 |
| extensions/rxsock/socketClass | ok | ok | fail 9/0 | fail 9/0 | fail 9/0 | sockets | server/client tests (no listen) and socket options (.nil) |
| regressions/bug2003_guard_when | ok | ok | fail 0/1 | fail 0/1 | fail 0/1 | processes | "rexx guard_when.rex" RC 127 |
| samples/samples | ok | ok | fail 29/0 | fail 29/0 | fail 29/0 | processes | the samples are run as a rexx process (and are not in the browser's file system) |
| utilities/rexx/rexx_command | ok | ok | fail 0/28 | fail 0/28 | fail 0/28 | processes | runs rexx as a command |
| utilities/rexxc/rexxc | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | processes | runs rexxc as a command |
| utilities/rxqueue/rxQueue | ok | ok | fail 0/8 | fail 0/8 | fail 0/8 | processes | runs rxqueue as a command |
| utilities/rxsubcom/rxsubcom | ok | ok | fail 7/0 | fail 7/0 | fail 7/0 | processes | runs rxsubcom as a command |

Browser groups not passing, by category: processes 24, api-libs 8, processes, memfs 1, install 1, stack 1, flaky 1, sockets 1
