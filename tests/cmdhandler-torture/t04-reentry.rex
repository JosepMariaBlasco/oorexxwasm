/* t04-reentry: handlers that issue commands, to themselves and to each      */
/* other, with redirection and the caller's variables at every level; and    */
/* recursion until the interpreter's limit (Error 11, not a crash).          */
signal on syntax name unexpected
.CommandHandler~register("DEEP", .Deep~new)
.CommandHandler~register("PING", .Ping~new)
.CommandHandler~register("PONG", .Ping~new)

-- every level reads its input, adds a line, passes it down, and returns what came back
depth = n(50)
in.0 = 1; in.1 = "seed"
address deep "NEST" depth with input stem in. output stem out.
ok = out.0 == depth + 2 & out.1 == "seed"
do i = 2 to out.0 while ok
  ok = out.i == "L" || i - 2              -- seed, L0, L1, ... (each level adds its line on the way back)
end
call check "nested" depth "levels, redirection passed through each", ok
call check "each level saw its caller's variables", rc == "ok"

-- two handlers calling each other
address ping "BALL" n(200)
call check "PING/PONG" n(200) "times, alternating", rc == "PING" & .local~volleys == n(200)

-- down until the control stack is full, many times: Error 11 every time
times = n(20)
codes = .bag~new
do t = 1 to times
  codes~put(down())
end
call check "recursion through the handler ends in Error 11, every time", codes~items("11.1") + codes~items("11.2") == times
call note "deepest level reached:" .local~deepest "; codes:" codes~makeArray~makeString("L", " ")~left(60)

-- and after all that the handlers still work
address deep "NEST 3" with input stem in. output stem out.
call check "still works after hitting the limit", out.0 == 5 & rc == "ok"
exit finish()

down: procedure
  signal on syntax name downEnd
  .local~deepest = 0
  address deep "DOWN 1"
  return "returned"
downEnd:
  return condition("O")~code

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class Deep subclass CommandHandler
::method command unguarded
  use arg command, context
  parse var command verb level
  if verb == "DOWN" then do
    if level > .local~deepest then .local~deepest = level
    address deep "DOWN" level + 1
    return rc
  end
  -- NEST level: check the caller's own LEVEL variable (one more than ours, or none at the top)
  if context~hasVar("level") then callers = context["level"]
  else callers = .nil
  okHere = callers == .nil | callers == level + 1
  lines = context~input~arrayIn
  out = context~output
  if level = 0 then do
    out~arrayOut(lines)
    out~lineout("L0")
    if okHere then return "ok"; else return "bad at 0"
  end
  fwd. = ""; fwd.0 = lines~items
  do i = 1 to lines~items; fwd.i = lines[i]; end
  address deep "NEST" level - 1 with input stem fwd. output stem back.
  below = rc
  do i = 1 to back.0; out~lineout(back.i); end
  out~lineout("L" || level)
  if \okHere then return "bad at" level
  return below

::class Ping subclass CommandHandler
::method command unguarded
  use arg command, context
  parse var command . left
  me = context~environment
  if left = 0 then return me
  if .local~volleys == .nil | me == "PING" & left == context~getVar("start") then .local~volleys = 0
  .local~volleys = .local~volleys + 1
  if me == "PING" then address pong "BALL" left - 1
  else address ping "BALL" left - 1
  return rc
