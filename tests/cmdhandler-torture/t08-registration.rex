/* t08-registration: environments registered, replaced and removed in odd   */
/* places and in quantity.                                                   */
signal on syntax name unexpected
trace off
call on failure name onFailure
.CommandHandler~register("SELF", .Changer~new)

-- a handler removes itself during its own command
address self "DROPME"
call check "a handler removing itself answers its command", rc == "dropped"
failed = ""
address self "AGAIN"
call check "then the environment is unknown (FAILURE 30)", failed == 30
-- a handler replaces itself, and a command nested inside goes to the new one
.CommandHandler~register("SELF", .Changer~new)
address self "REPLACE"
call check "replaced during its own command: the nested command goes to the new one", rc == "new:INNER"
address self "ANY"
call check "and so does the next one", rc == "new:ANY"

-- many environments
many = n(10000)
do i = 1 to many
  .CommandHandler~register("E" || i, .Named~new(i))
end
good = 0
do i = 1 to many
  address value "E" || i
  "WHO"
  if rc == i then good += 1
end
call check many "environments, each its own handler", good == many
failed = ""; gone = 0
do i = 1 to many
  .CommandHandler~unregister("E" || i)
  address value "E" || i
  "WHO"
  if failed == 30 then gone += 1
  failed = ""
end
call check many "environments removed: FAILURE 30 each", gone == many

-- the same name registered again and again (each time the native table entry is replaced)
h = .Named~new("same")
rss0 = rss()
do i = 1 to n(200000)
  .CommandHandler~register("SAME", h)
  if i = n(20000) then rss0 = rss()
end
rss1 = rss()
address same "WHO"
call check n(200000) "registrations of the same name", rc == "same"
if rss0 \== "" then do
  call note "RSS (KB):" rss0 "->" rss1
  call check "re-registering does not keep growing", rss1 - rss0 < 16384
end

-- names: case, length, odd characters
.CommandHandler~register("MiXeD", .Named~new("mixed"))
address mixed "WHO"; call check "names are case-insensitive", rc == "mixed"
do len over .array~of(100, 250)
  name = "N"~copies(len)
  .CommandHandler~register(name, .Named~new(len))
  address value name
  "WHO"
  call check "a" len"-character name", rc == len
end
r = longName(1000)
call note "a 1000-character name:" r
call check "a 1000-character name: works or a clean error", r == 1000 | r~word(1) == "SYNTAX"
r = longName2("a b")
call check "a name with a blank: works or a clean error", r == "a b" | r~word(1) == "SYNTAX"
exit finish()

longName: procedure
  use arg len
  signal on syntax name longSyntax
  name = "L"~copies(len)
  .CommandHandler~register(name, .Named~new(len))
  address value name
  "WHO"
  return rc
longSyntax:
  return describe(condition("O"))

longName2: procedure
  use arg name
  signal on syntax name longSyntax2
  .CommandHandler~register(name, .Named~new(name))
  address value name
  "WHO"
  return rc
longSyntax2:
  return describe(condition("O"))

onFailure:
  failed = rc
  return

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class Named subclass CommandHandler
::method init
  expose id
  use arg id
::method command
  expose id
  return id

::class Changer subclass CommandHandler
::method init
  expose kind
  use arg kind = "old"
::method command unguarded
  expose kind
  use arg command, context
  select case command
    when "DROPME" then do
      .CommandHandler~unregister("SELF")
      return "dropped"
    end
    when "REPLACE" then do
      .CommandHandler~register("SELF", .Changer~new("new"))
      address self "INNER"
      return rc
    end
    otherwise nop
  end
  return kind":"command
