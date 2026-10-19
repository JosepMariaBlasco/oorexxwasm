/* t01-volume: many commands in a row.  Each one creates a .CommandContext   */
/* and goes through the native handler; memory must reach a plateau.         */
signal on syntax name unexpected
.CommandHandler~register("V", .V~new)

total = n(1000000)
x = 0
mark = total % 5
do i = 1 to total
  address v "INC" i
  if rc \== i then leave
  if i = mark then rss0 = rss()
end
rss1 = rss()
call check total "commands, each answered with its own RC", i > total
call check "the caller's variable updated by every command", x == total

m = n(200000)
in.0 = 2; in.1 = "a"; in.2 = "b"
mark = m % 5
do i = 1 to m
  address v "COPY" with input stem in. output stem out. error stem err.
  if out.0 \== 2 | out.2 \== "b" | err.0 \== 1 then leave
  if i = mark then rss2 = rss()
end
rss3 = rss()
call check m "commands with input, output and error redirected", i > m

if rss0 \== "" then do
  call note "RSS (KB): plain" rss0 "->" rss1"; redirected" rss2 "->" rss3
  call check "plain commands: no growth after the first fifth", rss1 - rss0 < 16384
  call check "redirected commands: no growth after the first fifth", rss3 - rss2 < 16384
end
exit finish()

unexpected:
  say "UNEXPECTED" describe(condition("O")) "line" sigl
  exit 2

::requires "common.cls"

::class V subclass CommandHandler
::method command
  use arg command, context
  parse var command verb n
  if verb == "INC" then do
    context~setVar("x", context~getVar("x") + 1)
    return n
  end
  -- COPY: the input to the output, and one line to the error
  in = context~input; out = context~output
  do while in~lines > 0
    out~lineout(in~linein)
  end
  context~error~lineout("done")
  return 0
