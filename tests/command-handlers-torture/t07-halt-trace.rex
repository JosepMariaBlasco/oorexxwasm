/* t07-halt-trace: HALT arriving while a handler runs (SIGINT to ourselves,  */
/* where there are processes and signals), and TRACE on in the caller and in */
/* the handler, with the trace going to a file.                              */
signal on syntax name unexpected
.CommandHandler~register("H", .H~new)
x = 0

pid = ""
if .rexxInfo~platform \== "WINDOWS", .rexxInfo~executable \== .nil then do
  address system "kill -0" SysQueryProcess("PID") with output stem o. error stem e.
  if rc == 0 then pid = SysQueryProcess("PID")
end
if pid == "" then call note "skip HALT: no signals to ourselves here"
else do
  times = n(20)
  halted = 0; after = 0
  do t = 1 to times
    r = spinUntilHalted(pid)
    if r == "HALT" | r == "4.1" then halted += 1
    else call note "try" t":" r
    address h "RET 5"
    if rc == 5 then after += 1
  end
  -- untrapped in the handler's method, HALT becomes SYNTAX 4.1 there, and that reaches the caller
  call check "HALT while the handler runs reaches the caller (as HALT or 4.1)," times "times", halted == times
  call check "commands work after each HALT", after == times
end

-- TRACE in the caller and in the handler, to a file
f = .File~temporaryPath || "/command-handlers-torture-trace-" || SysQueryProcess("PID") || ".txt"
fs = .stream~new(f); fs~open("write replace")
previous = .traceOutput~destination(fs)
in.0 = 2; in.1 = "a"; in.2 = "b"
do i = 1 to n(200)
  trace i
  address h "TRACED" with input stem in. output stem out.
  trace off
  if out.0 \== 2 | rc \== 2 then leave
end
.traceOutput~destination(previous)
fs~close
call check n(200) "commands with TRACE I in the caller and TRACE R in the handler", i > n(200)
lines = .stream~new(f)~arrayIn
call check "the trace has the caller's command and the handler's clauses", -
  lines~items > n(200) * 4 & lines~makeString~pos('"TRACED"') > 0 & lines~makeString~pos("in~linein") > 0
call SysFileDelete f
exit finish()

spinUntilHalted: procedure
  use arg pid
  signal on halt name gotHalt
  signal on syntax name gotSyntax
  .Killer~new~start("run", pid)
  address h "SPIN"
  return "returned" rc
gotHalt:
  return "HALT"
gotSyntax:
  return condition("O")~code

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class H subclass CommandHandler
::method command unguarded
  use arg command, context
  parse var command verb rest
  select case verb
    when "RET" then return rest
    when "SPIN" then do i = 1 to 100000000          -- until HALT
      v = context~getVar("x")
      context~setVar("x", i)
    end
    when "TRACED" then do
      trace r
      n = 0
      in = context~input; out = context~output
      do while in~lines > 0
        out~lineout(in~linein~upper)
        n += 1
      end
      return n
    end
  end
  return 0

::class Killer
::method run unguarded
  use arg pid
  signal on halt name done                  -- every thread gets the HALT
  call SysSleep 0.2
  address system "kill -INT" pid
  call SysSleep 1
done:
  return 0
