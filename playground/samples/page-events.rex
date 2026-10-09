/* Events from the page, handled in Rexx: a small to-do panel.  Type an     */
/* item and press Enter (the form's submit, with "preventDefault" so the    */
/* page does not reload), click an item to cross it out, "Done" ends.       */
/* JavaScript only queues each event; .js~eventLoop takes them one by one   */
/* and sends the handler's message, here to the object of class ToDo.       */
doc = .js~page~document
todo = .ToDo~new(doc)
form = doc~createElement("form")
input = doc~createElement("input"); input~placeholder = "Something to do"
done = doc~createElement("button"); done~type = "button"; done~textContent = "Done"
list = doc~createElement("ul")
panel = doc~createElement("div")
st = panel~style
st~position = "fixed"; st~bottom = "24px"; st~right = "24px"; st~zIndex = "1000"
st~background = "#fdfaf3"; st~border = "3px solid #2b5797"; st~borderRadius = "10px"
st~padding = "12px 16px"; st~font = "15px sans-serif"; st~color = "#222"; st~minWidth = "240px"
st~boxShadow = "0 4px 12px rgba(0,0,0,.35)"
form~appendChild(input); form~appendChild(done)
panel~appendChild(form); panel~appendChild(list)
todo~setup(input, list)

-- one handler per kind of event; the list's handler serves every item.
-- Set up before the panel shows: an Enter with no submit handler yet
-- would really submit the form (and reload the page)
form~addEventListener("submit", .js~handler(todo, "add", "preventDefault"))
list~addEventListener("click", .js~handler(todo, "toggle"))
done~addEventListener("click", .js~handler(todo, "done"))
doc~body~appendChild(panel)
input~focus

say "Waiting for events from the panel (bottom right)..."
.js~eventLoop                   -- until ToDo~done calls .js~stopEventLoop
panel~remove
say "Done:" todo~count "item(s)."
exit

::class ToDo
::attribute count
::method init
  expose doc count
  use arg doc
  count = 0
::method setup
  expose input list
  use arg input, list
::method add                    -- the form was submitted (Enter)
  expose doc input list count
  text = input~value~strip
  if text == "" then return
  item = doc~createElement("li")
  item~textContent = text
  item~style~cursor = "pointer"
  list~appendChild(item)
  input~value = ""
  count += 1
  say "added:" text
::method toggle                 -- a click somewhere in the list
  use arg event
  item = event~target           -- (currentTarget is gone by now: the list)
  if item~tagName \== "LI" then return
  if item~style~textDecoration == "line-through" then item~style~textDecoration = ""
  else item~style~textDecoration = "line-through"
  say "toggled:" item~textContent
::method done
  .js~stopEventLoop
::requires "js.cls"
