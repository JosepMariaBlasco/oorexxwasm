/******************************************************************************/
/*                                                                            */
/* GridTables.cls - Pandoc's grid tables, read as cells and drawn again       */
/* ====================================================================       */
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
/* 20261026    0.7  First version (Rony: a "Rosetta Stone", ooRexx and VBA    */
/*                  side by side, with fenced code in the cells of a table)   */
/*                                                                            */
/******************************************************************************/
/*                                                                            */
/* A grid table is a drawing: every "|" of a row has to be under a "+" of the */
/* line above, or Pandoc does not see a table. A cell can hold blocks (a      */
/* fenced code block, a list...), and whoever rewrites what a cell holds      */
/* before Pandoc reads it (FencedCode, with a highlighted listing; md2latex,  */
/* with that listing in LaTeX) changes the length of its lines, and the       */
/* table is gone. Here the table is read as what it is, a set of cells, each  */
/* a rectangle of the drawing; the caller gives a cell new lines; and the     */
/* table is drawn again, as wide and as tall as those lines ask for.          */
/*                                                                            */
/*   table = .GridTable~at(lines, n)  -- the table whose top border is line   */
/*                                    -- n, or .Nil                           */
/*   Do cell Over table~cells                                                 */
/*     new = ... cell~bare ...        -- what it holds, as Pandoc reads it    */
/*     cell~setBare(new)              -- its new lines, read the same way     */
/*   End                                                                      */
/*   newLines = table~lines           -- the table, drawn again               */
/*                                                                            */
/* The cells are found as docutils finds them: from the top left corner of    */
/* each, along its top edge to a "+" from which a right edge goes down, down  */
/* that edge to a "+" from which a bottom edge goes back to a left edge. So   */
/* a cell can span columns, rows or both, as in Pandoc.                       */
/*                                                                            */
/* Drawn again, every column is the same number of times wider than it was    */
/* (a whole number, the smallest that makes room for every cell): the         */
/* proportions of the dashes, which are the widths of the columns where a     */
/* pipeline takes them (md2slides, md2latex when the author made them         */
/* unequal), stay the author's. A row is as much taller as its cells need.    */
/* The edges keep their dashes or their "=" (the line under the header) and   */
/* their colons (the alignment). A table no cell of which was given new       */
/* lines is returned as it was, byte for byte.                                */
/*                                                                            */
/* Lengths are counted in characters (UTF-8), as Pandoc counts them.          */
/*                                                                            */
/******************************************************************************/

::Class GridTable Public

::Attribute first  Get                  -- The table's first line in `lines`
::Attribute last   Get                  -- ... and its last one
::Attribute indent Get                  -- Blanks before its left border
::Attribute cells  Get                  -- Its cells, an Array of GridCell

--------------------------------------------------------------------------------
-- at -- the grid table whose top border is lines[n], or .Nil                 --
--------------------------------------------------------------------------------
-- A top border is "+", then runs of "-" (or "=", or ":") each closed by a    --
-- "+". The table goes on while the lines start, after the same blanks, with  --
-- "+" or "|", and ends at the last of them that starts with "+". Every line  --
-- must close on its right border, and every corner must start a cell, or it  --
-- is not a table for Pandoc either, and .Nil says so.                        --

::Method at Class
  Use Strict Arg lines, n

  top    = lines[n]
  indent = Length(top) - Length( Strip(top, "Leading") )
  border = Strip( SubStr(top, indent + 1), "Trailing" )
  If \IsBorder(border) Then Return .Nil
  If border~pos("=") > 0 Then Return .Nil    -- That is under a header

  last = self~runEnd(lines, n)
  -- ... back to the last line that is a border
  Loop While last > n, SubStr(lines[last], indent + 1, 1) \== "+"
    last -= 1
  End
  If last == n Then Return .Nil

  -- The drawing, one character per place
  grid  = .Array~new
  width = CharCount(border)
  Loop k = n To last
    row = Utf8Chars( Strip( SubStr(lines[k], indent + 1), "Trailing" ) )
    If row~items \== width Then Return .Nil
    If Pos( row[width], "+|" ) == 0 Then Return .Nil
    grid~append(row)
  End

  cells = FindCells(grid)
  If cells == .Nil Then Return .Nil

  Return self~new(lines, n, last, indent, grid, cells)

