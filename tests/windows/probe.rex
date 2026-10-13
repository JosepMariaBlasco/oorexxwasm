/* probe.rex: what the Node command-line build sees of its host, one fact per  */
/* line ("name = value", or "name !! error").  Made for bringing the port to  */
/* Windows, where the interpreter's Unix platform code meets Windows paths;   */
/* runs anywhere.  Never fails as a whole: every probe is caught on its own.  */
parse arg scratch
if scratch = "" then scratch = directory()

call probe "parse source",          "parse source x; return x"
call probe "parse version",         "parse version x; return x"
call probe "platform",              "return .RexxInfo~platform"
call probe "executable",            "return .RexxInfo~executable"
call probe "libraryPath",           "return .RexxInfo~libraryPath"
call probe "directorySeparator",    "return .RexxInfo~directorySeparator"
call probe "pathSeparator",         "return .RexxInfo~pathSeparator"
call probe "endOfLine",             "return .RexxInfo~endOfLine~c2x"
call probe "File~separator",        "return .File~separator"
call probe "File~pathSeparator",    "return .File~pathSeparator"
call probe "directory()",           "return directory()"
call probe "qualify('a.txt')",      "return qualify('a.txt')"
call probe "PATH",                  "return value('PATH',,'ENVIRONMENT')~left(300)~strip('T')"
call probe "Path (as Windows spells it)", "return value('Path',,'ENVIRONMENT')~left(300)~strip('T')"
call probe "HOME",                  "return value('HOME',,'ENVIRONMENT')"
call probe "USERPROFILE",           "return value('USERPROFILE',,'ENVIRONMENT')"
call probe "TEMP",                  "return value('TEMP',,'ENVIRONMENT')"
call probe "TMPDIR",                "return value('TMPDIR',,'ENVIRONMENT')"
call probe "ComSpec",               "return value('ComSpec',,'ENVIRONMENT')"
call probe "SHELL",                 "return value('SHELL',,'ENVIRONMENT')"

-- files: relative, absolute as given, the scratch directory
call probe "write relative",        "call lineout 'probe-a.txt', 'one'; call lineout 'probe-a.txt'; return linein('probe-a.txt', 1)"
call probe "query exists relative", "return stream('probe-a.txt', 'c', 'query exists')"
call probe "SysFileExists relative","return SysFileExists('probe-a.txt')"
call probe "delete relative",       "call stream 'probe-a.txt', 'c', 'close'; return SysFileDelete('probe-a.txt')"
f = scratch || .File~separator || "probe-b.txt"
call probe "absolute name",         "return" quote(f)
call probe "write absolute",        "call lineout" quote(f)", 'two'; call lineout" quote(f)"; return linein("quote(f)", 1)"
call probe "query exists absolute", "return stream("quote(f)", 'c', 'query exists')"
call probe "File absolute exists",  "return .File~new("quote(f)")~exists"
call probe "File~absolutePath",     "return .File~new('probe-b.txt')~absolutePath"
call probe "File~parent",           "return .File~new("quote(f)")~parent"
call probe "close absolute",        "return stream("quote(f)", 'c', 'close')"
call probe "SysFileDelete absolute","return SysFileDelete("quote(f)")"
call probe "SysMkDir sub",           "return SysMkDir('sub')"
call probe "SysMkDir/SysRmDir",     "return SysMkDir('probe-d') SysRmDir('probe-d')"
call probe "SysFileTree",           "call SysFileTree '*', 'x.', 'FO'; return x.0 x.1"
call probe "File~listFiles",        "return .File~new('.')~listFiles~items"
call probe "directory('..')",       "d = directory(); n = directory('..'); call directory d; return n"

-- the program itself, and packages found through PATH
call probe "::requires json.cls",   "return .context~package~loadPackage('json.cls')~name"
call probe "SysSearchPath rexx.img","return SysSearchPath('PATH', 'rexx.img')"

-- external commands, as host processes
call probe "address",               "return address()"
call probe "node -e exit 3",        "address system 'node -e ""process.exit(3)""'; return rc"
call probe "echo with output",      "address system 'echo hello' with output stem o.; return rc o.0 o.1"
call probe "cd (shell builtin)",    "address system 'cd' with output stem o.; return rc o.1"
call probe "dir or ls",             "address system 'dir /b' with output stem o. error stem e.; return rc o.0 e.0"
call probe "a command not found",   "address system 'no-such-command-x' with output stem o. error stem e.; return rc"

