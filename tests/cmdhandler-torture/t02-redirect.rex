/* t02-redirect: large and odd redirections.                                 */
signal on syntax name unexpected
.CommandHandler~register("R", .R~new)

k = n(200000)
do i = 1 to k; in.i = "line" i; end; in.0 = k
address r "COPY" with input stem in. output stem out.
call check k "lines through input~linein and output~lineout", sameStem(k)
drop out.
address r "LINES" with input stem in. output stem out.
call check k "lines through input~arrayIn and output~arrayOut", sameStem(k)

big = "x"~copies(n(1000000))
b.0 = n(20); do i = 1 to b.0; b.i = big || i; end
address r "COPY" with input stem b. output stem bo.
ok = bo.0 == b.0
do i = 1 to b.0 while ok; ok = bo.i == b.i; end
call check b.0 "lines of" big~length "characters", ok

j = n(20000)
address r "BOTH" j with output stem s. error stem s.
ok = s.0 == 2 * j
do i = 1 to j while ok
  a = 2 * i - 1; e = 2 * i
  ok = s.a == "o" i & s.e == "e" i
end
call check "output and error to the same stem, interleaved in order", ok

o.0 = 2; o.1 = "keep1"; o.2 = "keep2"
address r "COPY" with input stem in. output append stem o.
call check "OUTPUT APPEND STEM", o.0 == k + 2 & o.1 == "keep1" & o.3 == in.1 & o.[k + 2] == in.k

arr = .array~new(k); do i = 1 to k; arr[i] = i; end
outArr = .array~new
address r "COPY" with input using (arr) output using (outArr)
call check "INPUT / OUTPUT USING arrays", outArr~items == k & outArr[k] == k

f = .File~temporaryPath || "/cmdhandler-torture-" || SysQueryProcess("PID") || ".txt"
fs = .stream~new(f); fs~open("write replace")
address r "COPY" with input stem in. output using (fs)
fs~close
call check "OUTPUT USING a stream", .stream~new(f)~lines == k
call SysFileDelete f

-- the handler changes the stems while the interpreter reads and writes them
address r "MESS" with input stem in. output stem out.
call check "input and output stems changed under the redirection: still answers", rc == "messed"
call note "after MESS: out.0 =" out.0", in.0 =" in.0

-- command strings
cmd = "RET " || "y"~copies(n(10000000))
address r cmd
call check "a" cmd~length "character command", rc~length == cmd~length - 4
address r ""
call check "the empty command", rc == ""
address r "RET" "00"x || "zero" || "0a"x || "lf"
call check "binary characters in the command", rc == "00"x || "zero" || "0a"x || "lf"
exit finish()

sameStem: procedure expose in. out.
  use arg k
  if out.0 \== k then return 0
  do i = 1 to k
    if out.i \== in.i then return 0
  end
  return 1

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class R subclass CommandHandler
::method command
  use arg command, context
  parse var command verb rest
  select case verb
    when "COPY" then do
      in = context~input; out = context~output
      do while in~lines > 0
        out~lineout(in~linein)
      end
      return 0
    end
    when "LINES" then do
      context~output~arrayOut(context~input~arrayIn)
      return 0
    end
    when "BOTH" then do
      do i = 1 to rest
        context~output~lineout("o" i)
        context~error~lineout("e" i)
      end
      return 0
    end
    when "MESS" then do
      in = context~input; out = context~output
      first = in~linein
      context["in.0"] = 1                -- shorten the input under the reader
      context["in.2"] = "changed"
      context~dropVar("out.")           -- the output stem goes away
      do i = 1 to 100
        if in~lines == 0 then leave
        out~lineout(in~linein)
        if i = 50 then context["out.0"] = "not a number"
      end
      return "messed"
    end
    when "RET" then return rest
    otherwise return command
  end
