/* rxregexp: the regular expressions of ooRexx                            */
/* (its own syntax: "?" is any character, "*" repeats, "[...]" a set)     */
word = .RegularExpression~new("[a-z]+")
do candidate over "rexx", "Rexx", "ooRexx 5"
  say left(candidate, 10) "all lowercase letters?" word~match(candidate)
end
say
number = .RegularExpression~new("[0-9][0-9]*")
text = "Rexx was born in 1979; ooRexx 5.3 runs in 2026"
rest = text
do while rest \= ""
  p = number~pos(rest)
  if p = 0 then leave
  len = number~position - p + 1     -- POSITION: where the match ended
  if len <= 0 then leave
  say "number at" length(text) - length(rest) + p":" substr(rest, p, len)
  rest = substr(rest, p + len)
end
::requires "rxregexp.cls"
