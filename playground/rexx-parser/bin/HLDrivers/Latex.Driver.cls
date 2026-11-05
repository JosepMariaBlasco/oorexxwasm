/******************************************************************************/
/*                                                                            */
/* LaTeX.Highlighter.Driver.cls - LaTeX highlighter driver                    */
/* =======================================================                    */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
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
/* 20250101    0.1e First version                                             */
/* 20250105    0.1f Support style patches                                     */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250502    0.2b Update --prolog not to emit HTML classes                  */
/* 20250622    0.2d Change fg/bg char separator to ":"                        */
/* 20261011    0.7  Rewritten, with what md2latex learned: no listings, a     */
/*                  breakable box with the background of the style, one       */
/*                  macro per token, every TeX special character escaped,     */
/*                  blanks one character wide, line numbers, wide listings    */
/*                  set smaller, and a prolog that defines it all. Works      */
/*                  with LuaLaTeX, XeLaTeX and pdfLaTeX.                      */
/* 20261011         Class methods for md2latex (prolog, box, token) and       */
/*                  inline code (\rxhI): md2latex now uses this driver's     */
/*                  macros, for its listings and its mentions                 */
/* 20261026         \rxhT and \rxhI are \protected: a mention in a            */
/*                  footnote, a heading or a caption stopped LuaLaTeX (Rony)  */
/* 20261029         A ground with an alpha (#0000001f) is laid on the box's   */
/*                  ground (Blended): it was taken as opaque, black           */
/* 20261031         A dotted underline (flag D, \rxh@dotu): the directive     */
/*                  keywords, as the style sheets draw them (Rony)            */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- The LaTeX.Highlighter driver class                                         --
--                                                                            --
-- The output is a rxhlisting environment, one \rxhL{...} per line (or        --
-- \rxhLN{digits}{number}{...} with line numbers), and one                    --
-- \rxhT{flags/fg/bg}{text} per highlighted token, where flags are B, I       --
-- and U (bold, italic, underline) and fg and bg are RRGGBB colours, or       --
-- nothing. A token describes its own look, so that the output needs no       --
-- definitions of its own: listings highlighted separately, with different   --
-- styles and patches, can go in the same document. Everything comes from    --
-- the Highlighter's CSS (CachedCSS, that is, GetHighlight): the LaTeX       --
-- looks like the HTML.                                                       --
--                                                                            --
-- The macros are defined by the prolog (highlight --latex --prolog), which   --
-- goes, once, in the preamble of the document. See                           --
-- doc/highlighter/latex/readme.md.                                           --
--------------------------------------------------------------------------------

If \.environment~hasIndex( LaTeX.Highlighter ) Then
  .environment~LaTeX.Highlighter = .LaTeX.Highlighter

::Class LaTeX.Highlighter SubClass Highlighter.Driver Public

::Method Init
  Expose Options. output boxFg boxBg column maxColumn beginAt
  Use Strict Arg Options., output
  self~init:super(Options., output)

  -- The colours of the box: those of the "rexx" class of the style
  Parse Value self~CachedCSS(Options.style, "rexx") With . . . fg":"bg
  boxFg     = Hex6(fg, "000000")
  boxBg     = Hex6(bg, "FFFFFF")

  column    = 0                         -- Characters in the current line
  maxColumn = 0                         -- ...and in the longest one
  beginAt   = 0                         -- Where \begin{rxhlisting} goes

--------------------------------------------------------------------------------
-- Prolog: the definitions (only when requested), and the first line          --
--------------------------------------------------------------------------------

::Method Prolog
  Expose Options. output beginAt

  If Options.prolog Then Do line Over .Resources[LaTeX.Prolog]
    self~say( line )
  End

  -- \begin{rxhlisting} needs the length of the longest line, that we will
  -- know only at the end: its line is reserved here, and written by Epilog.
  beginAt = output~last
  self~say( "" )

  self~openLine( Options.startFrom )

--------------------------------------------------------------------------------
-- A new line                                                                 --
--------------------------------------------------------------------------------

::Method startLine
  Use Strict Arg lineNo
  self~closeLine
  self~openLine( lineNo )

::Method openLine
  Expose Options. column
  Use Strict Arg lineNo
  column = 0
  If Options.numberLines Then
    self~emit( "\rxhLN{"self~digits"}{"lineNo"}{" )
  Else
    self~emit( "\rxhL{" )

