/* JavaScript objects as Rexx objects (js.cls): .js is JavaScript's        */
/* globalThis here (the Web Worker that runs ooRexx).  Names are           */
/* case-insensitive; o["exactName"] and o~invoke("name", ...) are exact.   */
say "Math:" .js~Math~max(3, 7) .js~Math~PI
say "Today:" .js~Date~new~toLocaleDateString("es-ES")

-- JavaScript collections stay JavaScript objects (by reference)
m = .js~Map~new
m~set("uno", 1); m~set("dos", .js~num(2))      -- strings stay strings: .js~num
say "Map size" m~size "- dos is a" .js~eval("(m) => typeof m.get('dos')")~invoke(.nil, m)

-- a Directory becomes a plain object; JSON both ways
o = .js~newObject(.directory~of(("lang", "ooRexx"), ("year", .js~num(1996))))
say .js~JSON~stringify(o)
a = .js~JSON~parse("[1, 1, 2, 3, 5, 8]")
do x over a; call charout , x" "; end; say

-- fetch returns a Promise: ~await waits for it (this file is the Rexx
-- Parser, which colors the editor: a JSON object of file name -> contents)
files = .js~fetch("rexx-parser.json")~await~json~await
say "The editor's Rexx Parser has" .js~Object~keys(files)~length "files."

-- a JavaScript exception is a Rexx SYNTAX condition
signal on syntax
.js~JSON~parse("{oops")
syntax:
  say "Caught:" condition("O")~message

::requires "js.cls"
