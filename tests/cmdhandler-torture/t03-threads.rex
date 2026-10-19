/* t03-threads: commands from many threads at once, to a shared handler      */
/* (guarded COMMAND, the default) and to an unguarded one, each thread with   */
/* its own variables; and one thread registering and removing an             */
/* environment while others send commands to it.                             */
signal on syntax name unexpected
shared = .Counter~new
free = .FreeCounter~new
.CommandHandler~register("SHARED", shared)
.CommandHandler~register("FREE", free)

threads = max(2, n(32)); per = n(2000)
msgs = .array~new
do t = 1 to threads
  msgs~append(.Worker~new~start("run", t, per))
end
answers = .bag~new
do m over msgs; answers~put(m~result); end
call check threads "threads x" per "commands each, all answered", answers~items("ok") == threads
if answers~items("ok") \== threads then do a over answers~makeArray~makeString("L", "; ")~makeArray(";"); call note a; end
call check "guarded handler counted every command", shared~count == threads * (per + 1)   -- + WHO
call check "unguarded handler counted every command", free~count == threads * per
call check "a handler of its own per thread",  .local~perThread == threads * per

-- register / remove while others send
flips = n(5000)
.local~flipping = .true
flipper = .Flipper~new~start("run", flips)
senders = .array~new
do t = 1 to max(2, n(8)); senders~append(.FlipSender~new~start("run", per)); end
sum.ok = 0; sum.failure = 0; sum.other = 0
do m over senders
  parse value m~result with o f x
  sum.ok += o; sum.failure += f; sum.other += x
end
.local~flipping = .false
call check "register/remove under fire: RC 1 or FAILURE 30, nothing else", sum.other == 0
if .local~odd \== .nil then call note "odd outcomes:" .local~odd~makeString("L", "; ")
call note sum.ok "answered," sum.failure "unregistered (FAILURE 30) while flipping" flipper~result "times"
exit finish()

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class Counter subclass CommandHandler
::attribute count get
::method init
  expose count
  count = 0
::method command                          -- guarded: one command at a time
  expose count
  use arg command, context
  count += 1
  if command == "WHO" then return context~getVar("mine")
  return "ok"

::class FreeCounter subclass CommandHandler
::attribute count get
::method init
  expose count
  count = 0
::method add
  expose count
  count += 1
::method command unguarded              -- many commands at once
  use arg command, context
  self~add
  v = context~getVar("mine")
  context~setVar("echo", v)
  return v

::class Worker
::method run unguarded
  use arg t, per
  mine = t
  address shared
  do i = 1 to per
    "ADD"
    if rc \== "ok" then return "thread" t": shared answered" rc
  end
  "WHO"
  if rc \== t then return "thread" t": WHO gave" rc
  address free
  do i = 1 to per
    "ADD"
    if rc \== t | echo \== t then return "thread" t": free answered" rc "echo" echo
  end
  name = "W" || t
  .CommandHandler~register(name, .Counter~new)
  address value name
  do i = 1 to per
    "ADD"
  end
  call addPerThread per
  return "ok"

::routine addPerThread
  use arg k
  .PerThread~add(k)

::class PerThread
::method add class
  use arg k
  if .local~perThread == .nil then .local~perThread = 0
  .local~perThread = .local~perThread + k

::class Flipper
::method run unguarded
  use arg flips
  h = .Counter~new
  do i = 1 to flips while .local~flipping
    .CommandHandler~register("FLIP", h)
    .CommandHandler~unregister("FLIP")
  end
  return i - 1

::class FlipSender
::method run unguarded
  use arg per
  ok = 0; failure = 0; other = 0
  trace off                               -- no "+++ RC(30)" for each one
  call on failure name f
  address flip
  do i = 1 to per
    "ADD"
    if rc == "ok" then ok += 1
    else if rc \== 30 then call odd "RC" rc
  end
  return ok failure other
f:
  if rc == 30 then failure += 1; else call odd condition("C") rc
  rc = 30
  return
odd:
  other += 1
  if .local~odd == .nil then .local~odd = .array~new
  if .local~odd~items < 5 then .local~odd~append(arg(1) arg(2))
  return
