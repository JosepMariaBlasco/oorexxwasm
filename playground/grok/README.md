# Grokking in Rexx

A page of the Playground site (`grok/`, live at
https://rexx.epbcn.com/oorexx-wasm/grok/): a small neural network written in
ooRexx learns addition modulo 13 in the browser, and draws what happens inside
it while it learns. Left, the program, highlighted by the Rexx Parser (also run
in Rexx, once, when the page loads). Right, Run, and the window the program
draws into with `ADDRESS JDOR`: losses and accuracies, the table of sums as the
network answers it, and the Fourier energy of its embeddings, which shows the
circles the network finds when it groks (at epoch 904 with the defaults).

- `index.html` — the page (no outside dependencies). It takes the runtime
  (`ooRexx.js` and the files next to it), `rexx-parser.json`,
  `rexx-parser/rexx-light.css` and `fonts/` from the Playground site, one
  directory up, so it needs no copies of them, and the same COOP/COEP headers.
  The JDOR frames (`onJdor`: `window`, `frame`) go to a canvas of the page
  instead of the Playground's floating windows.
- `grok-live.rex` — the program: `grok.rex` 0.4 by Josep Maria Blasco (the
  network, its AdamW training and its instruments, in plain ooRexx with
  rxmath), with no checkpoints and with drawing routines added. Same seed,
  same numbers: its trace is the same, line for line, as grok.rex's under
  native ooRexx.
- `oryx.svg` — the ooRexx logo by Graham Wilson.

`build-site.sh` copies the directory (but this README) to `$OUT/grok/`.
