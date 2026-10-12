/* smoke.rex: a quick check of an installed oorexxwasm package (npm install  */
/* -g), meant for every platform: run it with `rexx smoke.rex` from a       */
/* scratch directory.  One line per check; exits 1 if any fails.            */
.local~ok = 0; .local~bad = 0

parse version v
call check "version", v~word(1) == "REXX-ooRexx_5.3.0(MT)_32-bit"
call check "platform", .RexxInfo~platform \= ""

-- files on the host's file system
f = "oorexxwasm-smoke.txt"
call lineout f, "one"; call lineout f, "two"; call lineout f
call check "write and read a file", linein(f, 1) == "one" & linein(f) == "two"
call stream f, "c", "close"
call check "delete a file", SysFileDelete(f) == 0 & \SysFileExists(f)

-- external commands, as host processes
'node -e "process.exit(3)"'
call check "an external command and its rc", rc == 3

-- the session queue, and a named queue (the RexxAPI daemon)
push "pushed"; parse pull x
call check "the session queue", x == "pushed"
name = .RexxQueue~create
q = .RexxQueue~new(name)
q~queue("hello"); y = q~pull
.RexxQueue~delete(name)
call check "a named queue (the RexxAPI daemon)", y == "hello"

-- rexxc: compile a program and run the result
call lineout "smoke-hello.rex", "say 6 * 7"; call lineout "smoke-hello.rex"
address system 'rexxc smoke-hello.rex smoke-hello.rxc' with output stem banner.
crc = rc
address system 'rexx smoke-hello.rxc' with output stem out.
call check "rexxc, and the compiled program run", crc == 0 & rc == 0 & out.0 == 1 & out.1 == 42
call SysFileDelete "smoke-hello.rex"; call SysFileDelete "smoke-hello.rxc"

-- JavaScript
call check "JavaScript: .js", .js~Math~max(3, 7) == 7
call check "JavaScript: Node's modules", .js~require("node:path")~basename("/a/b.txt") == "b.txt"

say .ok "passed," .bad "failed"
exit .bad > 0

check: procedure
  use arg what, good
  if good then do; .local~ok += 1; say "ok  " what; end
  else do; .local~bad += 1; say "FAIL" what; end
  return

::requires "js.cls"
