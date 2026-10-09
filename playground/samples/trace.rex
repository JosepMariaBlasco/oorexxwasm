/* TRACE ?R pauses after each clause: press Enter to go on, or type a     */
/* Rexx instruction to run it there (say total, total = 100, trace off).  */
trace ?r
total = 0
do i = 1 to 3
  total = total + i * i
end
say "Sum of squares:" total
