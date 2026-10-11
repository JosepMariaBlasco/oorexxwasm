# RFE #879 update, 5 October 2026: patch 0009 marks trace, error and plain output for web pages

*Posted as a comment on [RFE #879](https://sourceforge.net/p/oorexx/feature-requests/879/), with the revised attachment, which is there; the title is added here.*

**Why 0009 changed.** In a terminal, trace output and error messages simply
go to stderr, and the user tells them apart by reading. A web page can do
better (show trace, errors and plain output in different colors, and tell
when the program is waiting for interactive trace input rather than for
data), but only if it knows which is which. That knowledge exists only
inside the interpreter: by the time the bytes reach the page they are all
just stderr, since `.traceOutput` writes to `.error` by default. Guessing
from the text is fragile: a program can write text that looks like trace,
an error's traceback is trace while the error message is not, and nothing in
the output says whether a read comes from `.debugInput` or from `PULL`. This
was asked for on the list (Rony: different colors for `.output`, `.error`,
`.traceOutput`, `.input` and `.debugInput`).

**How, and at what cost.** The interpreter now marks what it is doing,
without changing what it does. `Activity::traceOutput`,
`display`/`displayDebug` and `traceInput` call a weak hook,
`orx_wasm_mark()`, defined only by the browser build. Everywhere else the
call vanishes: an empty class outside `__EMSCRIPTEN__`, and a null weak
symbol in the other WebAssembly builds. The marks travel in two reserved
words of the shared standard-input ring, and the page API passes them on as
`onOut/onErr(text, kind)` and `onInput({debug})`. Trace still goes wherever
`.traceOutput` sends it; the page just learns what each byte is. Native
builds compile it warning-free and produce byte-identical output, and the
TRACE groups of the official test suite pass natively and under
WebAssembly.
