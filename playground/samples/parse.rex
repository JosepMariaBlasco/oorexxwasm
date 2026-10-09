/* PARSE: templates with literals, positions and variables               */
date = "2026-10-04"
parse var date year "-" month "-" day
say "year" year", month" month", day" day

record = "Blasco     Josep Maria   Barcelona"
parse var record surname 12 first 26 city
say "["strip(first)"] ["strip(surname)"] ["city"]"

sentence = "The quick brown fox jumps over the lazy dog"
parse var sentence first second rest
say "first:" first" second:" second" rest:" rest
say "words:" words(sentence)", longest:" longest(sentence)

parse value "key=value; other=thing" with k1 "=" v1 ";" k2 "=" v2
say k1 "->" v1"," strip(k2) "->" v2
exit

longest: procedure
  parse arg text
  best = ""
  do w over text~makeArray(" ")
    if length(w) > length(best) then best = w
  end
  return best
