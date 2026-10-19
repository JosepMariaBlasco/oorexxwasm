/* t05-errors: conditions out of handlers, many times and in every state:    */
/* SYNTAX after each kind of context call (the #2104 path), at depth, caught */
/* inside the handler, ERROR / FAILURE with CALL ON and SIGNAL ON, and the   */
/* conditions the handler is not meant to raise (USER, HALT, NOTREADY).      */
signal on syntax name unexpected
trace off                                   -- no "+++ RC(-n)" for each FAILURE
.CommandHandler~register("E", .E~new)
loops = n(2000)
in.0 = 3; in.1 = "a"; in.2 = "b"; in.3 = "c"
mine = "caller"

-- SYNTAX after every kind of context call, caught by the caller each time
do verb over .array~of("PLAIN", "LINEIN", "LINES", "OUTPUT", "ERROR", "GET", "SET", "GETVAR", "SETVAR", "HAS", "DROP", "VARS", "REDIR", "ISVALID")
  good = 0
  do i = 1 to loops
    if syntaxOf(verb) == "42.3" then good += 1
  end
  call check "SYNTAX after" verb~lower", caught by the caller" loops "times", good == loops
end

-- SYNTAX raised several levels down, through every level's native frames
good = 0
do i = 1 to loops % 10
  do depth = 1 to 10
    if syntaxOf("DEEP" depth) == "42.3" then good += 1
  end
end
call check "SYNTAX from 1 to 10 levels down reaches the top", good == (loops % 10) * 10

-- trapped inside the handler, which then keeps using the context
good = 0
do i = 1 to loops
  address e "SELFTRAP" with input stem in. output stem out.
  if rc == 7 & out.0 == 4 & out.4 == "after" & mine == "set after" then good += 1
  mine = "caller"
end
call check "SYNTAX trapped inside the handler, the context still usable", good == loops

-- ERROR / FAILURE: CALL ON and SIGNAL ON, many times
.local~errs = 0; .local~fails = 0
call on error name onError
call on failure name onFailure
do i = 1 to loops
  address e "RAISE ERROR" i
  address e "RAISE FAILURE" (-i)
end
call off error; call off failure
call check "CALL ON ERROR / FAILURE," loops "each", .local~errs == loops & .local~fails == loops
good = 0
do i = 1 to loops
  if signalled("ERROR") == "ERROR 5" then good += 1
end
call check "SIGNAL ON ERROR" loops "times", good == loops
-- a handler that raises ERROR while it handles a nested ERROR of its own
address e "NESTERR"
call check "ERROR inside the handler, trapped there, then ERROR to the caller", rc == 9

-- conditions a handler is not meant to raise: what the caller gets, and no crash
do what over .array~of("USER BOOM", "HALT", "NOTREADY", "SYNTAX 98.900")
  r = odd(what)
  call note "RAISE" what "in the handler -> caller sees:" r
  call check "RAISE" what "in the handler: the caller gets a condition", r \== "nothing" & r~pos("UNEXPECTED") == 0
end

-- SYNTAX while output is going to a stem: what was written is kept
signal on syntax name partial
drop out.
address e "HALFWAY" with output stem out.
partial:
signal on syntax name unexpected
call check "SYNTAX halfway through the output: the lines written are there", out.0 == 5
exit finish()

syntaxOf: procedure expose in. out. err. mine
  use arg verb
  signal on syntax name caught
  address e verb "DIV" with input stem in. output stem out. error stem err.
  return "no condition"
caught:
  return condition("O")~code

signalled: procedure
  use arg kind
  signal on error name caughtError
  address e "RAISE" kind 5
  return "nothing"
caughtError:
  return condition("C") rc

odd: procedure
  use arg what
  signal on any name caughtAny
  signal on syntax name caughtAny
  signal on user boom name caughtAny
  address e "RAISE" what
  return "nothing"
caughtAny:
  return describe(condition("O"))

onError:   .local~errs = .local~errs + 1; return
onFailure: .local~fails = .local~fails + 1; return

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class E subclass CommandHandler
::method command unguarded
  use arg command, context
  parse var command verb rest
  select case verb
    when "PLAIN"   then nop
    when "LINEIN"  then x = context~input~linein
    when "LINES"   then x = context~input~arrayIn
    when "OUTPUT"  then context~output~lineout("x")
    when "ERROR"   then context~error~lineout("x")
    when "GET"     then x = context["mine"]
    when "SET"     then context["tmp"] = 1
    when "GETVAR"  then x = context~getVar("mine")
    when "SETVAR"  then context~setVar("tmp", 1)
    when "HAS"     then x = context~hasVar("mine")
    when "DROP"    then context~dropVar("tmp")
    when "VARS"    then x = context~variables
    when "REDIR"   then x = context~isRedirected("Same")
    when "ISVALID" then x = context~isValid
    when "DEEP" then do
      parse var rest depth .
      if depth > 1 then address e "DEEP" depth - 1 "DIV"
      else return 1 / 0
    end
    when "SELFTRAP" then return self~selfTrap(context)
    when "RAISE" then do
      parse var rest kind detail
      select case kind
        when "ERROR"    then return context~raiseError(detail)
        when "FAILURE"  then return context~raiseFailure(detail)
        when "USER"     then raise user boom
        when "HALT"     then raise halt
        when "NOTREADY" then raise notready
        when "SYNTAX"   then raise syntax 98.900 array("from the handler")
      end
    end
    when "NESTERR" then return self~nestErr(context)
    when "HALFWAY" then do
      do i = 1 to 5; context~output~lineout("line" i); end
      return 1 / 0
    end
  end
  return 1 / 0                              -- "... DIV": SYNTAX 42.3

::method nestErr private
  use arg context
  signal on error name inner
  address e "RAISE ERROR 3"
  return "not trapped"
inner:
  return context~raiseError(9)

::method selfTrap private
  use arg context
  signal on syntax name trapped
  context~output~arrayOut(context~input~arrayIn)
  context~setVar("mine", "set before")
  return 1 / 0
trapped:
  context~output~lineout("after")
  context~setVar("mine", "set after")
  return 7
