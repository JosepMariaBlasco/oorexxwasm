/*
 * sqlite.cls: ADDRESS SQLITE, a command environment written in Rexx over
 * the sqlite3 command-line program (an example for cmdhandler.cls).
 *
 *    address sqlite
 *    "CONNECT orders.db"
 *    "INSERT INTO orders VALUES (:id, :item, :qty)"    -- host variables
 *    "SELECT item, qty FROM orders WHERE qty > :min"   -- ITEM.i, QTY.i
 *    "DISCONNECT"
 *    ::requires "sqlite.cls"
 *
 * CONNECT file and DISCONNECT are its own commands; anything else is SQL,
 * run by sqlite3.  :name is replaced by the value of the caller's variable
 * name (simple or compound), as an SQL string literal.  The columns of the
 * rows a statement returns become stems of the caller, named by the
 * columns (name.0 rows, name.1, ...; use AS for names that are not Rexx
 * symbols), and the rows also go to WITH OUTPUT as tab-separated lines.
 *
 * RC: 0; 100 when a SELECT finds no rows (ERROR); -1 an SQL error, whose
 * message goes to WITH ERROR, -2 no connection or a host variable with no
 * value (FAILURE).
 *
 * An example, not a database interface: each command runs sqlite3 once.
 */
.CommandHandler~register("SQLITE", .SqliteHandler~new)

::requires "cmdhandler.cls"

::class SqliteHandler subclass CommandHandler

::method init
  expose db
  db = .nil

::method command
  expose db
  use arg command, context
  verb = command~word(1)~upper
  if verb == "CONNECT" then do
    db = command~subword(2)~strip
    return 0
  end
  if verb == "DISCONNECT" then do
    db = .nil
    return 0
  end
  if db == .nil then do
    context~error("SQLITE: not connected")
    return context~raiseFailure(-2)
  end

  sql = self~hostVariables(command, context)
  if sql == .nil then return context~raiseFailure(-2)

  -- sqlite3 in ASCII mode: fields end in "1F"x, rows in "1E"x, header first
  input = .array~of(".bail on", sql";")
  out = .array~new; err = .array~new
  address system "sqlite3 -ascii -header" self~shellQuote(db) -
    with input using (input) output using (out) error using (err)
  if rc \= 0 | err~items > 0 then do
    context~error(err)
    return context~raiseFailure(-1)
  end

  rows = out~makeString("L", "0a"x)~makeArray("1e"x)
  if rows~items == 0 then do
    if verb == "SELECT" then return context~raiseError(100)
    return 0
  end
  columns = rows[1]~makeArray("1f"x)
  do c over columns
    context~setVar(c".0", rows~items - 1)
  end
  do i = 2 to rows~items
    fields = rows[i]~makeArray("1f"x)
    do j = 1 to columns~items
      context~setVar(columns[j] || "." || (i - 1), fields[j])
    end
    if context~isRedirected("Output") then
      context~output(fields~makeString("L", "09"x))
  end
  return 0

-- :name -> the caller's variable as an SQL literal (not inside quotes)
::method hostVariables private
  use arg sql, context
  symbol = xrange("A", "Z")xrange("a", "z")xrange("0", "9")"_.!?"
  result = ""; quote = ""
  i = 1
  do while i <= sql~length
    ch = sql~subchar(i)
    if quote \== "" then do
      if ch == quote then quote = ""
    end
    else if ch == "'" | ch == '"' then quote = ch
    else if ch == ":" then do
      j = sql~verify(symbol, "N", i + 1)
      if j == 0 then j = sql~length + 1
      name = sql~substr(i + 1, j - i - 1)~strip("T", ".")
      if name \== "" then do
        value = context~getVar(name)
        if value == .nil then do
          context~error("SQLITE: host variable" name~upper "has no value")
          return .nil
        end
        result ||= "'"value~changeStr("'", "''")"'"
        i += 1 + name~length
        iterate
      end
    end
    result ||= ch
    i += 1
  end
  return result

::method shellQuote private
  use arg s
  return "'"s~changeStr("'", "'\''")"'"
