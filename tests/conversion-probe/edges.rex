/* Conversion edges of the JavaScript bridge (.JSObject), oorexxwasm.
   Run with the Node command-line build:  rexx edges.rex
   (the same js.cls and js-bridge.js run in the browser builds).
   Each line: what was sent or evaluated, then what arrived.            */

js = .js
F = js~Function
-- k(x): what JavaScript received, as type:value
k = F~new("x", -
  "const d = (x) => {" -
  "  if (x === null) return 'null'; if (x === undefined) return 'undefined';" -
  "  const t = typeof x;" -
  "  if (t === 'string') return 'string:' + JSON.stringify(x);" -
  "  if (t === 'number') return 'number:' + (Object.is(x, -0) ? '-0' : String(x));" -
  "  if (t === 'boolean' || t === 'bigint') return t + ':' + String(x);" -
  "  if (Array.isArray(x)) return 'Array(' + x.length + ')[' + Array.from({length: x.length}, (_, i) => i in x ? d(x[i]) : '<hole>').join(', ') + ']';" -
  "  if (typeof RexxProxy !== 'undefined' && x instanceof RexxProxy) return 'RexxProxy:' + String(x);" -
  "  if (x instanceof Uint8Array) return 'Uint8Array[' + Array.from(x) + ']';" -
  "  if (t === 'object') return (x.constructor ? x.constructor.name : 'null-proto') + '{' + Object.keys(x).map((n) => JSON.stringify(n) + ': ' + d(x[n])).join(', ') + '}';" -
  "  return t; };" -
  "return d(x);")

say "--- Rexx -> JavaScript"
list = '0|-0|42|-7|007|+5| 5|5 |3.14|.5|5.|1E3|1e3|1E+3|1E-3|-1.5E2|1.0|12345678901234567890123456789|3.14159265358979323846264|1E999|1E-999|.|-|E3|1E|0x10|1_000|inf|NaN|abc||1 2'
do while list \= ""
  parse var list v "|" list
  say left("'"v"'", 40) k~call(.nil, v)
end
say left("12345678901234567890 * 10 (DIGITS 9)", 40) k~call(.nil, 12345678901234567890 * 10)
say left("5 (an integer object inside Rexx)", 40) k~call(.nil, 5)
say left(".true / .false", 40) k~call(.nil, .true) k~call(.nil, .false)
say left(".js~true / .js~false / .js~bool(0)", 40) k~call(.nil, js~true) k~call(.nil, js~false) k~call(.nil, js~bool(0))
say left(".Boolean~true / .Boolean~false", 40) k~call(.nil, .Boolean~true) k~call(.nil, .Boolean~false)
say left(".js~true == .Boolean~true (same object)", 40) (js~true == .Boolean~true) (js~true~identityHash == .Boolean~true~identityHash)
say left(".js~num: '007' '3.14' '1E3' '-0'", 40) k~call(.nil, js~num("007")) k~call(.nil, js~num("3.14")) k~call(.nil, js~num("1E3")) k~call(.nil, js~num("-0"))
say left(".js~num('abc')", 40) tryNum("abc")
say left(".js~bigint(12345678901234567890123)", 40) k~call(.nil, js~bigint(12345678901234567890123))
say left(".js~box('Int', 7) / ('BO', 1) / ('STring', 7)", 40) k~call(.nil, js~box("Int", 7)) k~call(.nil, js~box("BO", 1)) k~call(.nil, js~box("STring", 7))
say left(".nil / .js~undefined", 40) k~call(.nil, .nil) k~call(.nil, js~undefined)
say left("Array (1, 'a', (2, 3))", 40) k~call(.nil, .array~of(1, "a", .array~of(2, 3)))
a = .array~new(4); a[1] = 1; a[3] = "x"
say left("sparse Array [1,,x,] (size" a~size")", 40) k~call(.nil, a)
m = .array~new(2,2); m[1,1] = 1; m[2,2] = 4
say left("2-D Array 2x2", 40) k~call(.nil, m)
m = .array~new(2, 3); m[1, 2] = "b"; m[2, 1] = "d"
say left("2-D Array 2x3, m[1,2]=b m[2,1]=d", 40) k~call(.nil, m)
-- copies keep cycles and sharing: what is the same object in JavaScript
same = F~new("x", "p", "return p.split(' ').map((e) => e + ': ' + Function('x', 'return ' + e)(x)).join(', ')")
a = .array~of(1, 2); a~append(a)
say left("a = (1, 2); a~append(a)", 40) same~call(.nil, a, "x.length x[2]===x")
b = .array~of(1); c = .array~of(2, b); b~append(c)
say left("b = (1, c), c = (2, b)", 40) same~call(.nil, b, "x[1][1]===x x[1]===x")
x = .array~of(9)
say left(".array~of(x, x)", 40) same~call(.nil, .array~of(x, x), "x[0]===x[1]")
d = .directory~new; da = .array~of(d); d["a"] = da
say left("Array -> Directory -> the Array", 40) same~call(.nil, da, "x[0].a===x")
d = .directory~new; d~method = "POST"; d["cache"] = "no-store"
say left("Directory (d~method=, d['cache']=)", 40) k~call(.nil, d)
st = .stringtable~new; st["Key"] = 1
say left("StringTable ['Key']", 40) k~call(.nil, st)
s.1 = "a"; s.0 = 1
say left("stem s.", 40) k~call(.nil, s.)
say left(".list~of(1,2)", 40) k~call(.nil, .list~of(1,2))
say left(".mutablebuffer~new('12')", 40) k~call(.nil, .mutablebuffer~new("12"))
say left("'é' (UTF-8 bytes)", 40) k~call(.nil, "é")
say left("'ff'x (not UTF-8)", 40) tryCall(k, "ff"x)
say left(".js~bytes('ff'x)", 40) k~call(.nil, js~bytes("ff"x))
t = F~new("x", "return x")
say left("'ff'x round trip", 40) tryCall(t, "ff"x)
say left("'é' round trip (== 'é')", 40) (t~call(.nil, "é") == "é")
say left("JS 'a\uD800' (lone surrogate) to Rexx", 40) tryCall(F~new("return 'a\uD800'"))

