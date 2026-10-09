/* The console understands ANSI escape sequences (SGR): colors and styles. */
/* ESC is '1b'x; "ESC[...m" sets the style, "ESC[0m" resets it.            */
esc = '1b'x
reset = esc || '[0m'

say sgr(1, "bold") sgr(2, "dim") sgr(3, "italic") sgr(4, "underline"),
    sgr(9, "struck") sgr(7, " inverse ")
say

names = "black red green yellow blue magenta cyan white"
line = ""; bright = ""
do i = 0 to 7
  line   = line   sgr(30 + i, left(word(names, i + 1), 7))
  bright = bright sgr(90 + i, left(word(names, i + 1), 7))
end
say "normal:" line
say "bright:" bright
line = ""
do i = 0 to 7;  line = line || sgr(40 + i, "   ");  end
do i = 0 to 7;  line = line || sgr(100 + i, "   "); end
say "backgr:" line
say

say "256 colors, the 6x6x6 cube (ESC[48;5;n m):"
do g = 0 to 5
  line = ""
  do r = 0 to 5
    do b = 0 to 5
      line = line || sgr("48;5;" || 16 + 36 * r + 6 * g + b, "  ")
    end
    line = line" "
  end
  say line
end
line = ""
do n = 232 to 255; line = line || sgr("48;5;" || n, "  "); end
say line
say

say "24-bit color (ESC[38;2;r;g;b m):"
text = "The quick brown fox jumps over the lazy dog, in true color."
line = ""
do i = 1 to length(text)
  t = (i - 1) / (length(text) - 1)
  r = format(255 * (1 - t), , 0); b = format(255 * t, , 0); g = format(120 + 100 * t * (1 - t), , 0)
  line = line || esc || "[1;38;2;" || r || ";" || g || ";" || b || "m" || substr(text, i, 1)
end
say line || reset

.error~lineout(sgr("1;31", "stderr can be colored too."))
exit

sgr:  /* sgr(codes, text): text in that style, then reset */
  return esc || '[' || arg(1) || 'm' || arg(2) || reset
