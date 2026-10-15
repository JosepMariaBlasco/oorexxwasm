/*----------------------------------------------------------------------------*/
/* RexxDebuggerWebUI.rex: a front end for Dom Wise's ooRexx debugger          */
/* (RexxDebugger.rex, https://sourceforge.net/p/oorexxdebugger/) in a web     */
/* page, for the WebAssembly build of ooRexx.                                 */
/*                                                                            */
/* The debugger's core asks its front end, the class DebuggerUI, to show the  */
/* source, the current line, the stack, the variables and the console, and    */
/* waits in GetUINextResponse for what the user does.  Here the drawing is    */
/* done by the page: a JavaScript object, window.orxDebugger, that the page   */
/* provides (the playground's is in its index.html; for pages with           */
/* <script type="text/rexx">, ooRexx-debugger.js).  The front end's thread    */
/* asks the page for the user's next action and waits for it (a Promise):     */
/* it never takes events, which in a page belong to the page's own handlers.  */
/*                                                                            */
/* Two modes, window.orxDebugger.mode:                                        */
/*   "program"  the core runs a program (the playground's Debug): the         */
/*              session ends with it, and every stop waits for the user       */
/*   "page"     the page's scripts trace (::OPTIONS TRACE ?A), and so do the  */
/*              handlers they set up, long after the scripts are done: the    */
/*              session lasts as long as the page, and a stop that is not a   */
/*              breakpoint, a Break or a step (the core stops at the first    */
/*              clause of each program and of each thread) goes on by itself; */
/*              the program's output goes where it would go without the       */
/*              debugger, and trace output is dropped, but for errors; the    */
/*              user's actions come by standard input (see next() below)      */
/*                                                                            */
/* window.orxDebugger, called from Rexx:                                      */
/*   mode                       "program" or "page"                           */
/*   begin()                    a session starts                              */
/*   next()                     (program mode) a Promise of the user's next   */
/*                              action, a string: "step", "run", "exec        */
/*                              INSTRUCTIONS", "break", "exit", "bp NAME|LINE */
/*                              on|off", or "end" (from wake()); in page mode */
/*                              the page writes the same strings, one per     */
/*                              line, to the session's standard input         */
/*   wake()                     make the pending next() answer "end"          */
/*   setSource(name, lines)     a program's source (lines: an array)          */
/*   getBreakpoints()           the breakpoints, an array of "NAME|LINE"      */
/*   stopAt(name, line, stack, index)  stopped after line of name; stack:     */
/*                              one string per frame, index: the current one  */
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
expose debugger front awaiting response sourcename ended started pagemode sources stepping breakpoints lastwhere manual
use arg debugger, watchhelperclass, debughelperclass
front = .js~page~js.getStrict("orxDebugger")
pagemode = front~mode = "page"
started = .false
awaiting = .false
response = ''
sourcename = ''
ended = .false
sources = .Set~new
stepping = .false
breakpoints = .Set~new          -- "name>line", as the core keys them
lastwhere = ''
manual = .false

------------------------------------------------------
::method RunUI unguarded
------------------------------------------------------
-- The front end's thread: it waits for the user's actions until the session is over.
expose debugger front ended pagemode
front~begin
if pagemode then do
  -- No main program: the core takes the session for over when its main context
  -- ends, and this thread's lasts as long as the debugger.
  .local~debuggermaincontext = .context
  .traceOutput~destination(.PageTraceOutput~new(self, .traceOutput~current))
  self~LoadBreakpoints
end
debugger~FlagUIStartupComplete
do while \ended
  -- A page: the actions come as lines of standard input (the page writes them
  -- with session.write).  While a thread waits for JavaScript, the bridge may
  -- give it the page's calls of Rexx, the scripts' runs among them: one that
  -- stopped there would stop this thread, which must stay free for the user.
  -- A thread reading standard input waits in shared memory, and runs nothing.
  if pagemode then action = linein()
  else action = front~next~await
  parse var action kind data
  if kind = "end" then leave
  self~UIEVENT(kind, data)
end
front~end