say "--- JavaScript -> Rexx"
e = "true|false|null|undefined|0|-0|1e21|1e-7|1e16|1.0|2**53+2|0.1+0.2|1/3|NaN|Infinity|-Infinity|12345678901234567890n|'café'|''|[1,2]|({a:1})|new Map([[1,2]])|new Set([1])|new Uint8Array([97,255])|new Number(5)|Symbol('s')"
do while e \= ""
  parse var e x "|" e
  r = F~new("return (" x ")")~call(.nil)
  say left(x, 40) show(r)
end
r = F~new("return true")~call(.nil)
say left("true: class / is .Boolean~true / r + 1", 40) r~class~id (r~identityHash == .Boolean~true~identityHash) (r + 1)
say left("false through Rexx and back", 40) k~call(.nil, F~new("return false")~call(.nil))
r = F~new("return new Uint8Array([97,255])")~call(.nil)
say left("Uint8Array~js.byteString", 40) "'"c2x(r~js.byteString)"'x"
say left("datatype(1e21 / 1e-7 / NaN, 'N')", 40) datatype(F~new("return 1e21")~call(.nil), "N") datatype(F~new("return 1e-7")~call(.nil), "N") datatype(F~new("return NaN")~call(.nil), "N")

say "--- positions"
arr = F~new("return [10, 20, 30]")~call(.nil)
say left("[10,20,30]: o[1] o[3] o[4] o~length", 40) arr[1] arr[3] show(arr[4]) arr~length
say left("o~items / o~size / o~js.className", 40) tryMsg(arr, "items") tryMsg(arr, "size") arr~js.className
ma = arr~makeArray
say left("~makeArray: class, items, [1]", 40) ma~class~id ma~items ma[1]
o = ""; do with index i item v over arr; o = o i"="v; end
say left("do with index i item v over", 40) strip(o)
say left("o[0]", 40) tryAt(arr, 0)

say "--- names"
obj = F~new("return {foo: 1, Foo: 2, bar: 3}")~call(.nil)
say left("{foo:1, Foo:2, bar:3}: o~bar", 40) obj~bar
say left("o~foo (differ only in case)", 40) tryMsg(obj, "foo")
say left("o~js.getStrict('Foo') / o['foo']", 40) obj~js.getStrict("Foo") obj["foo"]
say left("o~nothere", 40) show(obj~nothere)

say "--- identity"
o1 = F~new("return globalThis.probeObj = globalThis.probeObj || {}")~call(.nil)
o2 = F~new("return globalThis.probeObj")~call(.nil)
say left("same JS object twice: == / =", 40) (o1 == o2) (o1 = o2)
o3 = F~new("return {}")~call(.nil)
say left("two different {}: == / =", 40) (o1 == o3) (o1 = o3)
acct = .Thing~new
same = F~new("a", "b", "return a === b")
say left("Rexx object twice to JS: a === b", 40) same~call(.nil, acct, acct)
say left("Rexx object round trip (== itself)", 40) (t~call(.nil, acct) == acct)

