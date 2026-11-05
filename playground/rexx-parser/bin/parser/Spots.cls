/******************************************************************************/
/*                                                                            */
/* Spots.cls - spot= drawn once and for all, for the outputs that do not move */
/* ===========================================================================*/
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
/* 20261025    0.7  First version (Rony: "highlight text -- fragments, whole  */
/*                  lines; bold or colored -- in output sections")            */
/* 20261103         One colour per beat for the whole page (Rony): a beat     */
/*                  takes its pen by its first place in the page (PagePens),  */
/*                  not in its block                                          */
/*                                                                            */
/******************************************************************************/
/*                                                                            */
/* In md2slides, spot= on a listing names the BEATS it takes part in and what */
/* lights up in each one: spot="init:2 salary:5-7,[Total]". The slide runtime */
/* (js/spotlight.js) lights them one click after another.                     */
/*                                                                            */
/* A page does not click. md2html, md2pdf, md2epub, the CGI and md2latex draw */
/* every beat at once, as a slide looks when all its steps are done: the      */
/* marks of a listing are spans in its HTML, written here, and the style      */
/* sheets (css/tables.css, css/print/rexxpub-base.css) and md2latex draw      */
/* them. The same spelling, so a deck and a book say it the same way:         */
/*                                                                            */
/*   name:items     a beat; items is a comma list of N, N-M (whole lines,     */
/*                  numbered as the listing shows them), [text] (that text,   */
/*                  wherever it is) or N[text] (that text, on line N).        */
/*   wash ink box ring hatch                                                  */
/*                  how a mark looks (wash, the default; hatch is a wash      */
/*                  here). One for the whole spot=, as in md2slides.          */
/*   bold           the text in bold: alone, only that; with a look, both.    */
/*   pen=N|colour   the pen: one of the four of the style (1-4), or a colour. */
/*                  Without it, a beat takes the pen of its place in the      */
/*                  page: the first beat that marks something, in any block,  */
/*                  pen 1, the second 2..., and a beat that comes back in     */
/*                  another block keeps its pen (v380; Rony, 03-Nov: "one     */
/*                  colour per beat for the whole page"). See PagePens.       */
/*   caseless       the texts are found in any case.                          */
/*   part           the texts are found inside words too (v360; Rony, 01-Nov: */
/*                  the %20 of Rony%20G.); without it, whole words only.      */
/*   clear hide indent hull                                                   */
/*                  are about time or slides: left alone here.                */
/*                                                                            */
/* The spans, each with class rx-spot and:                                    */
/*                                                                            */
/*   rx-spot-line   on the span of a whole line (the line's own span gets the */
/*                  classes), or rx-spot-text on a span inside a token;       */
/*   rx-spot-wash, -ink, -box or -ring (none when it is bold only);           */
/*   rx-spot-bold;                                                            */
/*   rx-spot-pen1 .. rx-spot-pen4, or rx-spot-penx with the colour inline:    */
/*                  style="--rx-spot-line: C; --rx-spot-bg: C at 40%";        */
/*   rx-spot-first, rx-spot-last: where a run of lines, or a text that goes   */
/*                  through several tokens, starts and ends (a box draws its  */
/*                  sides there).                                             */
/*                                                                            */
/* The same rules, for code that is not Rexx and for program output, are in   */
/* cgi/spots.lua: Pandoc writes those blocks, and the Lua filters mark them.  */
/*                                                                            */
/******************************************************************************/

/******************************************************************************/
/* SpotSpec(spec) -- spot= read: a Directory with                             */
/*                                                                            */
/*   beats     an Array of Directories: name, lines (a Set of numbers),       */
/*             texts (an Array of Directories: line, "" or a number; text)    */
/*   look      "", wash, ink, box, ring                                       */
/*   bold      0 or 1                                                         */
/*   pen       "", 1-4 or a colour                                            */
/*   caseless  0 or 1                                                         */
/*   part      0 or 1 (v360)                                                  */
/*   warnings  an Array of strings: what could not be read                    */
/******************************************************************************/

