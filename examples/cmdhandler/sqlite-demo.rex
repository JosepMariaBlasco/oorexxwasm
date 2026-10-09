-- ADDRESS SQLITE: an ADDRESS environment written in Rexx (cmdhandler.cls)
address sqlite
"CONNECT orders.db"
"DROP TABLE IF EXISTS orders"
"CREATE TABLE orders (id INTEGER, item TEXT, qty INTEGER)"
items = .array~of("book", "pen", "O'Brien's map")
do id = 1 to 3
  item = items[id]; qty = id * 2
  "INSERT INTO orders VALUES (:id, :item, :qty)"
end

min = 2
"SELECT item, qty FROM orders WHERE qty > :min ORDER BY id"
do i = 1 to item.0
  say item.i qty.i
end

address sqlite "SELECT count(*) AS n FROM orders" with output stem lines.
say "rows:" n.1 "/ WITH OUTPUT:" lines.1

signal on error
"SELECT item FROM orders WHERE qty > 100"
say "not reached"
error:
say "ERROR, RC" rc

signal on failure
address sqlite "SELECT * FROM nosuchtable" with error stem e.
say "not reached"
failure:
say "FAILURE, RC" rc":" e.1
"DISCONNECT"

::requires "sqlite.cls"