--------------------------------------------------------------------------------
-- runEnd -- the last line of the run that starts at lines[n]: the lines      --
-- that start, after the blanks of the first, with "+" or "|". When `at`      --
-- finds no table there, none of them starts one either (the line under a     --
-- header looks like a top border): the caller leaves the whole run alone.    --
--------------------------------------------------------------------------------

::Method runEnd Class
  Use Strict Arg lines, n
  top    = lines[n]
  indent = Length(top) - Length( Strip(top, "Leading") )
  last   = n
  Loop k = n + 1 To lines~items
    line = lines[k]
    If Left(line, indent) \== Copies(" ", indent) Then Leave
    If Pos( SubStr(line, indent + 1, 1), "+|" ) == 0 Then Leave
    last = k
  End
  Return last

-- Whether lines[n] looks like a top border, a table or not
::Method isBorder Class
  Use Strict Arg lines, n
  Return IsBorder( Strip(lines[n]) )

--------------------------------------------------------------------------------

::Method init
  Expose first last indent grid cells original
  Use Strict Arg lines, first, last, indent, grid, cells
  original = lines~section(first, last - first + 1)

--------------------------------------------------------------------------------
-- lines -- the table drawn again, with the new contents of its cells         --
--------------------------------------------------------------------------------

::Method lines
  Expose indent grid cells original

  changed = 0
  Do cell Over cells
    If cell~content \== .Nil Then changed = 1
  End
  If \changed Then Return original~copy

  height = grid~items
  width  = grid[1]~items

  -- The places where an edge is: the columns and rows of the corners
  xs = .Set~new; ys = .Set~new
  Do cell Over cells
    xs~put(cell~left); xs~put(cell~right)
    ys~put(cell~top);  ys~put(cell~bottom)
  End
  xs = xs~allIndexes~sortWith(.NumericComparator~new)
  ys = ys~allIndexes~sortWith(.NumericComparator~new)
  xAt. = 0; Do j = 1 To xs~items; xAt.[xs[j]] = j; End
  yAt. = 0; Do i = 1 To ys~items; yAt.[ys[i]] = i; End

  -- The same number of times wider, every column: the smallest whole number
  -- that leaves room for every cell (a blank after its longest line)
  factor = 1
  Do cell Over cells
    j1 = xAt.[cell~left]; j2 = xAt.[cell~right]
    dashes = cell~right - cell~left - 1 - (j2 - j1 - 1)
    need = 0
    Do line Over cell~text
      need = Max(need, CharCount(line) + 1)
    End
    need -= j2 - j1 - 1                     -- The borders it spans are room
    If dashes > 0 Then factor = Max(factor, (need + dashes - 1) % dashes)
  End
  newX. = 0
  newX.1 = 1
  Do j = 2 To xs~items
    newX.j = newX.[j - 1] + (xs[j] - xs[j - 1] - 1) * factor + 1
  End

  -- Each row as much taller as its cells need, the cells that span fewer
  -- rows first; a cell that spans rows takes what it lacks in its last one
  rowH. = 0
  Do i = 2 To ys~items
    rowH.i = ys[i] - ys[i - 1] - 1
  End
  bySpan = .Array~new
  Do cell Over cells
    bySpan~append( Right(yAt.[cell~bottom] - yAt.[cell~top], 6, "0")":"bySpan~items + 1 )
  End
  order = bySpan~sort
  Do key Over order
    Parse Var key . ":" c
    cell = cells[c]
    i1 = yAt.[cell~top]; i2 = yAt.[cell~bottom]
    room = i2 - i1 - 1
    Do i = i1 + 1 To i2; room += rowH.i; End
    lack = cell~text~items - room
    If lack > 0 Then rowH.i2 += lack
  End
  newY. = 0
  newY.1 = 1
  Do i = 2 To ys~items
    newY.i = newY.[i - 1] + rowH.i + 1
  End

  newWidth  = newX.[xs~items]
  newHeight = newY.[ys~items]
  canvas = .Array~new
  Do r = 1 To newHeight
    row = .Array~new(newWidth)
    row~fill(" ")
    canvas[r] = row
  End

  -- The edges, then the corners over them
  Do cell Over cells
    j1 = xAt.[cell~left]; j2 = xAt.[cell~right]
    i1 = yAt.[cell~top];  i2 = yAt.[cell~bottom]
    Do edge Over .Array~of(cell~top, cell~bottom)
      i = yAt.[edge]
      Do j = j1 To j2 - 1
        old = ""
        Do x = xs[j] + 1 To xs[j + 1] - 1; old ||= grid[edge][x]; End
        Call Segment canvas[newY.i], newX.j, newX.[j + 1], old
        If j > j1 Then Do                 -- A border it spans: still the edge
          If canvas[newY.i][newX.j] == " " Then
            canvas[newY.i][newX.j] = Fill(old)
        End
      End
    End
    Do side Over .Array~of(j1, j2)
      Do r = newY.i1 + 1 To newY.i2 - 1
        canvas[r][newX.side] = "|"
      End
    End
  End
  Do cell Over cells
    j1 = xAt.[cell~left]; j2 = xAt.[cell~right]
    i1 = yAt.[cell~top];  i2 = yAt.[cell~bottom]
    canvas[newY.i1][newX.j1] = "+"; canvas[newY.i1][newX.j2] = "+"
    canvas[newY.i2][newX.j1] = "+"; canvas[newY.i2][newX.j2] = "+"
  End

  -- What the cells hold, from just after their left border
  Do cell Over cells
    j1 = xAt.[cell~left]
    i1 = yAt.[cell~top]
    r  = newY.i1
    Do line Over cell~text
      r += 1
      chars = Utf8Chars(line)
      Do x = 1 To chars~items
        canvas[r][newX.j1 + x] = chars[x]
      End
    End
  End

  pad = Copies(" ", indent)
  res = .Array~new
  Do r = 1 To newHeight
    res~append( pad || Strip( canvas[r]~makeString("C"), "Trailing" ) )
  End
  Return res

