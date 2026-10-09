/* JDOR: drawing with ADDRESS commands.
   JDOR ("Java Drawing for ooRexx", by Rony G. Flatscher) is the drawing
   command handler of BSF4ooRexx.  Here it draws on the browser's canvas:
   the same commands, no Java.  ::requires "jdor.cls" (at the end) sets up
   the JDOR environment, an image and its window; ADDRESS JDOR selects it.
   The other samples in this group are Rony's, adapted the same way (no BSF).
   Commands: https://sourceforge.net/projects/bsf4oorexx/ */

address jdor                            -- unknown words go to JDOR from now on

w = 480; h = 300
newImage w h                            -- the image (the canvas)
winTitle "Hello, JDOR"
winShow                                 -- and the window that shows it

gradientPaint sky 0 0 midnightBlue 0 h steelBlue
fillRect w h                            -- at the current position: 0 0
color white
do 60                                   -- stars
  moveTo random(0, w) random(0, h - 80)
  fillOval 2 2
end

font big "SansSerif bold 30"
text = "Hello from ooRexx!"
stringBounds text                       -- RC: x y width height
parse var rc . . tw .
moveTo (w - tw) / 2 70
"drawString" text                       -- quoted: keep the case

color ground 40 60 40
moveTo 0 h - 40; fillRect w 40
pushImage scenery                       -- remember the background

-- an animation: draw each frame on the image, show it only when complete
x = 40; y = 120; dx = 5; dy = 0
stroke thin 1
do 160
  winUpdate .false
  moveTo 0 0; drawImage scenery
  color orange; moveTo x y; fillOval 30 30
  color black; drawOval 30 30
  winUpdate .true
  dy += 1; x += dx; y += dy
  if y > h - 70 then do; y = h - 70; dy = -dy * 0.85 % 1; end
  if x < 0 | x > w - 30 then dx = -dx
  sleep 0.02
end

color                                   -- commands return Java-like objects
say "The current color:" rc~toString "(red="rc~red")"
say "Drag the window by its title bar; it stays until the next run."
::requires "jdor.cls"                   -- set up the JDOR environment
