/* A clock drawn on this page by Rexx: every second the program changes a  */
/* DOM element (SVG hands) and takes it away after 20 seconds.  (Stop      */
/* ends the run at once: the clock then stays until you reload the page.)  */
doc = .js~page~document
ns = "http://www.w3.org/2000/svg"
svg = doc~createElementNS(ns, "svg")
svg~setAttribute("viewBox", "-100 -100 200 200")
st = svg~style
st~position = "fixed"; st~bottom = "24px"; st~right = "24px"; st~width = "160px"
st~height = "160px"; st~zIndex = "1000"; st~filter = "drop-shadow(0 4px 12px rgba(0,0,0,.35))"
call add "circle", "r 95 fill #fdfaf3 stroke #2b5797 stroke-width 6"
do h = 0 to 11                                           -- hour marks
  a = h * 30
  call add "line", "x1 0 y1 -80 x2 0 y2 -90 stroke #2b5797 stroke-width 4 transform rotate("a")"
end
hours = add("line", "x1 0 y1 10 x2 0 y2 -50 stroke #222 stroke-width 7 stroke-linecap round")
mins  = add("line", "x1 0 y1 12 x2 0 y2 -72 stroke #222 stroke-width 4 stroke-linecap round")
secs  = add("line", "x1 0 y1 16 x2 0 y2 -80 stroke #c0392b stroke-width 2")
doc~body~appendChild(svg)
do 20
  parse value time() with hh ":" mm ":" ss
  call turn hours, (hh // 12) * 30 + mm / 2
  call turn mins, mm * 6 + ss / 10
  call turn secs, ss * 6
  call SysSleep 1
end
svg~remove
say "The clock is gone."
exit

add: procedure expose doc ns svg      -- add(tag, "attr value attr value ...")
  parse arg tag, attrs
  e = doc~createElementNS(ns, tag)
  do while attrs \= ""
    parse var attrs k v attrs
    e~setAttribute(k, v)
  end
  svg~appendChild(e)
  return e

turn: procedure                      -- rotate a hand to deg degrees
  use arg hand, deg
  hand~setAttribute("transform", "rotate("deg")")
  return
::requires "js.cls"