say "--- errors: JavaScript exception in Rexx"
signal on syntax name js1
F~new("throw new TypeError('bad thing')")~call(.nil)
js1:
c = condition("O")
say left("code / errortext", 40) c~code "/" c~errortext
say left("message", 40) c~message
say left("additional items / [2] class", 40) c~additional~items "/" show(c~additional[2])
say left("additional[2]~name / ~message", 40) c~additional[2]~name "/" c~additional[2]~message
say left("additional[3] (the stack), first line", 40) c~additional[3]~makeArray("0a"x)[1]
signal on syntax name js2
F~new("throw 42")~call(.nil)
js2:
c = condition("O")
say left("throw 42: message / additional[2]", 40) c~message "/" show(c~additional[2])
say left("throw 42: additional items", 40) c~additional~items

say "--- errors: Rexx condition in JavaScript"
catch = F~new("o", "m", -
  "try { o[m](); return 'no error'; } catch (e) {" -
  " return [typeof RexxError !== 'undefined' && e instanceof RexxError, e instanceof Error, e.name," -
  "  JSON.stringify(e.message), JSON.stringify(Object.getOwnPropertyNames(e).filter((n) => n !== 'stack'))," -
  "  JSON.stringify([e.condition, e.code, e.rc, e.errorText, typeof e.program, e.line," -
  "  e.traceback && e.traceback.split('\n').length, 'cause' in e])].join(' | '); }")
say left("SYNTAX 41.1 (instanceof RexxError | Error | name | message | own props | [condition, code, rc, errorText, program, line, traceback lines, cause?])", 40)
say "   " catch~call(.nil, acct, "bad")
say left("RAISE SYNTAX 93.900 with a message", 40)
say "   " catch~call(.nil, acct, "raise93")
say left("user condition (RAISE USER oops)", 40)
say "   " catch~call(.nil, acct, "user")

say "--- errors: JavaScript exception through Rexx and back"
back = F~new("o", -
  "try { o.callsjs(); return 'no error'; } catch (e) {" -
  " return [e.constructor.name, e instanceof TypeError, JSON.stringify(e.message)," -
  "  'cause:', e.cause && e.cause.constructor.name, e.cause && e.cause.message].join(' | '); }")
say "   " back~call(.nil, acct)
say "--- float text (topics/float-text.md): JavaScript numbers -> Rexx"
-- each value is made in JavaScript and returned; Rexx shows it, its length, DATATYPE(v, "N")
fl = '1.0|1/3|0.1 + 0.2|1e16|1e17|1.5e17|1e21|1e-7|1e-20|1e-34|1e-35|1.2345678901234567e-10|1.2345678901234567e-20|-0.0|-1.5e-35|2**53 + 1|2n**53n + 1n|Number.MAX_VALUE|Number.MIN_VALUE|NaN|Infinity|-Infinity'
do while fl \= ""
  parse var fl e "|" fl
  v = F~new("return " e)~call(.nil)
  say left(e, 40) "'"v"'" length(v) datatype(v, "N")
end
say "--- float text: Rexx strings -> a JavaScript number (.js~num)"
fl = '1E+16|1e16|1E16|1E+17|0.0000001| 1.5 |-0|nan|+infinity|-infinity|NaN|Infinity|-Infinity|inf|1E+999'
do while fl \= ""
  parse var fl e "|" fl
  say left("'"e"'", 40) tonum(k, e)
end
exit

show: procedure
  use arg r
  if r == .nil then return ".nil"
  if r == .js~undefined then return ".js~undefined"
  if r~isA(.JSObject) then return "JSObject:"r~js.className
  return "'"r"'" "(len" r~length")"

tryCall: procedure                  -- f~call(.nil, args...), or its condition
  use arg f
  args = arg(1, "A")~section(2)
  signal on syntax name bad0
  return show(f~sendWith("CALL", .array~of(.nil)~appendAll(args)))
bad0: return "SYNTAX" condition("O")~code":" condition("O")~additional[1]

tryNum: procedure
  signal on syntax name bad
  return .js~num(arg(1))
bad: return "SYNTAX" condition("O")~code":" condition("O")~message

tryMsg: procedure
  use arg o, m
  signal on syntax name bad2
  return show(o~send(m))
bad2: return "SYNTAX" condition("O")~code":" condition("O")~message

tryAt: procedure
  use arg o, i
  signal on syntax name bad3
  return show(o[i])
bad3: return "SYNTAX" condition("O")~code":" condition("O")~message

tonum: procedure                     -- what JavaScript receives from .js~num(s)
  use arg k, s
  signal on syntax
  return k~call(.nil, .js~num(s))
syntax:
  return "SYNTAX" condition("O")~code condition("O")~additional[1]

::class Thing
::method bad
  return 1 + "a"
::method raise93
  raise syntax 93.900 array("my message")
::method user
  raise user oops
::method callsjs
  .js~Function~new("throw new TypeError('from JS')")~call(.nil)

::requires "js.cls"
