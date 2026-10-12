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
