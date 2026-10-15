# The debugger

Dom Wise's [ooRexx debugger](https://sourceforge.net/p/oorexxdebugger/) (MIT,
[`LICENSE`](LICENSE)), with a front end for web pages. Two uses:

- **The playground's Debug** runs a program under the debugger
  (`playground/index.html`, *the debugger*).
- **Pages with `<script type="text/rexx">`**: open the page with
  `?rexx-debug=1` at the end of its address, and `ooRexx.js` loads
  `ooRexx-debugger.js` from its own directory before it runs the scripts. A
  panel at the foot of the page shows the scripts; a click on a line number
  sets a breakpoint (remembered for the page, so a reload stops in the
  scripts' first run), and the scripts, or the handlers they set up, stop
  there. Then Step (F10), Run (F8), Break, the stack, the variables, and Rexx
  run where the program is paused (`say` there shows in the panel). The
  program's output goes to the browser's console, as without the debugger.

## Files

- `RexxDebugger.rex`: the debugger's core, vendored from its git repository
  (`git.code.sf.net/p/oorexxdebugger/code`) at v1.45 (d51f1ee), with one
  addition in `findandloadui` (marked "ooRexx/WASM"): under Emscripten it
  loads `RexxDebuggerWebUI.rex` from its own directory.
- `RexxDebuggerWebUI.rex`: the web front end, class `DebuggerUI` (as the
  debugger's ooDialog and Swing ones). It draws through a JavaScript object
  of the page, `window.orxDebugger`, whose interface is described at the top
  of the file, in two modes: `program` (the playground) and `page`.
- `ooRexx-debugger.js`: the page side for `?rexx-debug=1`. It sets
  `ooRexx.debugger` (`prepare`, `attach`, `instrument`: the hook of
  `ooRexx.js`, described in its first comment and in
  [*ooRexx/WASM and JavaScript*](../docs/ooRexx-WASM-and-JavaScript.md#rexx-from-the-page)),
  and `window.orxDebugger`, the panel (in a shadow root, so that the page's
  styles do not reach it).

Where they go: `ooRexx-debugger.js` next to `ooRexx.js`, and the two `.rex`
files and `LICENSE` in a `debugger/` directory next to it
(`playground/build-site.sh` and `scripts/web-package.sh` do this).

## How a page is debugged

- Each script runs with `::OPTIONS TRACE ?A` appended (as the debugger does
  with the programs it opens; appended, so that no line moves): the script,
  and the routines and methods it defines, trace interactively, and the
  interpreter asks `.DEBUGINPUT`, which the debugger answers. So they run
  slower while debugging; code that does not come from the page's scripts
  (`::REQUIRES`d files) is not traced unless it says so itself.
- The core stops at the first clause of each program and each thread; in a
  page those stops go on by themselves, and only a breakpoint, Break or a
  step waits for the user.
- In a program, the debugger's session ends with the program. A page's
  session lasts as long as the page: the front end gives the core its own
  thread's context as the "main" one.
- The front end's thread waits for the user's actions on the session's
  standard input, which the panel writes (`session.write`), and not for
  JavaScript: while a Rexx thread waits for JavaScript, the bridge may give
  it the page's calls of Rexx, among them the runs of the scripts, and one
  that stopped at a breakpoint there would stop the front end itself. So,
  while debugging, standard input is the debugger's.
- The program's output is not captured (`NOCAPTURE`); trace output is
  dropped, but for errors, which go to the console and the panel.

Tests: `tests/page-debugger/check.py BIN_WEB [ENGINE]` (a page with two
scripts and a click handler: breakpoints, step, Rexx in context, Break,
errors, breakpoints across a reload, the folded panel) and, for the
playground, `tests/playground_check.py`.