-- One stretch of a horizontal edge, from corner to corner: its dashes (or
-- its "="), and a colon where the old one had it, next to a corner
Segment: Procedure
  Use Strict Arg row, here, there, old
  fill = Fill(old)
  Do x = here + 1 To there - 1; row[x] = fill; End
  If old~left(1)  == ":" Then row[here + 1]  = ":"
  If old~right(1) == ":" Then row[there - 1] = ":"
  Return

Fill: Procedure
  Use Strict Arg old
  If old~pos("=") > 0 Then Return "="
  Return "-"

--------------------------------------------------------------------------------
-- A top border: "+", then runs of "-", "=" or ":", each closed by a "+"      --
--------------------------------------------------------------------------------

::Routine IsBorder Private
  Use Strict Arg s
  If Length(s) < 3 Then Return 0
  If s[1] \== "+" Then Return 0
  If s~right(1) \== "+" Then Return 0
  If s~verify("+-=:") > 0 Then Return 0
  If s~pos("++") > 0 Then Return 0
  If s~pos("-") == 0, s~pos("=") == 0 Then Return 0
  Return 1

--------------------------------------------------------------------------------
-- FindCells -- the cells of a drawing, or .Nil if it is not a grid table     --
--------------------------------------------------------------------------------
-- From each top left corner still to be looked at: right along the top edge  --
-- to a "+" with a right edge under it, down it to a "+" with a bottom edge   --
-- that goes back to a "+" with a left edge up to the corner. The top right   --
-- and bottom left corners of a cell are top left corners of the next ones.   --
-- A corner that starts no cell is passed by, as docutils does; a place       --
-- inside the table that no cell holds and that is not an edge, or one that   --
-- two cells hold, is no table.                                               --

::Routine FindCells Private
  Use Strict Arg grid

  height = grid~items
  width  = grid[1]~items
  cells  = .Array~new
  done   = .Set~new
  todo   = .Array~of("1 1")
  -- Every place a cell holds, to see that every place is held once
  held   = .Set~new

  Loop While todo~items > 0
    corner = todo[1]
    todo~delete(1)
    If done~hasIndex(corner) Then Iterate
    done~put(corner)
    Parse Var corner top left
    If top == height | left == width Then Iterate
    -- A corner no cell starts at (a cell that spans columns has one on its
    -- top edge): nothing to do there. That every place is in a cell or on
    -- an edge is seen at the end.
    found = ScanCell(grid, top, left)
    If found == .Nil Then Iterate
    Parse Var found bottom right
    cell = .GridCell~new(grid, top, left, bottom, right)
    cells~append(cell)
    Do y = top To bottom
      Do x = left To right
        If y > top, y < bottom, x > left, x < right Then Do
          If held~hasIndex(y x) Then Return .Nil
          held~put(y x)
        End
      End
    End
    todo~append(top right)
    todo~append(bottom left)
  End

  -- Every place inside the table belongs to a cell or to an edge
  Do y = 2 To height - 1
    Do x = 2 To width - 1
      If held~hasIndex(y x) Then Iterate
      If Pos( grid[y][x], "+-=:|" ) == 0 Then Return .Nil
    End
  End
  Return cells

