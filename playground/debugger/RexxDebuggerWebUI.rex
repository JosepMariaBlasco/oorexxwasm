/*----------------------------------------------------------------------------*/
/* RexxDebuggerWebUI.rex: a front end for Dom Wise's ooRexx debugger          */
/* (RexxDebugger.rex, https://sourceforge.net/p/oorexxdebugger/) in a web     */
/* page, for the WebAssembly build of ooRexx.                                 */
/*                                                                            */
/* The debugger's core asks its front end, the class DebuggerUI, to show the  */
/* source, the current line, the stack, the variables and the console, and    */
/* waits in GetUINextResponse for what the user does.  Here the drawing is    */
/* done by the page: a JavaScript object, window.orxDebugger, that the page   */
/* provides (the playground's is in its index.html).  What the user does      */
/* comes back as calls of a queued handler, which this front end's thread     */
/* takes from the event queue (.js~runEventLoop).                             */
/*                                                                            */
/* window.orxDebugger, called from Rexx:                                      */
/*   begin(handler)             a session starts; handler(kind, data) is how  */
/*                              the page reports the user's actions: "step",  */
/*                              "run", "exec" (data: the instructions),       */
/*                              "break", "exit", "bp" (data: "line on|off")   */
/*   setSource(name, lines)     the program (lines: its source, an array)     */
/*   getBreakpoints()           the lines with a breakpoint (an array)        */
/*   stopAt(name, line, stack, index)  stopped at line of the source name;    */
/*                              stack: one string per frame, index: current   */
/*   setVars(rows)              the variables: an array of [name, value]      */
/*   setWaiting(flag)           whether the debugger waits for the user       */
/*   write(text, newline)       console output (the program's, the debugger's)*/
/*   clearConsole()                                                           */
/*   end()                      the session is over                           */
/*                                                                            */
/* Copyright (c) 2026 Josep Maria Blasco.  MIT License, as RexxDebugger.rex.  */
/*----------------------------------------------------------------------------*/

::requires "js.cls"

::class DebuggerUI public

------------------------------------------------------
::method BuildGetThreadIdRoutine class
------------------------------------------------------
return .Routine~new("", "return .context~Thread")

------------------------------------------------------
::method init
------------------------------------------------------
expose debugger front awaiting response sourcename ended started
use arg debugger, watchhelperclass, debughelperclass
started = .false
front = .js~page~js.getStrict("orxDebugger")
awaiting = .false
response = ''
sourcename = ''
ended = .false

------------------------------------------------------
::method RunUI unguarded
------------------------------------------------------
-- The front end's thread: it takes the page's events until the session is over.
expose debugger front
front~begin(.js~handler(self, "UIEVENT"))
debugger~FlagUIStartupComplete
.js~runEventLoop
front~end

------------------------------------------------------
::method UIEVENT unguarded
------------------------------------------------------
-- What the user did (called by the event loop, on the front end's thread).
expose debugger sourcename awaiting
use arg kind, data = ''
select case kind
  when "step" then self~Respond("NEXT")
  when "run"  then self~Respond("RUN")
  when "exec" then if data \= '' then self~Respond(data)
  when "break" then if \awaiting then debugger~SetManualBreak(.true)
  when "exit" then do
    if awaiting then self~Respond("EXIT")
    else do
      debugger~informshutdown     -- the next clause ends the program
      .js~stopEventLoop
    end
  end
  when "bp" then do
    parse var data line state
    if sourcename \= '' then do
      if state = "on" then debugger~SetBreakPoint(sourcename, line)
      else debugger~ClearBreakPoint(sourcename, line)
    end
  end
  otherwise nop
end

------------------------------------------------------
::method Respond
------------------------------------------------------
-- Guarded: releasing the guard is what wakes GetUINextResponse's GUARD WHEN.
expose awaiting response
if \awaiting then return
response = arg(1)
awaiting = .false

------------------------------------------------------
::method GetUINextResponse unguarded
------------------------------------------------------
-- Called by the core on the program's thread: wait until the user acts.
expose front awaiting response
response = ''
awaiting = .true
front~setWaiting(.js~true)
guard off when awaiting = .false
front~setWaiting(.js~false)
return response

------------------------------------------------------
::method AppendUIConsoleText unguarded
------------------------------------------------------
-- Never SAY here: the program's output comes this way too.
expose front
use arg text, newline = .true
front~write(text~string, .js~bool(newline))

------------------------------------------------------
::method ClearUIConsole unguarded
------------------------------------------------------
expose front
front~clearConsole

------------------------------------------------------
::method InitUISource unguarded
------------------------------------------------------
expose front debugger sourcename started
use arg arrSource, name
sourcename = name
started = .true
front~setSource(name, arrSource)
-- breakpoints the user set before the session started
bps = front~getBreakpoints
do i = 1 to bps~length
  debugger~SetBreakPoint(name, bps[i])
end

------------------------------------------------------
::method ResetUISourceState unguarded
------------------------------------------------------

------------------------------------------------------
::method SetUISourceListInfoText unguarded
------------------------------------------------------
use arg list
do line over list
  self~AppendUIConsoleText(line)
end

------------------------------------------------------
::method UpdateUIControlStates unguarded
------------------------------------------------------
-- The session is over when the core says so (finished), or when, once a program
-- was loaded, it can open another one (after EXIT, for example): the debugger
-- then ends, and with it the run.
expose ended started debugger
use arg finished = .false
if \ended, finished = .true | (started = .true & debugger~canopensource = .true) then do
  ended = .true
  .js~stopEventLoop                 -- RunUI returns: the debugger ends, and the run with it
end

------------------------------------------------------
::method UpdateUICodeView unguarded
------------------------------------------------------
expose front
use arg frames, index
if frames = .nil then return
stack = .array~new
do i = 1 to frames~items
  f = frames[i]
  name = ''
  if f~executable \= .nil, f~executable~package \= .nil then name = FILESPEC('N', f~executable~package~name)
  stack~append(name':'f~line' 'f~traceline~strip)
end
f = frames[index]
name = ''
if f~executable \= .nil, f~executable~package \= .nil then name = f~executable~package~name
front~stopAt(name, f~line, stack, index)

------------------------------------------------------
::method UpdateUIWatchWindows unguarded
------------------------------------------------------
-- The variables, as name = value.  While their strings are made, the core does
-- not trace this thread (as RexxDebugger.rex's WatchHelper does).
expose front debugger
use arg variables
if variables = .nil then return
rows = .array~new
debugger~uithreadid = .context~Thread
do name over variables~allindexes~sort
  if name~left(1) = '.' then iterate
  rows~append(.array~of(name, ValueText(variables[name])))
end
debugger~uithreadid = 0
front~setVars(rows)

------------------------------------------------------
::routine ValueText
------------------------------------------------------
use arg v
if v = .nil then t = 'The NIL object'
else if v~isA(.String) then t = v
else if v~isA(.MutableBuffer) then t = v~string
else t = v~defaultname
if v \= .nil, v~isInstanceOf(.Collection) then do
  t = t' ('v~items' item'
  if v~items \= 1 then t = t's'
  t = t')'
end
if v \= .nil, v~hasmethod("makedebuggerstring") then t = t' ['DebuggerString(v)']'
t = t~changestr('0d'x, '<CR>')~changestr('0a'x, '<LF>')~changestr('00'x, '<NUL>')
if t~length > 200 then t = t~left(200)'...'
return t

------------------------------------------------------
::routine DebuggerString
------------------------------------------------------
use arg v
signal on syntax
return v~makedebuggerstring~string
syntax: return '?'
