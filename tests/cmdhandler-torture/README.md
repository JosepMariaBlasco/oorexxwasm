# cmdhandler torture tests

`wasm/tests/cmdhandler.rex` (in the patched ooRexx tree) checks that each
part of cmdhandler — command environments written in Rexx, patch 0009 —
does what it says, once.  These cases check that it *holds*: volume,
concurrency, reentrancy, chained errors, misuse, interruptions.  Each case is
a program of its own, run in a process of its own, with assertions; it exits
0 when everything held.

    ./run.sh REXX [CASE...]

`REXX` is whatever runs a Rexx program: a native `rexx` (or a launcher that
sets `PATH` / `LD_LIBRARY_PATH` for a build tree), or `build-wasm/bin-node/rexx`.
The runner prints one line per case: PASS, FAIL (an assertion failed),
CRASH (killed by a signal), TIMEOUT, EXIT(n) (a Rexx error ended it), or
ASAN (a sanitizer report in a sanitized build; UBSan's `vptr` reports are
ignored: the interpreter restores its image by setting virtual table
pointers itself, and `-fsanitize=vptr` cannot be used with it).

| Variable | Default | |
|---|---|---|
| `TORTURE_SCALE` | 1 | multiplies the counts (0.1–0.2 for WASM or a sanitized build) |
| `TORTURE_TIMEOUT` | 900 | seconds per case |
| `TORTURE_OUT` | a new temporary directory | the logs, one per case |

| Case | What it does (scale 1) |
|---|---|
| `t01-volume` | 1,000,000 commands, each reading and setting a caller's variable; 200,000 with input, output and error redirected; resident memory must reach a plateau |
| `t02-redirect` | 200,000-line stems through `~lineIn` and `~lines`; 20 lines of 1 MB; output and error interleaved into one stem; APPEND; arrays and a stream; the handler changing the input and output stems under the redirection; a 10 MB command, the empty command, binary characters |
| `t03-threads` | 32 threads × 2,000 commands to a guarded handler, an unguarded one and one of their own, each seeing its own variables; one thread registering and removing an environment while 8 others send commands to it |
| `t04-reentry` | 50 levels of handlers issuing commands with redirection, each checking its caller's variables; two handlers calling each other; recursion through the handler until Error 11, 20 times, then everything still works |
| `t05-errors` | SYNTAX after every kind of context call, 2,000 times each; SYNTAX from 1 to 10 levels down; trapped inside the handler with the context still in use; ERROR / FAILURE with CALL ON and SIGNAL ON; USER, HALT, NOTREADY raised in a handler; SYNTAX halfway through the output |
| `t06-context` | every method of a context whose command ended; 100,000 dead contexts kept; a handler that REPLYs and goes on using the context (10,000 calls); the context used from another thread while its command waits; odd RC values; ERROR asked for and then a SYNTAX |
| `t07-halt-trace` | SIGINT to the process while a handler runs, 20 times (where there are signals); TRACE I in the caller and TRACE R in the handler, into a file |
| `t08-registration` | a handler removing or replacing itself during its own command; 10,000 environments added and removed; the same name registered 200,000 times; names in mixed case, 100, 250 and 1,000 characters long, with a blank |

What they found, with the fix for each:

- `RexxInstance::AddCommandEnvironment` changed the instance's table of
  command handlers (allocating objects) without the interpreter lock, so a
  thread registering an environment while another ran Rexx code corrupted
  the object heap (`t03`: hangs and crashes).  An ooRexx fix, outside this
  series.
- Resolving an environment that is not in the instance's table (the lookup
  of a classic registered subcommand handler) wrote into a new
  `CommandHandler` that nothing anchored, with the kernel lock released
  (`CommandHandler::resolve`: `UnsafeBlock` around
  `RexxResolveSubcom(name, &entryPoint)`); another thread's garbage
  collection could free it, and a garbage handler was then cached for that
  environment (`t03`: a crash in 2–6 % of the runs under load, when a
  sender's first command came before the environment's first
  registration).  It happens in plain ooRexx, with no extension: commands
  to an unknown environment from one thread while others run.  An ooRexx
  fix, outside this series.
  With both fixes `t03` passed 200 of 200 runs under load; until they are
  in the base revision it can hang or crash.
- `ApiContext(RexxIORedirectorContext *, bool)`, used by the non-blocking
  redirector queries (`IsInputRedirected` …), left `clearConditions`
  uninitialized: its destructor could clear the activation's condition, and
  without the lock (UBSan, any case).  An ooRexx fix, outside this series.
- cmdhandler let a `.CommandContext` be used from another thread: a method
  that REPLYs and goes on, or a thread the handler hands it to, used the
  command's exit context from the wrong activity, racing with the end of
  the command (`t06`: hangs).  Fixed in patch 0009: such calls raise SYNTAX
  98.900, as calls on a context whose command ended do.

Facts found on the way (expected, no change): an untrapped HALT in a
handler reaches the caller as SYNTAX 4.1 (it is untrapped in the method);
USER, HALT and NOTREADY raised in a handler reach the caller as themselves;
an environment name of 1,000 characters is SYNTAX 29.1; dropping the
output stem inside the handler leaves the caller's new stem untouched by the
redirection (the interpreter keeps writing to the stem it had).
