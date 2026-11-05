/******************************************************************************/
/*                                                                            */
/* NearMisses.cls - a class or a key that is ours but for its case            */
/* ===============================================================            */
/*                                                                            */
/* This file is part of the Rexx Parser package                               */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20261027    0.7  First version (Rony: ".numberlines, .numberLines or       */
/*                  .NUMBERLINES should all be the same attribute")           */
/*                                                                            */
/******************************************************************************/
/*                                                                            */
/* The rule (JMB and Rony, 27/10/2026): a Rexx fence is ours, and caseless,   */
/* as Rexx is (FencedCode.cls). Everything else between braces -- other       */
/* fences, ::: blocks, headings, spans, links, pictures -- is read by Pandoc, */
/* by the style sheets and by the browser, and keeps their rules: names are   */
/* case-sensitive. Rewriting the names we know would make a rule nobody could */
/* guess (.NUMBERLINES would work, the author's own .MyBox would not).        */
/*                                                                            */
/* What we do instead is say it. NearMisses reads a Markdown document and     */
/* returns a note for every class or key that is not one RexxPub (or Pandoc)  */
/* knows, but is one of them except for its case or its dashes:               */
/*                                                                            */
/*   line 412: '.numberlines' is not a class RexxPub knows; did you mean      */
/*   '.numberLines'? Outside a Rexx fence, names are case-sensitive.          */
/*                                                                            */
/* Every md2* program prints the notes as warnings. A name that is no near    */
/* miss (an author's own class) says nothing. The lists below only feed the   */
/* warning: a name missing from them costs a warning, never a document.       */
/*                                                                            */
/* What is read: the attributes ({...}) after the opening of a fence that is  */
/* not Rexx, and its first word ("```Output"); a ::: line, with braces or     */
/* with its one word; and every {...} in the text (headings, spans, links,    */
/* pictures, code spans), except a raw one ({=html}). Not read: the front     */
/* matter, the inside of fences, the inside of code spans, and Rexx fences,   */
/* also in the cells of a grid table.                                         */
/*                                                                            */
/******************************************************************************/

::Requires "FencedCode.cls"

/******************************************************************************/
/* NearMisses -- the notes for a document, as "line N: text" strings          */
/******************************************************************************/

::Routine NearMisses Public
  Use Strict Arg source

  out = .Array~new
  Do miss Over NearMissList(source)
    out~append("line" miss~line":" miss~text)
  End
  Return out

/******************************************************************************/
/* NearMissList -- the same, as directories with ~line and ~text              */
/* (md2slides adds the slide)                                                 */
/******************************************************************************/

::Routine NearMissList Public
  Use Strict Arg source

  out    = .Array~new
  tab    = "09"x
  marker = ""                                  -- the fence we are in, if any
  first  = 1

  -- The front matter is YAML, not attributes
  If source~items > 0, Strip(source[1]) == "---" Then Do
    Do i = 2 To source~items
      If Strip(source[i]) == "---" | Strip(source[i]) == "..." Then Do
        first = i + 1
        Leave
      End
    End
  End

  Do lineNo = first To source~items
    line = source[lineNo]
    seen = .Set~new                            -- one note per name and line

    -- Inside a fence: code, until its marker
    If marker \== "" Then Do
      If Strip( Strip(line, "T"), "Leading" ) == marker Then marker = ""
      Iterate
    End

    -- The opening of a fence, perhaps after a list marker
    at = Verify(line, " ")
    If at == 0 Then Iterate
    If SubStr(line, at, 3) \== "```", SubStr(line, at, 3) \== "~~~" Then Do
      p = FenceMarkerPrefix( line )
      If p > 0 Then at = p + 1
    End
    If SubStr(line, at, 3) == "```" | SubStr(line, at, 3) == "~~~" Then Do
      char = SubStr(line, at, 1)
      info = Strip( SubStr(line, at), "Leading", char )
      run  = Length( SubStr(line, at) ) - Length(info)
      If \(char == "`" & info~pos("`") > 0) Then Do
        marker = Copies(char, run)
        info   = Strip(info)
        word   = info
        e = Verify( word, " {"tab, "M" )
        If e > 0 Then word = Left( word, e - 1 )
        -- A Rexx fence is ours, and caseless
        If WordPos( Lower(word), "rexx executor" ) > 0 Then Iterate
        If word \== "" Then Call Check out, lineNo, "."word, seen
        b = info~pos("{")
        If b > 0 Then Call Braces out, lineNo, SubStr(info, b), seen
        Iterate
      End
    End

    -- A ::: line: "::: name" or "::: {...}"
    s = Strip(line)
    If s~startsWith(":::") Then Do
      rest = Strip( Strip(s, "Leading", ":") )
      If rest \== "", rest[1] \== "{" Then Do
        Parse Var rest word .
        Call Check out, lineNo, "."word, seen
        Iterate
      End
    End

    -- The text: every {...}, code spans skipped
    Call Prose out, lineNo, line, seen
  End
  Return out

/******************************************************************************/
/* Prose -- the attribute blocks of a line of text                            */
/******************************************************************************/

::Routine Prose Private
  Use Strict Arg out, lineNo, line, seen

  i = 1
  n = Length(line)
  Loop While i <= n
    c = line[i]
    If c == "`" Then Do
      run = Verify( SubStr(line, i), "`" ) - 1
      If run < 0 Then run = n - i + 1
      close = Copies("`", run)
      j = i + run
      -- The matching run of exactly as many backticks ends the code span
      e = 0
      Loop k = j To n
        If SubStr(line, k, run) == close, SubStr(line, k + run, 1) \== "`", -
           (k == 1 | SubStr(line, k - 1, 1) \== "`") Then Do
          e = k
          Leave
        End
      End
      If e > 0 Then Do
        i = e + run
        Iterate
      End
      -- No end on this line: a fence in the cell of a grid table. A Rexx
      -- one is ours, and the rest of the line is its attributes.
      If run >= 3 Then Do
        Parse Value SubStr(line, j) With word .
        Parse Var word word "{"
        If WordPos( Lower(word), "rexx executor" ) > 0 Then Return
      End
      i = j
      Iterate
    End
    If c == "{" Then Do
      e = BraceEnd(line, i)
      If e == 0 Then Return
      Call Braces out, lineNo, SubStr(line, i, e - i + 1), seen
      i = e + 1
      Iterate
    End
    i += 1
  End

/******************************************************************************/
/* BraceEnd -- where the {...} that starts at i ends (quotes respected), or 0 */
/******************************************************************************/

::Routine BraceEnd Private
  Use Strict Arg line, i

  q = ""
  Do k = i + 1 To Length(line)
    c = line[k]
    Select
      When q \== "" Then If c == q Then q = ""
      When c == '"' | c == "'" Then q = c
      When c == "{" Then Return 0              -- not attributes
      When c == "}" Then Return k
      Otherwise Nop
    End
  End
  Return 0

/******************************************************************************/
/* Braces -- the names in one {...}: its classes and its keys                 */
/******************************************************************************/

::Routine Braces Private
  Use Strict Arg out, lineNo, block, seen

  e = BraceEnd(block, 1)
  If e == 0 Then Return
  body = Strip( SubStr(block, 2, e - 2) )
  If body == "" Then Return
  If body[1] == "=" Then Return                -- {=html}: raw, no names
  Loop While body \== ""
    body = Strip(body, "Leading")
    If body == "" Then Leave
    p = Verify(body, " =""'", "M")
    If p > 0, body[p] == "=" Then Do           -- key=value
      key  = Left(body, p - 1)
      body = SubStr(body, p + 1)
      If body \== "", (body[1] == '"' | body[1] == "'") Then Do
        q = body[1]
        Parse Var body (q) . (q) body
      End
      Else Parse Var body . body
      If key \== "" Then Call Check out, lineNo, key"=", seen
      Iterate
    End
    Parse Var body token body
    If token~left(1) == "." Then Call Check out, lineNo, token, seen
  End

/******************************************************************************/
/* Check -- one name (".class" or "key="): a note if it is a near miss        */
/******************************************************************************/

::Routine Check Private
  Use Strict Arg out, lineNo, name, seen

  If name == "." | name == "=" Then Return
  If seen~hasItem(name) Then Return
  seen~put(name)
  If name~left(1) == "." Then Do
    kind  = "class"
    word  = SubStr(name, 2)
    known = KnownClasses()
  End
  Else Do
    kind  = "attribute"
    word  = Left(name, Length(name) - 1)
    known = KnownKeys()
  End
  If WordPos(word, known) > 0 Then Return
  -- col-N, the columns of md2slides
  If kind == "class", Lower(word)~startsWith("col-"), -
     DataType(SubStr(word, 5), "W"), word \== Lower(word) Then
    meant = Lower(word)
  Else Do
    meant = ""
    norm  = Lower(word)~changeStr("-", "")
    Do w Over known~makeArray(" ")
      If Lower(w)~changeStr("-", "") == norm Then Do
        meant = w
        Leave
      End
    End
  End
  If meant == "" Then Return
  If kind == "class" Then shown = "'."meant"'"
  Else                    shown = "'"meant"='"
  miss = .Directory~new
  miss~line = lineNo
  miss~text = "'"name"' is not" Article(kind) kind "RexxPub knows; did you" -
    "mean" shown"? Outside a Rexx fence, names are case-sensitive."
  out~append(miss)

::Routine Article Private
  Use Strict Arg kind
  If Pos(kind~left(1), "aeiou") > 0 Then Return "an"
  Return "a"

/******************************************************************************/
/* KnownClasses, KnownKeys -- the names, as they are spelt                    */
/*                                                                            */
/* Pandoc's own, the pages' and the book's (MARKUP.md), and md2slides' (its   */
/* reference). A name spelt two ways (.numberLines, .number-lines) has the    */
/* one to suggest first. Add a name here when a pipeline learns one.          */
/******************************************************************************/

::Routine KnownClasses Public
  -- Pandoc's; the pages' and the books'; md2slides'
  Return -
    "numberLines number-lines unnumbered unlisted smallcaps underline mark" -
    "incremental nonincremental"                                            -
    "part chapter toc-exclude back newpage book-title book-subtitle"        -
    "title-page author title-line title-verso listing figure table output"  -
    "out blanks dfn kw rexx ref ref-num ref-chapter ref-text ref-page"      -
    "ref-dir ref-note main definition hint class-hierarchy grid stripes"    -
    "nogrid nostripes"                                                      -
    "slide section title-slide fragment afterClick afterPrevious afterPrev" -
    "withPrevious withPrev startPause pause later static contents plain"    -
    "tight row ruled card box label keys key callout arrow arrow-left"      -
    "arrow-right drawing layers use tree under break file business-card"    -
    "title subtitle background notes refs cover-art presenter affiliation"  -
    "date reference kicker header-left header-center header-right"          -
    "footer-left footer-center footer-right"

::Routine KnownKeys Public
  -- Pandoc's; the pages' and the books'; md2slides'
  Return -
    "startFrom numberWidth width height id lang dir"                     -
    "source spot caption program style size pad patch patchfile"         -
    "extraletters classprefix background border border-width"            -
    "border-color scale cols rules stripes ix note blanks"               -
    "anim anim-duration appear arrow at bend color countdown duration"   -
    "each fill flow from group head indent key kicker label layout level" -
    "line logo numbered offset over pause pen pin ratio reference route"  -
    "section shape show steps time title to wait wait-after wait-before" -
    "word gradient presenter affiliation date"