-- The bottom right corner of the cell whose top left one is (top, left)
::Routine ScanCell Private
  Use Strict Arg grid, top, left
  height = grid~items
  width  = grid[1]~items
  Do right = left + 1 To width
    c = grid[top][right]
    If c == "+" Then Do
      -- A right edge down from here?
      Do bottom = top + 1 To height
        d = grid[bottom][right]
        If d == "+" Then Do
          If BottomEdge(grid, bottom, left, right), LeftEdge(grid, top, bottom, left) Then
            Return bottom right
        End
        Else If d \== "|" Then Leave
      End
    End
    Else If Pos(c, "-=:") == 0 Then Return .Nil
  End
  Return .Nil

::Routine BottomEdge Private
  Use Strict Arg grid, y, left, right
  If grid[y][left] \== "+" Then Return 0
  Do x = left + 1 To right - 1
    If Pos( grid[y][x], "+-=:" ) == 0 Then Return 0
  End
  Return 1

::Routine LeftEdge Private
  Use Strict Arg grid, top, bottom, left
  Do y = top + 1 To bottom - 1
    If Pos( grid[y][left], "+|" ) == 0 Then Return 0
  End
  Return 1

--------------------------------------------------------------------------------
-- GridCell -- one cell: where it is in the drawing, and what it holds        --
--------------------------------------------------------------------------------

::Class GridCell Public

::Attribute top    Get
::Attribute left   Get
::Attribute bottom Get
::Attribute right  Get
::Attribute lines  Get                  -- What it holds: an Array of lines,
                                        -- without the blanks at their end
::Attribute content                     -- Its new lines, or .Nil

::Method init
  Expose top left bottom right lines content
  Use Strict Arg grid, top, left, bottom, right
  content = .Nil
  lines = .Array~new
  Do y = top + 1 To bottom - 1
    line = ""
    Do x = left + 1 To right - 1; line ||= grid[y][x]; End
    lines~append( Strip(line, "Trailing") )
  End

-- What it holds as Pandoc reads it: without the blanks all its lines start
-- with (up to three; more would make an indented code block of it)
::Method bare
  Expose lines
  margin = 4
  Do line Over lines
    If line \== "" Then margin = Min( margin, Verify(line, " ") - 1 )
  End
  If margin > 3 Then margin = 0
  res = .Array~new
  Do line Over lines
    res~append( SubStr(line, margin + 1) )
  End
  Return res

-- New lines for it, written as bare ones are read: drawn after one blank
::Method setBare
  Expose content
  Use Strict Arg new
  content = .Array~new
  Do line Over new
    If line == "" Then content~append( "" )
    Else content~append( " "line )
  End

-- What it will be drawn with: its new lines, if it has them
::Method text
  Expose lines content
  If content \== .Nil Then Return content
  Return lines

--------------------------------------------------------------------------------
-- UTF-8: a string as an Array of its characters, and how many there are      --
--------------------------------------------------------------------------------

::Routine Utf8Chars Public
  Use Strict Arg s
  res = .Array~new
  i = 1
  len = Length(s)
  Loop While i <= len
    b = s[i]~c2d
    Select
      When b < 192 Then n = 1             -- ASCII (or a stray byte)
      When b < 224 Then n = 2
      When b < 240 Then n = 3
      Otherwise         n = 4
    End
    res~append( SubStr(s, i, n) )
    i += n
  End
  Return res

::Routine CharCount Public
  Use Strict Arg s
  -- Every byte that does not continue a character starts one
  n = 0
  Do i = 1 To Length(s)
    b = s[i]~c2d
    If b < 128 | b >= 192 Then n += 1
  End
  Return n
