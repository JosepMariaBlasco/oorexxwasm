/* app.rex: a <script type="text/rexx" src="app.rex"> of index.html.        */
/* It gives the button a handler: a method of a Rexx object, which the      */
/* session runs each time the button is clicked.                            */
doc = .js~page~document
counter = .Counter~new(doc~getElementById("clicks"))
doc~getElementById("clicker")~addEventListener("click", .js~handler(counter, "CLICKED"))
say "app.rex ran."

::requires "js.cls"

::class Counter
::method init
  expose output count
  use arg output
  count = 0
::method clicked
  expose output count
  count += 1
  if count = 1 then output~textContent = "Rexx counted 1 click."
  else output~textContent = "Rexx counted" count "clicks."