::Method closeLine
  Expose column maxColumn
  maxColumn = Max( maxColumn, column )
  self~say( "}" )

-- The digits of the line numbers (the base class adds one for the blank)
::Method digits
  Expose Options.
  Return Options.!numberWidth - 1

--------------------------------------------------------------------------------
-- A token                                                                    --
--------------------------------------------------------------------------------

::Method Highlight
  Expose Options. boxFg boxBg column

  Use Strict Arg category, subCategory, variant, tags, string

  If string == "" Then Return

  patch = Options.!Patch
  If patch == .Nil Then extra = ""
  Else Do
    patch. = patch~getPatch
    Tag2Attr. = patch.!Tag2Attr
    Select
      When variant     \== "" Then extra = Tag2Attr.category.subCategory.variant
      When subCategory \== "" Then extra = Tag2Attr.category.subCategory
      Otherwise                    extra = Tag2Attr.category
    End
  End

  Parse Value self~tags2highlight(tags, extra) -
    With bold italic underline fg":"bg

  text = TokenLaTeX(bold, italic, underline, fg, bg, boxFg, boxBg, string, -
    "\rxhs{}")
  column += CharLength( string~changeStr("09"x, "        ") )
  self~emit( text )

--------------------------------------------------------------------------------
-- Epilog: the last line, and the environment around it all                   --
--------------------------------------------------------------------------------

::Method Epilog
  Expose Options. output boxFg boxBg maxColumn beginAt

  self~closeLine
  self~emit( "\end{rxhlisting}" )

  -- The width, in characters, of the longest line, numbers included: if it
  -- does not fit, the listing is set smaller
  width = maxColumn
  If Options.numberLines Then width += self~digits + 3

  output[beginAt] ||= "\begin{rxhlisting}["width"]{"boxFg"}{"boxBg"}"

--------------------------------------------------------------------------------
-- Class methods, for programs that write LaTeX from the Highlighter's HTML   --
-- (md2latex): the same macros, the same looks.                               --
--------------------------------------------------------------------------------

-- The prolog, as a string
::Method prologText Class
  Return .Resources[LaTeX.Prolog]~makeString("L", "0a"x)

-- The colours of the box of a style: "FG BG" (RRGGBB RRGGBB)
::Method box Class
  Use Strict Arg style
  Parse Value CachedLook(style, "rexx") With . . . fg":"bg
  Return Hex6(fg, "000000") Hex6(bg, "FFFFFF")

-- A token, from its text and its HTML classes ("rx-kw rx-..."), in a style.
-- where is "block" (a listing) or "inline" (a mention: unbreakable blanks).
::Method token Class
  Use Strict Arg style, classes, text, where = "block"
  If where == "inline" Then blank = "\rxhsp{}"
  Else                      blank = "\rxhs{}"
  If classes == "" Then Return TeXText(text, blank)
  Parse Value self~box(style) With boxFg boxBg
  Parse Value CachedLook(style, classes) With b i u fg":"bg
  Return TokenLaTeX(b == "B", i == "I", Pos(u, "UD"), fg, bg, boxFg, boxBg, -
    text, blank)

--------------------------------------------------------------------------------
-- Routines                                                                   --
--------------------------------------------------------------------------------