call probe "address cmd: ver",       "address cmd 'ver' with output stem o.; return rc o.0"
call probe "address cmd: set ORXP",  "address cmd 'set ORXP=1 && set ORXP' with output stem o.; return rc o.1"
call probe "2>&1 into one stem",     "address cmd 'echo out & echo err 1>&2' with output stem o. error stem o.; return rc o.0 o.1 o.2"
call probe "address bash",           "address bash 'echo $0' with output stem o.; return rc o.1"
call probe "value env Path=PATH",    "return value('Path',,'ENVIRONMENT') == value('PATH',,'ENVIRONMENT')"
call probe "SysTempFileName",        "return SysTempFileName('orx????.tmp')"
call probe "File~listRoots",         "r = .File~listRoots; return r~items r[1]"
call probe "File~isCaseSensitive",   "return .File~isCaseSensitive"
call probe "qualify('\a\b.txt')",  "return qualify('\a\b.txt')"
call probe "qualify('..\x')",       "return qualify('..\x')"
call probe "qualify('~/x')",         "return qualify('~/x')"
call probe "SysFileTree backslash",  "call lineout 'sub\t.txt', 'x'; call lineout 'sub\t.txt'; call SysFileTree 'sub\*.txt', 'x.', 'FO'; call SysFileDelete 'sub\t.txt'; return x.0 x.1"
call probe "filespec drive/path",    "f = 'C:\dir\sub\name.ext'; return filespec('d', f) '|' filespec('p', f) '|' filespec('n', f)"

call probe "rexxc",                  "call lineout 'probe-c.rex', 'say 6 * 7'; call lineout 'probe-c.rex'; address system 'rexxc probe-c.rex probe-c.rxc' with output stem o. error stem e.; r = rc o.0 e.0; do i = 1 to o.0; r = r '|' o.i; end; do i = 1 to e.0; r = r '|E' e.i; end; return r"
call probe "rexx compiled",          "address system 'rexx probe-c.rxc' with output stem o. error stem e.; r = rc o.0 e.0; do i = 1 to o.0; r = r '|' o.i; end; do i = 1 to e.0; r = r '|E' e.i; end; return r"
call probe "rexx source",            "address system 'rexx probe-c.rex' with output stem o. error stem e.; return rc o.0 e.0 o.1"
call probe "compiled exists",        "return SysFileExists('probe-c.rxc') stream('probe-c.rxc', 'c', 'query size')"

-- other processes and the session queue (RXQUEUESESSION), through the daemon
call probe "RXQUEUESESSION",         "return value('RXQUEUESESSION',,'ENVIRONMENT')"
call probe "echo | rxqueue",         "address cmd 'echo piped| rxqueue'; n = queued(); if n > 0 then parse pull x; return rc n x"
call probe "rxqueue /fifo, INPUT",   "address cmd 'rxqueue /fifo' with input using (('a', 'b')); n = queued(); do queued(); pull .; end; return rc n"
call probe "a child queues",         "address cmd 'rexx -e ""queue ''fromchild''""'; n = queued(); if n > 0 then parse pull x; return rc n x"
call probe "ADDRESS PATH rexxc",     "address path 'rexxc' with output stem o. error stem e.; return rc o.0 e.0"
call probe "executable",             "return .RexxInfo~executable"

-- the queues (the session queue; a named queue needs the RexxAPI daemon)
call probe "session queue",         "push 'pushed'; parse pull x; return x"
call probe "named queue (daemon)",  "n = .RexxQueue~create; q = .RexxQueue~new(n); q~queue('hi'); y = q~pull; .RexxQueue~delete(n); return y"

-- JavaScript
call probe "js Math.max",           "return .js~Math~max(3, 7)"
call probe "js process.platform",   "return .js~process~platform"
call probe "js process.cwd()",      "return .js~process~cwd"
exit 0

probe: procedure
  use arg name, code
  signal on syntax
  say name "=" evaluate(code)
  return
syntax:
  c = condition("O")
  say name "!!" c~code c~errortext c~message
  return

quote: return "'" || changestr("'", arg(1), "''") || "'"

::requires "js.cls"

::routine evaluate
  use arg code
  interpret code