::Routine SpotSpec Public
  Use Strict Arg spec

  s = .Directory~new
  s~beats    = .Array~new
  s~look     = ""
  s~bold     = 0
  s~pen      = ""
  s~caseless = 0
  s~part     = 0
  s~warnings = .Array~new

  terms = SplitOutside(Strip(spec), " ;" || "090d0a"x)
  If terms == .Nil Then Do
    s~warnings~append('the square brackets do not pair up in "'spec'"')
    Return s
  End

  Do term Over terms
    If term == "" Then Iterate
    low = Lower(term)
    Select
      When low == "caseless"                          Then s~caseless = 1
      When low == "part"                              Then s~part = 1
      When WordPos(low, "clear hide indent hull") > 0 Then Nop
      When low == "hatch"                             Then s~look = "wash"
      When WordPos(low, "wash ink box ring") > 0      Then s~look = low
      When low == "bold"                              Then s~bold = 1
      When low~startsWith("pen=") Then Do
        pen = Strip(SubStr(term, 5))
        If WordPos(pen, "1 2 3 4") > 0 | SpotColour(pen) Then s~pen = pen
        Else s~warnings~append("pen="pen "is neither one of the four pens" -
          '(1-4) nor a colour (in "'spec'")')
      End
      Otherwise Call BeatTerm
    End
  End
  Return s

BeatTerm:
  i = term~pos(":")
  b = term~pos("[")
  If b > 0, i == 0 | b < i Then i = 0           -- a ":" inside a text
  If i == 0 Then name = term
  Else           name = Left(term, i - 1)
  name = Strip(name)
  If name == "" | name~pos("[") > 0 Then Do
    s~warnings~append('"'term'" names no beat (write name:[text])')
    Return
  End
  beat = .Directory~new
  beat~name  = Lower(name)
  beat~lines = .Set~new
  beat~texts = .Array~new
  If i > 0 Then Do
    items = SplitOutside(SubStr(term, i + 1), ",")
    Do item Over items
      item = Strip(item)
      Select
        When item == "" Then Nop
        When item[1] == "@" Then Nop            -- a region: pictures only
        When item~verify("0123456789") == 0 Then beat~lines~put(item + 0)
        When item~pos("-") > 1, item~changeStr("-", "")~verify("0123456789") == 0, -
             item~countStr("-") == 1 Then Do
          Parse Var item lo "-" hi
          If hi < lo Then Parse Value hi lo With lo hi
          Do n = lo To hi; beat~lines~put(n + 0); End
        End
        When item~right(1) == "]", item~pos("[") > 0 Then Do
          p = item~pos("[")
          at = Left(item, p - 1)
          text = SubStr(item, p + 1, Length(item) - p - 1)
          If text == "" | at~verify("0123456789") \== 0 Then
            s~warnings~append('cannot read "'item'" as a line, a range or a' -
              '[text] (in "'spec'")')
          Else Do
            t = .Directory~new
            If at == "" Then t~line = ""
            Else             t~line = at + 0
            t~text = text
            beat~texts~append(t)
          End
        End
        Otherwise s~warnings~append('cannot read "'item'" as a line, a range' -
          'or a [text] (in "'spec'")')
      End
    End
  End
  s~beats~append(beat)
  Return

/******************************************************************************/
/* SpotColour(value) -- is it a colour a page and md2latex understand? A hex  */
/* colour (#RGB, #RRGGBB) or one of the names of CSS (SpotHex).               */
/******************************************************************************/

::Routine SpotColour Public
  Use Strict Arg value
  Return SpotHex(value) \== ""

/******************************************************************************/
/* SpotHex(value) -- a colour as RRGGBB, or "" if it is not one we know:      */
/* #RGB, #RRGGBB, or one of the 148 names of CSS (md2latex needs numbers).    */
/******************************************************************************/

