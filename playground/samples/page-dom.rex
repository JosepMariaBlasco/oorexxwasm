/* Programming the page: .js~page is this page's window, with its DOM.     */
/* The program adds a note to the page, asks you something with the        */
/* browser's own dialogs, and takes the note away again.                   */
w = .js~page
doc = w~document
say "This page is" doc~title "-" w~innerWidth"x"w~innerHeight "pixels, language" w~navigator~language

note = doc~createElement("div")
note~textContent = "Hello from Rexx! This note is a DOM element made by your program."
s = note~style
s~position = "fixed"; s~top = "20px"; s~right = "20px"; s~zIndex = "1000"
s~padding = "16px 20px"; s~maxWidth = "320px"; s~borderRadius = "10px"
s~background = "#2b5797"; s~color = "white"; s~font = "15px system-ui, sans-serif"
s~boxShadow = "0 6px 20px rgba(0,0,0,.3)"
doc~body~appendChild(note)

name = w~prompt("What's your name?", "Rexx fan")      -- the page waits for you; so does Rexx
if name == .nil then name = "stranger"                  -- Cancel: null, so .nil
note~textContent = "Hello," name"! Watch this note fade away."
say "You are" name

do i = 10 to 0 by -1                                    -- an animation, step by step
  s~opacity = i / 10
  call SysSleep 0.15
end
note~remove
if w~confirm("Shall I change this tab's title?") then do
  old = doc~title
  doc~title = "Changed by Rexx!"
  say "Look at the tab's title. It goes back in 3 seconds."
  call SysSleep 3
  doc~title = old
end
say "Done."
::requires "js.cls"
