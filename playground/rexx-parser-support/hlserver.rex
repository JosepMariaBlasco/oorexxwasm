/* hlserver.rex -- ooRexx Playground: highlights the editor's program.        */
/*                                                                            */
/* Runs for as long as the page is open, in a run of its own, so that the     */
/* Rexx Parser is loaded once. Requests come on standard input:               */
/*                                                                            */
/*   "id count style"   then count source lines (style: light or dark)        */
/*                                                                            */
/* and each answer goes to standard output as the Highlighter's HTML,         */
/* followed by a line '1e'x"id OK", or by '1e'x"id ERR line code text" when   */
/* the program has a syntax error (nothing else is written then).             */
/*                                                                            */
/* Uses the Rexx Parser by Josep Maria Blasco (Apache 2.0),                   */
/* https://rexx.epbcn.com/rexx-parser/                                        */

rs = '1e'x
Signal On NotReady
Do Forever
  Parse Value LineIn() With id count style .
  If \DataType(count, "W") Then Iterate
  source = .Array~new(count)
  Do i = 1 To count
    source[i] = LineIn()
  End
  If style \== "light" Then style = "dark"
  Parse Value Highlight(source, style) With status rest
  If status == "OK" Then Do
    Call CharOut , rest
    Say rs || id "OK"
  End
  Else Say rs || id "ERR" rest
End

NotReady:
  Exit

::Routine Highlight
  Use Arg source, style
  Signal On Syntax
  options. = 0
  options.mode  = "HTML"
  options.style = style
  html = .Highlighter~new("program", source, options.)~parse
  If html~isA(.Array) Then html = html~makeString("L", "0a"x)
  Return "OK" html || "0a"x

Syntax:
  co    = Condition("O")
  extra = co~additional~lastItem
  line  = ""
  If extra~isA(.Directory) Then line = extra~position
  Return "ERR" line co~code Ansi.ErrorText(co~code, co~additional)

::Requires "Rexx.Parser.cls"
::Requires "parser/Highlighter.cls"
::Requires "parser/ANSI.ErrorText.cls"