------------------------------------------------------
::method UIEVENT unguarded
------------------------------------------------------
-- What the user did (on the front end's thread).
expose debugger awaiting ended stepping breakpoints
use arg kind, data = ''
select case kind
  when "step" then do; stepping = .true; self~Respond("NEXT"); end
  when "run"  then do; stepping = .false; self~Respond("RUN"); end
  when "exec" then if data \= '' then do; stepping = .true; self~Respond(data); end
  when "break" then if \awaiting then debugger~SetManualBreak(.true)
  when "exit" then do
    if awaiting then self~Respond("EXIT")
    else do
      debugger~informshutdown     -- the next clause ends the program
      ended = .true
    end
  end
  when "bp" then do
    parse var data name "|" line state
    if state = "on" then do
      debugger~SetBreakPoint(name, line)
      breakpoints~put(name">"line)
    end
    else do
      debugger~ClearBreakPoint(name, line)
      breakpoints~remove(name">"line)
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
-- Called by the core on the program's thread: wait until the user acts.  In a
-- page, a stop that is no breakpoint, Break or step goes on at once.
expose front awaiting response pagemode stepping breakpoints lastwhere manual
if pagemode, \stepping, \manual, \breakpoints~hasindex(lastwhere) then return "RUN"
manual = .false
response = ''
awaiting = .true
front~setWaiting(.js~true)
guard off when awaiting = .false
front~setWaiting(.js~false)
return response

------------------------------------------------------
::method AppendUIConsoleText unguarded
------------------------------------------------------
-- Never SAY here: the program's output may come this way too.
expose front manual
use arg text, newline = .true
if text~string~pos("Automatic breakpoint hit") > 0 then manual = .true    -- a Break
front~write(text~string, .js~bool(newline))

------------------------------------------------------
::method ClearUIConsole unguarded
------------------------------------------------------
expose front
front~clearConsole

------------------------------------------------------
::method InitUISource unguarded
------------------------------------------------------
-- The program the core runs (program mode).
expose front sourcename started sources
use arg arrSource, name
sourcename = name
started = .true
sources~put(name)
front~setSource(name, arrSource)
self~LoadBreakpoints

------------------------------------------------------
::method LoadBreakpoints unguarded
------------------------------------------------------
-- Breakpoints the user set before the session started.
expose front debugger breakpoints
bps = front~getBreakpoints
do i = 1 to bps~length
  parse value bps[i] with name "|" line
  debugger~SetBreakPoint(name, line)
  breakpoints~put(name">"line)
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
-- Program mode: the session is over when the core says so (finished), or when,
-- once a program was loaded, it can open another one (after EXIT, for example):
-- the debugger then ends, and with it the run.  A page's session never ends.
expose ended started debugger pagemode front
use arg finished = .false
if pagemode then return
if \ended, finished = .true | (started = .true & debugger~canopensource = .true) then do
  ended = .true
  front~wake
end

------------------------------------------------------
::method UpdateUICodeView unguarded
------------------------------------------------------
expose front sources lastwhere pagemode
use arg frames, index
if frames = .nil then return
stack = .array~new
do i = 1 to frames~items
  f = frames[i]
  name = ''
  if f~executable \= .nil, f~executable~package \= .nil then name = f~executable~package~name
  -- a page: below the page's code are the bridge's frames (js.cls, the session)
  if pagemode, i > index, name = '' | name = "REXX" | name~pos("/usr/lib/ooRexx/") = 1 | FILESPEC('N', name) = "ooRexx-session.rex" then leave
  line = f~traceline~strip
  if line~pos("*-*") > 0 then line = line~substr(line~pos("*-*") + 3)~strip
  stack~append(FILESPEC('N', name)':'f~line'  'line)
end
f = frames[index]
name = ''
if f~executable \= .nil, f~executable~package \= .nil then do
  name = f~executable~package~name
  if \sources~hasindex(name) then do      -- the first stop in a program: its source
    sources~put(name)
    source = f~executable~package~source
    if source \= .nil then front~setSource(name, source)
  end
end
lastwhere = name">"f~line
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
::class PageTraceOutput
------------------------------------------------------
-- Page mode: every traced clause would be trace output.  Only errors go on to
-- where trace output went before (the console), and to the debugger's console.
::method init
expose ui original
use arg ui, original
::method lineout
expose ui original
use arg line
if \line~isA(.String) then line = line~makestring      -- a TraceObject (ooRexx 5.1)
if line~strip~left(5) = "Error" | line~strip~pos("+++ Interactive trace.  Error") = 1 then do
  original~lineout(line)
  ui~AppendUIConsoleText(line)
end
return 0
::method say
forward message("LINEOUT")
::method charout
return 0

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