-- A token as LaTeX: \rxhT{flags/fg/bg}{text}, or the bare text if it has
-- nothing that the box has not
::Routine TokenLaTeX
  Use Strict Arg bold, italic, underline, fg, bg, boxFg, boxBg, string, blank

  -- What the box already does need not be said again. A ground with an
  -- alpha (#0000001f: a light grey on any ground) is laid on the box's
  bg = Blended(bg, boxBg)
  fg = Hex6(fg, "")
  bg = Hex6(bg, "")
  If fg == boxFg Then fg = ""
  If bg == boxBg Then bg = ""

  flags = ""
  If bold      Then flags ||= "B"
  If italic    Then flags ||= "I"
  Select Case underline                  -- 1: a line, 2: dotted
    When 1 Then flags ||= "U"
    When 2 Then flags ||= "D"
    Otherwise Nop
  End

  text = TeXText( string, blank )
  If flags || fg || bg == "" Then Return text
  Return "\rxhT{"flags"/"fg"/"bg"}{"text"}"

-- GetHighlight, through the cache that the drivers share (Drivers.cls)
::Routine CachedLook
  Use Strict Arg style, classes
  look = .CSS.Cache[style, classes]
  If look \== "" Then Return look
  look = GetHighlight(style, classes)
  .CSS.Cache[style, classes] = look
  Return look

-- rrggbbaa laid on the ground RRGGBB: rrggbb, as a browser paints it (an
-- alpha of ff or 00, or no alpha, is left as it is: Hex6 knows what to do)
::Routine Blended
  Use Strict Arg color, ground
  If Length(color) \== 8 | Length(ground) \== 6 Then Return color
  a = X2D( Right(color, 2) )
  If a == 0 | a == 255 Then Return color
  out = ""
  Do k = 1 To 5 By 2
    c = X2D( SubStr(color, k, 2) )
    g = X2D( SubStr(ground, k, 2) )
    out ||= D2X( Format( (c * a + g * (255 - a)) / 255, , 0 ), 2 )
  End
  Return out

-- rrggbb or rrggbbaa -> RRGGBB (the alpha is not used; 00 means no colour)
::Routine Hex6
  Use Strict Arg color, default
  If color == "" Then Return default
  If Length(color) == 8, Right(color, 2) == "00" Then Return default
  Return Upper( Left(color, 6) )

-- The length of a UTF-8 string, in characters
::Routine CharLength
  Use Strict Arg s
  Return Length(s) - -
    CountStr("80"x, s~translate(Copies("80"x, 64), XRange("80"x, "BF"x)))

-- Text for TeX: the special characters escaped, the quotes straight, and
-- each blank a macro, one character wide (\rxhs, after which the line may
-- break, or \rxhsp, after which it may not)
::Routine TeXText
  Use Strict Arg s, blank
  out = .MutableBuffer~new
  Do i = 1 To Length(s)
    c = s[i]
    Select Case c
      When "\"   Then out~append( "\textbackslash{}"    )
      When "{"   Then out~append( "\{"                  )
      When "}"   Then out~append( "\}"                  )
      When "$"   Then out~append( "\$"                  )
      When "&"   Then out~append( "\&"                  )
      When "#"   Then out~append( "\#"                  )
      When "%"   Then out~append( "\%"                  )
      When "_"   Then out~append( "\_"                  )
      When "^"   Then out~append( "\textasciicircum{}"  )
      When "~"   Then out~append( "\textasciitilde{}"   )
      When "'"   Then out~append( "\textquotesingle{}"  )
      When "`"   Then out~append( "\textasciigrave{}"   )
      When "-"   Then out~append( "-{}"                 ) -- No -- ligature
      When "<"   Then out~append( "<{}"                 ) -- No << ligature
      When ">"   Then out~append( ">{}"                 ) -- No >> ligature
      When "09"x Then out~append( Copies(blank, 8)       )
      When " "   Then out~append( blank                  )
      Otherwise       out~append( c                     )
    End
  End
  Return out~string

--------------------------------------------------------------------------------
-- The prolog: what has to be in the preamble of the document, once          --
--------------------------------------------------------------------------------

::Resource LaTeX.Prolog
% ---------------------------------------------------------------------------
% Rexx Parser, LaTeX highlighter (highlight --latex --prolog). Put this in
% the preamble, once. For LuaLaTeX, XeLaTeX or pdfLaTeX.
%
% A listing is a box with the background of its style, that can break across
% pages. Each line is \rxhL{...} (\rxhLN{digits}{number}{...} if numbered),
% each token \rxhT{flags/fg/bg}{text}: flags B, I, U and D (bold, italic,
% underline, dotted underline), fg and bg RRGGBB or empty. Blanks are \rxhs, one character
% wide; a line too long for the box goes on, indented, on the next. A listing
% too wide for the box is set smaller (down to 60%) so that it fits. Code
% inline is \rxhI{fg}{bg}{tokens}, with unbreakable blanks, \rxhsp.
%
% To change: the font size (\renewcommand\rxhfont{\footnotesize}), the box
% (\tcbset{rxh/.style={arc=2pt}}), the colour of the line numbers
% (\definecolor{rxhgutter}{HTML}{808080}). The code font is \ttfamily, and
% it should have bold and italic, as Latin Modern Mono has not: with LuaLaTeX
% or XeLaTeX, \setmonofont{DejaVu Sans Mono}[Scale=MatchLowercase]; with
% pdfLaTeX, \usepackage[T1]{fontenc} and \usepackage[scaled=0.9]{DejaVuSansMono}.
% ---------------------------------------------------------------------------
\makeatletter
\ifdefined\rxhT\else
\RequirePackage{xcolor}
\RequirePackage[most]{tcolorbox}
\providecommand\rxhfont{\small}
\tcbset{rxh/.style={}}
\definecolor{rxhgutter}{HTML}{B0B0A8}
\newlength\rxhcw
\newcommand\rxhs{\hspace{\rxhcw}\allowbreak}
\newcommand\rxhsp{\hspace*{\rxhcw}}
\newcommand\rxh@code{\ttfamily\settowidth{\rxhcw}{x}%
  \spaceskip=\rxhcw\relax\xspaceskip=\rxhcw\relax}
\protected\def\rxhT#1#2{\rxh@T#1//\@nil{#2}}
\def\rxh@T#1/#2/#3/#4\@nil#5{\begingroup
  \in@{U}{#1}\ifin@\let\rxh@u\underline\else\let\rxh@u\@firstofone\fi
  \in@{D}{#1}\ifin@\let\rxh@u\rxh@dotu\fi
  \in@{I}{#1}\ifin@\let\rxh@i\textit\else\let\rxh@i\@firstofone\fi
  \in@{B}{#1}\ifin@\let\rxh@b\textbf\else\let\rxh@b\@firstofone\fi
  \ifx\relax#2\relax\let\rxh@c\@firstofone\else\def\rxh@c{\textcolor[HTML]{#2}}\fi
  \ifx\relax#3\relax\let\rxh@g\@firstofone\else\def\rxh@g{\rxh@bg{#3}}\fi
  \rxh@g{\rxh@c{\rxh@b{\rxh@i{\rxh@u{#5}}}}}%
  \endgroup}
% A dotted underline, thin and in the token's colour half drawn (the
% directive keywords: Rony, 31/10/2026): dots .04em square, every .12em,
% .16em under the baseline. It takes no room.
\newcommand\rxh@dotu[1]{\leavevmode\setbox\z@\hbox{#1}%
  \colorlet{rxh@dot}[rgb]{.}% (in rgb: a mix of an HTML colour fails)
  \rlap{\hbox to\wd\z@{\color{rxh@dot!50}\xleaders\hbox to .12em{\hss
    \vrule width .04em height -.16em depth .2em\hss}\hfil}}\box\z@}
\newcommand\rxh@bg[2]{{\setlength{\fboxsep}{0pt}\colorbox[HTML]{#1}{\strut #2}}}
\newcommand\rxhL[1]{\hangindent=3\rxhcw\hangafter=1\strut#1\par}
\newcommand\rxhLN[3]{\hangindent=\dimexpr#1\rxhcw+3\rxhcw+9pt\relax
  \hangafter=1\strut\makebox[#1\rxhcw][r]{\textcolor{rxhgutter}{#2}}%
  \hspace{4pt}{\color{rxhgutter}\vrule}\hspace{4pt}#3\par}
\newcommand\rxh@fit[1]{%
  \ifnum#1>0
    \ifdim\dimexpr#1\rxhcw\relax>\linewidth
      \edef\rxh@size{\fpeval{trunc(\f@size*max(\linewidth/(#1*\rxhcw)*0.995,
        0.6),2)}}%
      \fontsize{\rxh@size}{\fpeval{1.2*\rxh@size}}\selectfont\rxh@code
    \fi
  \fi}
\newenvironment{rxhlisting}[3][0]
  {\definecolor{rxh@fg}{HTML}{#2}\definecolor{rxh@bg}{HTML}{#3}%
   \begin{tcolorbox}[breakable, enhanced jigsaw, boxrule=0pt, arc=0pt,
     left=4pt, right=4pt, top=3pt, bottom=3pt, before skip=0.6em,
     after skip=0.8em, colback=rxh@bg, coltext=rxh@fg,
     fontupper=\rxhfont\rxh@code\rxh@fit{#1}, rxh]%
   \setlength{\parindent}{0pt}\setlength{\parskip}{0pt}\raggedright
   \hyphenpenalty=10000\exhyphenpenalty=10000\relax}
  {\end{tcolorbox}}
\protected\def\rxhI#1#2#3{{\setlength{\fboxsep}{1pt}\colorbox[HTML]{#2}%
  {\strut\rxh@code\color[HTML]{#1}#3}}}
\fi
\makeatother
::END

::Requires "parser/StyleSheet.cls"