::Routine SpotHex Public
  Use Strict Arg value
  v = Strip(value)
  If v[1] == "#" Then Do
    h = SubStr(v, 2)
    If h~verify("0123456789abcdefABCDEF") \== 0 Then Return ""
    Select Case Length(h)
      When 3 Then Return Upper(h[1]h[1]h[2]h[2]h[3]h[3])
      When 6 Then Return Upper(h)
      Otherwise Return ""
    End
  End
  -- The 148 colour names of CSS (the same as JDOR's: svg2jdor.cls)
  names = "aliceblue:F0F8FF antiquewhite:FAEBD7 aqua:00FFFF aquamarine:7FFFD4" -
    "azure:F0FFFF beige:F5F5DC bisque:FFE4C4 black:000000" -
    "blanchedalmond:FFEBCD blue:0000FF blueviolet:8A2BE2 brown:A52A2A" -
    "burlywood:DEB887 cadetblue:5F9EA0 chartreuse:7FFF00" -
    "chocolate:D2691E coral:FF7F50 cornflowerblue:6495ED" -
    "cornsilk:FFF8DC crimson:DC143C cyan:00FFFF darkblue:00008B" -
    "darkcyan:008B8B darkgoldenrod:B8860B darkgray:A9A9A9" -
    "darkgreen:006400 darkgrey:A9A9A9 darkkhaki:BDB76B" -
    "darkmagenta:8B008B darkolivegreen:556B2F darkorange:FF8C00" -
    "darkorchid:9932CC darkred:8B0000 darksalmon:E9967A" -
    "darkseagreen:8FBC8F darkslateblue:483D8B darkslategray:2F4F4F" -
    "darkslategrey:2F4F4F darkturquoise:00CED1 darkviolet:9400D3" -
    "deeppink:FF1493 deepskyblue:00BFFF dimgray:696969 dimgrey:696969" -
    "dodgerblue:1E90FF firebrick:B22222 floralwhite:FFFAF0" -
    "forestgreen:228B22 fuchsia:FF00FF gainsboro:DCDCDC" -
    "ghostwhite:F8F8FF gold:FFD700 goldenrod:DAA520 gray:808080" -
    "green:008000 greenyellow:ADFF2F grey:808080 honeydew:F0FFF0" -
    "hotpink:FF69B4 indianred:CD5C5C indigo:4B0082 ivory:FFFFF0" -
    "khaki:F0E68C lavender:E6E6FA lavenderblush:FFF0F5 lawngreen:7CFC00" -
    "lemonchiffon:FFFACD lightblue:ADD8E6 lightcoral:F08080" -
    "lightcyan:E0FFFF lightgoldenrodyellow:FAFAD2 lightgray:D3D3D3" -
    "lightgreen:90EE90 lightgrey:D3D3D3 lightpink:FFB6C1" -
    "lightsalmon:FFA07A lightseagreen:20B2AA lightskyblue:87CEFA" -
    "lightslategray:778899 lightslategrey:778899 lightsteelblue:B0C4DE" -
    "lightyellow:FFFFE0 lime:00FF00 limegreen:32CD32 linen:FAF0E6" -
    "magenta:FF00FF maroon:800000 mediumaquamarine:66CDAA" -
    "mediumblue:0000CD mediumorchid:BA55D3 mediumpurple:9370DB" -
    "mediumseagreen:3CB371 mediumslateblue:7B68EE" -
    "mediumspringgreen:00FA9A mediumturquoise:48D1CC" -
    "mediumvioletred:C71585 midnightblue:191970 mintcream:F5FFFA" -
    "mistyrose:FFE4E1 moccasin:FFE4B5 navajowhite:FFDEAD navy:000080" -
    "oldlace:FDF5E6 olive:808000 olivedrab:6B8E23 orange:FFA500" -
    "orangered:FF4500 orchid:DA70D6 palegoldenrod:EEE8AA" -
    "palegreen:98FB98 paleturquoise:AFEEEE palevioletred:DB7093" -
    "papayawhip:FFEFD5 peachpuff:FFDAB9 peru:CD853F pink:FFC0CB" -
    "plum:DDA0DD powderblue:B0E0E6 purple:800080 rebeccapurple:663399" -
    "red:FF0000 rosybrown:BC8F8F royalblue:4169E1 saddlebrown:8B4513" -
    "salmon:FA8072 sandybrown:F4A460 seagreen:2E8B57 seashell:FFF5EE" -
    "sienna:A0522D silver:C0C0C0 skyblue:87CEEB slateblue:6A5ACD" -
    "slategray:708090 slategrey:708090 snow:FFFAFA springgreen:00FF7F" -
    "steelblue:4682B4 tan:D2B48C teal:008080 thistle:D8BFD8" -
    "tomato:FF6347 turquoise:40E0D0 violet:EE82EE wheat:F5DEB3" -
    "white:FFFFFF whitesmoke:F5F5F5 yellow:FFFF00 yellowgreen:9ACD32"
  Do pair Over names~makeArray(" ")
    Parse Var pair name ":" hex
    If Lower(v) == name Then Return hex
  End
  Return ""

/******************************************************************************/
/* SpotClasses(sp, k, where) -- the classes (and the style attribute, if any, */
/* after a "|") of a mark of beat k: where is "line" or "text".               */
/******************************************************************************/

::Routine SpotClasses Public
  Use Strict Arg sp, k, where
  classes = "rx-spot rx-spot-"where
  If sp~look \== "" Then classes ||= " rx-spot-"sp~look
  Else If \sp~bold  Then classes ||= " rx-spot-wash"
  If sp~bold Then classes ||= " rx-spot-bold"
  pen = sp~pen
  If pen == "" Then pen = PagePen(sp, k)
  If WordPos(pen, "1 2 3 4") > 0 Then Return classes "rx-spot-pen"pen"|"
  hex = SpotHex(pen)
  Parse Value X2D(Left(hex, 2)) X2D(SubStr(hex, 3, 2)) X2D(Right(hex, 2)) With r g b
  rgb = r", "g", " || b
  style = "--rx-spot-line: #"hex"; --rx-spot-bg: rgba("rgb", .4)"
  Return classes "rx-spot-penx|"style

/******************************************************************************/
/* PagePen(sp, k) -- the pen of beat k when spot= names none: the one its     */
/* name has in the page (sp~pagePens, from PagePens), or else the one of its  */
/* place in the block.                                                        */
/******************************************************************************/

::Routine PagePen Private
  Use Strict Arg sp, k
  If sp~hasEntry("PAGEPENS") Then Do
    pen = sp~pagePens[sp~beats[k]~name]
    If pen \== .Nil Then Return pen
  End
  Return (k - 1) // 4 + 1

/******************************************************************************/
/* PagePens(specs) -- the pens of the beats of a page: specs is an Array of   */
/* the spot= of its blocks, in the order of the page. The first beat that     */
/* marks something takes pen 1, the next new one pen 2, and so on, round the  */
/* four; a beat that comes back keeps its pen. Returned as "name:pen ..."     */
/* (a beat's name has no blank and no ":"), for StaticSpots and, through the  */
/* environment (REXXPUB_BEAT_PENS), for cgi/spots.lua.                        */
/******************************************************************************/

::Routine PagePens Public
  Use Strict Arg specs
  seen = .Set~new
  res  = ""
  Do spec Over specs
    Do beat Over SpotSpec(spec)~beats
      If beat~lines~items + beat~texts~items == 0 Then Iterate
      If seen~hasIndex(beat~name) Then Iterate
      seen~put(beat~name)
      res ||= " "beat~name":" || (seen~items - 1) // 4 + 1
    End
  End
  Return Strip(res)

/******************************************************************************/
/* StaticSpots(html, spec, pens) -- the HTML of a Rexx listing (an Array of   */
/* lines, as FencedCode has it), with the marks of spot= written in. pens is  */
/* what PagePens gives for the page ("" when the page is this block alone).   */
/*                                                                            */
/* The listing's <code> holds one <span id="rxK-N"> per line, N the number    */
/* the line shows (startFrom= counts). A whole line gets the classes on that  */
/* span; a text, a span of its own inside each token it goes through, so that */
/* the tokens keep their colours and their spans stay whole.                  */
/******************************************************************************/

::Routine StaticSpots Public
  Use Strict Arg html, spec, pens = ""

  sp = SpotSpec(spec)
  If pens \== "" Then Do
    sp~pagePens = .Directory~new
    Do pair Over pens~makeArray(" ")
      Parse Var pair name ":" pen
      sp~pagePens[name] = pen
    End
  End
  Do w Over sp~warnings
   .Error~Say("Warning: spot=:" w)
  End
  marks = 0
  Do beat Over sp~beats
    If beat~lines~items + beat~texts~items > 0 Then marks = 1
  End
  If \marks Then Return html

  s = html~makeString("L", "0a"x)
  p = s~pos("<code")
  If p == 0 Then Return html
  q = s~pos(">", p)
  e = s~lastPos("</code>")
  If q == 0 | e < q Then Return html
  code = SubStr(s, q + 1, e - q - 1)

  -- The lines: what comes before each (the "0a"x between them), its tag,
  -- what it holds, its number
  lines = .Array~new
  rest  = code
  count = 0
  Loop
    o = rest~pos("<span")
    If o == 0 Then Leave
    line = .Directory~new
    line~before = Left(rest, o - 1)
    t = rest~pos(">", o)
    line~tag = SubStr(rest, o, t - o + 1)
    c = SpanEnd(rest, t + 1)                  -- the position of its </span>
    line~inner = SubStr(rest, t + 1, c - t - 1)
    rest = SubStr(rest, c + Length("</span>"))
    count += 1
    n = count
    If line~tag~pos('id="') > 0 Then Do
      Parse Value line~tag With 'id="' id '"'
      last = id~lastPos("-")
      If last > 0, SubStr(id, last + 1)~dataType("W") Then n = SubStr(id, last + 1)
    End
    line~number = n + 0
    line~beat = 0
    Do k = 1 To sp~beats~items
      If sp~beats[k]~lines~hasIndex(line~number) Then line~beat = k
    End
    lines~append(line)
  End

  out = .MutableBuffer~new
  out~append(Left(s, q))
  Do i = 1 To lines~items
    line = lines[i]
    out~append(line~before)
    tag = line~tag
    k = line~beat
    If k > 0 Then Do
      Parse Value SpotClasses(sp, k, "line") With classes "|" style
      If i == 1 Then first = 1
      Else           first = lines[i - 1]~beat \== k
      If i == lines~items Then last = 1
      Else                     last = lines[i + 1]~beat \== k
      If first Then classes ||= " rx-spot-first"
      If last  Then classes ||= " rx-spot-last"
      tag = WithClasses(tag, classes, style)
    End
    out~append(tag, MarkTexts(line~inner, line~number, sp), "</span>")
  End
  out~append(rest, SubStr(s, e))
  res = out~string~makeArray("0a"x)
  -- makeArray drops a last empty line, and FencedCode counts on it
  If html~items > 0, html[html~last] == "", res[res~last] \== "" Then res~append("")
  Return res

/******************************************************************************/
/* MarkTexts -- the inside of a line, with its texts marked                   */
/******************************************************************************/

::Routine MarkTexts Private
  Use Strict Arg inner, number, sp

  plain = PlainText(inner)
  If plain == "" Then Return inner
  owner = .Array~new(Length(plain))
  any = 0
  If sp~caseless Then hay = AsciiLower(plain)
  Else                hay = plain
  Do k = 1 To sp~beats~items
    Do t Over sp~beats[k]~texts
      If t~line \== "", t~line \== number Then Iterate
      needle = t~text
      If sp~caseless Then needle = AsciiLower(needle)
      at = 1
      Loop
        f = hay~pos(needle, at)
        If f == 0 Then Leave
        z = f + Length(needle) - 1
        -- Whole words, as spotlight.js: a text that starts (ends) with a
        -- letter, a digit or "_" does not start (end) inside a word
        -- (v360: unless the spot= says part)
        cut = 0
        If \sp~part Then Do
          If f > 1, IsWordChar(needle~left(1)), IsWordChar(hay[f - 1]) Then cut = 1
          If z < Length(hay), IsWordChar(needle~right(1)), IsWordChar(hay[z + 1]) Then cut = 1
        End
        If cut Then Do
          at = f + 1
          Iterate
        End
        Do b = f To z; owner[b] = k; End
        any = 1
        at = z + 1
      End
    End
  End
  If \any Then Return inner

  out = .MutableBuffer~new
  o   = 1                                     -- where we are in plain
  rest = inner
  Do While rest \== ""
    If rest[1] == "<" Then Do
      t = rest~pos(">")
      If t == 0 Then Do; out~append(rest); Leave; End
      out~append(Left(rest, t))
      rest = SubStr(rest, t + 1)
      Iterate
    End
    t = rest~pos("<")
    If t == 0 Then t = Length(rest) + 1
    text = Decoded(Left(rest, t - 1))
    rest = SubStr(rest, t)
    -- The text, cut where the owner changes
    j = 1
    Do While j <= Length(text)
      k = Owner(owner, o + j - 1)
      m = j
      Do While m < Length(text), Owner(owner, o + m) == k
        m += 1
      End
      piece = Escaped(SubStr(text, j, m - j + 1))
      If k == 0 Then out~append(piece)
      Else Do
        Parse Value SpotClasses(sp, k, "text") With classes "|" style
        If Owner(owner, o + j - 2) \== k Then classes ||= " rx-spot-first"
        If Owner(owner, o + m)     \== k Then classes ||= " rx-spot-last"
        tag = '<span class="'classes'"'
        If style \== "" Then tag ||= ' style="'style'"'
        out~append(tag">", piece, "</span>")
      End
      j = m + 1
    End
    o += Length(text)
  End
  Return out~string

::Routine Owner Private
  Use Strict Arg owner, b
  If b < 1 | b > owner~size Then Return 0
  k = owner[b]
  If k == .Nil Then Return 0
  Return k

/******************************************************************************/
/* Small helpers                                                              */
/******************************************************************************/

-- Split s at every character of seps that is outside square brackets, or
-- .Nil when the brackets do not pair up ([a[1]] is the text a[1]).
::Routine SplitOutside Public
  Use Strict Arg s, seps
  out = .Array~new
  cur = ""
  depth = 0
  Do i = 1 To Length(s)
    c = s[i]
    If c == "[" Then depth += 1
    Else If c == "]" Then Do
      If depth == 0 Then Return .Nil
      depth -= 1
    End
    If depth == 0, seps~pos(c) > 0 Then Do
      out~append(cur)
      cur = ""
    End
    Else cur ||= c
  End
  If depth > 0 Then Return .Nil
  out~append(cur)
  Return out

-- The position of the </span> that closes the span whose content starts at p
::Routine SpanEnd Private
  Use Strict Arg s, p
  depth = 1
  i = p
  Loop
    o = s~pos("<span", i)
    c = s~pos("</span>", i)
    If c == 0 Then Return Length(s) + 1
    If o > 0, o < c Then Do
      depth += 1
      i = o + 5
    End
    Else Do
      depth -= 1
      If depth == 0 Then Return c
      i = c + 7
    End
  End

-- A tag with more classes (and a style, if any)
::Routine WithClasses Private
  Use Strict Arg tag, classes, style
  If tag~pos('class="') > 0 Then
    tag = tag~changeStr('class="', 'class="'classes' ', 1)
  Else
    tag = Left(tag, Length(tag) - 1) 'class="'classes'">'
  If style \== "" Then
    tag = Left(tag, Length(tag) - 1) 'style="'style'">'
  Return tag

-- The text of some HTML: the tags out, the entities decoded
::Routine PlainText Private
  Use Strict Arg html
  out = .MutableBuffer~new
  Do While html \== ""
    p = html~pos("<")
    If p == 0 Then Do; out~append(Decoded(html)); Leave; End
    out~append(Decoded(Left(html, p - 1)))
    t = html~pos(">", p)
    If t == 0 Then Leave
    html = SubStr(html, t + 1)
  End
  Return out~string

::Routine Decoded Private
  Use Strict Arg s
  If s~pos("&") == 0 Then Return s
  out = ""
  Do While s~pos("&") > 0
    Parse Var s before "&" entity ";" rest
    out ||= before
    Select
      When entity == "lt"   Then out ||= "<"
      When entity == "gt"   Then out ||= ">"
      When entity == "amp"  Then out ||= "&"
      When entity == "quot" Then out ||= '"'
      When entity == "apos" Then out ||= "'"
      When entity == "nbsp" Then out ||= "C2A0"x
      When entity~left(2)~upper == "#X" Then out ||= Utf8Of(SubStr(entity, 3)~x2d)
      When entity~left(1) == "#", DataType(SubStr(entity, 2), "W") Then
        out ||= Utf8Of(SubStr(entity, 2))
      Otherwise out ||= "&"entity";"
    End
    s = rest
  End
  Return out || s

::Routine Utf8Of Private
  Use Strict Arg n
  Select
    When n < 128   Then Return D2C(n)
    When n < 2048  Then Return D2C(192 + n % 64) || D2C(128 + n // 64)
    When n < 65536 Then Return D2C(224 + n % 4096) || D2C(128 + n % 64 // 64) || D2C(128 + n // 64)
    Otherwise Return D2C(240 + n % 262144) || D2C(128 + n % 4096 // 64) ||    -
                     D2C(128 + n % 64 // 64) || D2C(128 + n // 64)
  End

::Routine Escaped Private
  Use Strict Arg s
  Return s~changeStr("&", "&amp;")~changeStr("<", "&lt;")~changeStr(">", "&gt;")

-- A character of a word, for the texts of spot=: a letter, a digit, "_"; a
-- byte of a character that is not ASCII counts as a letter
::Routine IsWordChar Private
  Use Strict Arg c
  If c >= "80"x Then Return 1
  Return Verify(c, XRange("a", "z") || XRange("A", "Z") || "0123456789_") == 0

-- Lower case for A-Z only: a text in another script is found as written
::Routine AsciiLower Private
  Use Strict Arg s
  Return Translate(s, XRange("a", "z"), XRange("A", "Z"))
