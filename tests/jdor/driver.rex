/* runs the JDOR commands of file arg(1), one per line, as the Java harness does */
parse arg file
call addJdorHandler
cmds = .stream~new(file)~arrayIn
out = .array~new; err = .array~new
address jdor with output append using (out) error append using (err)
do line over cmds
  w = line~word(1)~upper
  if w~left(3) == "WIN" | w == "SLEEP" | w == "PRINTIMAGE" then iterate
  line
  if .rs \= 0 then say "["line"] ->" (.rs < 0)~?("FAILURE", "ERROR") rc
  else if rc~isA(.JdorObject) then say "["line"] ->" rc~toString
  else say "["line"] ->" rc
end
do e over err; say "E:" e; end
do o over out; say "O:" o; end
::requires "jdor.cls"
