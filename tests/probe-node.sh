#!/usr/bin/env bash
# Probes for behaviour NOT covered by wasm/tests/qualify-node.sh.
# Usage: probe-node.sh /path/to/build-wasm/bin
BIN=${1:?usage: probe-node.sh /path/to/bin}
cd "$BIN"
R() { echo "== $1"; shift; timeout 30 node ./rexx.js -e "$@" 2>&1 | grep -v '^\s*[0-9]* \*-\*\|\*-\* Compiled' | awk 'length<300' | head -4; }

R queue     'push "a"; queue "b"; say queued()'
R start     'say .o~new~start("f")~result; ::class o; ::method f; return "thread ok"'
R reply     'say .t~new~go; say "after"; ::class t; ::method go; reply "early"; say "post-reply"'
R alarm     'a=.alarm~new(0.2, .message~new(.stdout,"lineout","I","alarm fired")); call syssleep 0.6; say done'
R address   '"ls"; say "rc="rc'
R files     'f="/tmp/x.txt"; call lineout f,"hola"; call lineout f; say linein(f)'
R rxfuncadd 'say rxfuncadd("Foo","nolib","Foo")'
R syntax    'signal on syntax; x=1+"a"; syntax: say "trapped" condition("o")~code'

echo "== recursion limit (binary search)"
lo=100; hi=20000
while [ $((hi-lo)) -gt 25 ]; do
  m=$(((lo+hi)/2))
  if timeout 120 node ./rexx.js -e "say f($m); exit; f: procedure; arg n; if n=0 then return 0; return 1+f(n-1)" 2>/dev/null | grep -qx "$m"
  then lo=$m; else hi=$m; fi
done
echo "   max depth ~ $lo"

echo "== thread stress: 10 concurrent START, 10 runs"
P='do i=1 to 10; m.i=.obj~new~start("hi",i); end; s=0; do i=1 to 10; s=s+m.i~result; end; say "sum="s; ::class obj; ::method hi; use arg k; return k'
ok=0; for i in $(seq 10); do timeout 20 node ./rexx.js -e "$P" 2>/dev/null | grep -qx sum=55 && ok=$((ok+1)); done
echo "   $ok/10 ok"
