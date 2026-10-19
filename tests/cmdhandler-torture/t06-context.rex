/* t06-context: the .CommandContext used where it should not be: after its   */
/* command ended (every method), from a REPLY'd method that goes on after    */
/* the command returned, from another thread while the command runs, and     */
/* odd results.  Each must answer or raise a clean error, never crash.       */
signal on syntax name unexpected
trace off
.CommandHandler~register("C", .C~new)
x = "caller x"

-- after the command: every method is a SYNTAX 98.900, isValid is 0
address c "KEEP"
ctx = .local~kept
call check "isValid after the command", ctx~isValid == 0
good = 0
calls = .array~of("input", "output", "error", "isRedirected", "[]", "[]=", "getVar", "hasVar", "setVar", "dropVar", "variables", "raise")
do m over calls
  if stale(ctx, m) == "98.900" then good += 1
  else call note m "on a dead context:" stale(ctx, m)
end
call check "every method of a dead context raises 98.900", good == calls~items
call check "environment still readable on a dead context", ctx~environment == "C"

-- many dead contexts kept, then dropped
keep = .array~new
do i = 1 to n(100000)
  address c "KEEP"
  keep~append(.local~kept)
end
call check n(100000) "dead contexts kept", keep~items == n(100000) & keep[1]~isValid == 0
drop keep

-- REPLY: the method goes on using the context after the command returned
.local~replied = .bag~new
times = n(2000)
do i = 1 to times
  address c "REPLY"
  if rc \== "replied" then leave
end
call check times "commands whose handler REPLYs first", i > times
call SysSleep 0.5
call note "after REPLY, the context's calls gave:" summary(.local~replied)
bad = .local~replied~items - .local~replied~items("ok") - .local~replied~items("98.900")
call check "after REPLY: each call answered or raised 98.900", bad == 0

-- another thread uses the context while the command waits for it
.local~cross = .bag~new
in.0 = 1; in.1 = "a"
times = n(500)
do i = 1 to times
  address c "CROSS" with input stem in. output stem out.
  if rc \== "crossed" then leave
end
call check times "commands whose context is used from another thread", i > times
call note "the other thread's calls gave:" summary(.local~cross)

-- odd RC values
address c "RCNIL";    call check "RC .nil", rc == .nil | rc == "The NIL object"
address c "RCARRAY";  call check "RC an Array", rc~isA(.Array) | rc~isA(.String)
address c "RCLONG";   call check "RC a long string", rc~length == 100000
-- ERROR asked for, then a SYNTAX: the SYNTAX wins
signal on syntax name bothSyntax
address c "BOTH"
call check "raiseError then SYNTAX: SYNTAX reaches the caller", .false
bothSyntax:
signal on syntax name unexpected
call check "raiseError then SYNTAX: SYNTAX reaches the caller", condition("C") == "SYNTAX"
exit finish()

stale: procedure
  use arg ctx, m
  signal on syntax name staleSyntax
  -- through .Message: the context's own (private) SEND would hide Object's
  select case m
    when "[]", "getVar", "hasVar", "dropVar" then args = .array~of("x")
    when "[]=" then args = .array~of(1, "x")
    when "raise" then args = .array~of("ERROR", 1)
    when "isRedirected" then args = .array~of("Input")
    when "setVar" then args = .array~of("x", 1)
    otherwise args = .array~new
  end
  .Message~new(ctx, m, "A", args)~send
  return "no error"
staleSyntax:
  return condition("O")~code

summary: procedure
  use arg bag
  s = ""
  do k over .set~new~union(bag)
    s ||= k "x" bag~items(k)"; "
  end
  return s

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class C subclass CommandHandler
::method command unguarded
  use arg command, context
  select case command
    when "KEEP" then .local~kept = context
    when "REPLY" then do
      reply "replied"
      do 5
        .local~replied~put(try(context))
      end
      return                                -- no value after REPLY
    end
    when "CROSS" then do
      m = .Other~new~start("run", context)
      r = m~result
      return "crossed"
    end
    when "RCNIL" then return .nil
    when "RCARRAY" then return .array~of(1, 2)
    when "RCLONG" then return "z"~copies(100000)
    when "BOTH" then do
      context~raiseError(5)
      return 1 / 0
    end
  end
  return 0

::routine try public
  use arg context
  signal on syntax name failed
  x = context["x"]
  context["y"] = 1
  context~output~lineout("o")
  return "ok"
failed:
  return condition("O")~code

::class Other
::method run unguarded
  use arg context
  do 3
    .local~cross~put(try(context))
  end
  return 0
