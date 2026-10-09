/* Reads its standard input from the box above the console.              */
/* Clear the box to type the lines interactively instead (Ctrl+D ends).  */
count. = 0; words = 0; lines = 0
seen = .array~new
do while lines() > 0
  line = linein()
  lines += 1
  do w over line~translate(" ", ".,;:!?")~lower~makeArray(" ")
    if w = "" then iterate
    if count.w = 0 then seen~append(w)
    count.w += 1; words += 1
  end
end
say lines "lines," words "words," seen~items "different"
say
do w over seen
  if count.w > 1 then say right(count.w, 4) w
end
