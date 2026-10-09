# Provenance of the patches

## Tom Dyer's dev1 patch (now inside 0001)

The port started from Tom Dyer's "dev1" patch. In the current series it lives
on in `0001-wasm-build-and-base-runtime.patch`: about four fifths of its code
lines (measured 04/10/2026). Its QUALIFICATION.md and evidence log were not
carried over.

- **Origin:** posted to the ooRexx developers' list (oorexx-devel,
  lists.sourceforge.net) by Tom Dyer, 25/09/2026, subject
  "Patch for oorexx 5.3.0 -> WASM Javascript ...". Archive:
  https://sourceforge.net/p/oorexx/mailman/message/59399062/
  The patch carried no license statement of its own (its new files had no
  headers).
- **License confirmation**, same list, thread on that message, 04/10/2026:
  - Josep Maria Blasco: "Before any of this goes near trunk: Tom, could you
    confirm here on the list that you contribute dev1 under the Common Public
    License 1.0, so that RexxLA can include it (and derivatives of it) in
    ooRexx? It's just to keep the provenance of the code clean — the same we'd
    ask of any contribution."
  - Tom Dyer: "Yes. Any and all submissions, past, now and ongoing which
    I make to the ooRexx Language implementation are being provided under
    Common Public License 1.0."
  - Archive: https://sourceforge.net/p/oorexx/mailman/message/59407162/
- **Why it was asked:** the patch is the base of the whole series (at the
  time, ~85 % of its significant lines, 445/527, were still unchanged in the
  tree).

## The rest of the series

Written by Josep Maria Blasco, an ooRexx committer, with Claude (Anthropic) as
coding assistant. Intended for ooRexx under the CPL 1.0: new files have the
standard RexxLA CPL header.

The series also fixed four ooRexx bugs, now in trunk and therefore no longer
patches here: #2093 (r13251), #2094 (r13252), #2095 (r13253) and #2096
(r13254).
