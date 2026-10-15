-- the button's handler
btn = .js~page~document~getElementById("btn")
btn~addEventListener("click", .js~handler(.Counter~new, "CLICK"))
say "handlers set"

::class Counter
::method init
  expose count
  count = 0
::method click
  expose count
  count = count + 1
  if count = 4 then say 1 +- "x"         -- an error, on the fourth click
  .js~page~document~getElementById("out")~textContent = "clicked" count
