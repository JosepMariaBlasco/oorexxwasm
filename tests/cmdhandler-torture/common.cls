/* common.cls: what the cmdhandler torture cases share.                       */
/*                                                                            */
/* check(name, condition) prints "ok  " or "FAIL" and counts; finish()        */
/* prints the totals and returns the exit status (1 when something failed).   */
/* n(base) scales a count by the environment variable TORTURE_SCALE           */
/* (default 1; lighter runs, as under WASM, use e.g. 0.1). rss() is the       */
/* resident memory in KB, or "" where there is no /proc.                      */

.local~tortureOk = 0
.local~tortureBad = 0

::requires "cmdhandler.cls"

::routine scale public
  s = value("TORTURE_SCALE", , "ENVIRONMENT")
  if \datatype(s, "N") then s = 1
  return s

::routine n public
  use strict arg base
  return max(1, trunc(base * scale()))

::routine check public
  use strict arg name, cond
  if cond == 1 then do
    .local~tortureOk = .local~tortureOk + 1
    say "ok  " name
  end
  else do
    .local~tortureBad = .local~tortureBad + 1
    say "FAIL" name
  end
  return cond == 1

::routine note public
  use strict arg text
  say "      " text

::routine finish public
  say .local~tortureOk "passed," .local~tortureBad "failed"
  return .local~tortureBad > 0

::routine rss public
  f = "/proc/self/status"
  if \SysFileExists(f) then return ""
  s = .stream~new(f)
  if s~open("read") \= "READY:" then return ""
  kb = ""
  do 200
    l = s~linein
    if s~state \== "READY" then leave
    if l~startsWith("VmRSS:") then do
      parse var l . kb .
      leave
    end
  end
  s~close
  return kb

-- what a caught condition looked like, for the record
::routine describe public
  use strict arg co
  if co == .nil then return "(no condition)"
  d = co~condition
  if co~code \== .nil then d ||= " " || co~code
  if co~description \== .nil, co~description \== "" then d ||= " (" || co~description || ")"
  return d
