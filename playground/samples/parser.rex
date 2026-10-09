/* The Rexx Parser, by Josep Maria Blasco, comes preloaded:                  */
/* ::requires "Rexx.Parser.cls" (and "parser/Highlighter.cls" to highlight), */
/* or call its utilities: call highlight "-a prog.rex", call elements ...    */
/* Docs: https://rexx.epbcn.com/rexx-parser/                                 */

source = .context~package~source          -- this very program

-- 1. The Highlighter, in ANSI mode (the console understands the colors)
options. = 0
options.mode  = "ANSI"
options.style = "dark"                     -- try "light", "tokio-night"...
say .Highlighter~new("parser.rex", source, options.)~parse

-- 2. The Element API: walk the elements the parser found
parser   = .Rexx.Parser~new("parser.rex", source)
element  = parser~firstElement
keywords = .Bag~new
count    = 0
Loop Until element == .Nil
  count += 1
  If element < .EL.KEYWORD Then keywords~put(Upper(element~value))
  element = element~next
End
say count "elements; keywords used:"
Do kw Over keywords~uniqueIndexes~sort
  call charout , kw"("keywords~items(kw)") "
End
say

::Requires "Rexx.Parser.cls"
::Requires "parser/Highlighter.cls"
