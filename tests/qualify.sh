#!/usr/bin/env bash
# One-command qualification of the ooRexx/WASM builds, with assertions.
# Exit status 0 only if every check passes; a summary lists the failures.
#
# Usage: qualify.sh [BUILD=$ORX_WASM_WORK/build-wasm] [--no-browser] [--quick]
#   BUILD/bin       MEMFS build (Node + browser, WebSocket sockets)
#   BUILD/bin-node  Node command-line build (host files, commands, rxapi
#                   daemon, real TCP/UDP) — oorexx/wasm/build-node.sh
#   --no-browser    skip the headless Chromium section (otherwise it runs when
#                   Python Playwright is importable, and is reported SKIPPED
#                   if it is not)
#   --quick         skip the slow parts (deep-recursion cases, thread stress)
# Needs: node, python3 (+ websockets for the WebSocket echo server).
# Takes ~3 min (--quick ~1 min).  Ports used: 50010 (WebSocket echo),
# 8000 (COOP/COEP HTTP server), 50110-50119 (socket checks).
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -uo pipefail
BUILD=$ORX_WASM_WORK/build-wasm; BROWSER=auto; QUICK=0
for a in "$@"; do
  case $a in
    --no-browser) BROWSER=no ;;
    --quick) QUICK=1 ;;
    -*) echo "unknown option $a" >&2; exit 2 ;;
    *) BUILD=$a ;;
  esac
done
BUILD=$(cd "$BUILD" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
OOREXX=${OOREXX:-$ORX_WASM_WORK/oorexx}
BIN=$BUILD/bin; NB=$BUILD/bin-node
T=$(mktemp -d); trap 'rm -rf "$T"; for p in ${PIDS[@]:-}; do kill $p 2>/dev/null; done' EXIT
PIDS=()
PASSED=0; FAILED=(); SKIPPED=()

# check TITLE REGEX... -- SHELL-SNIPPET
# Runs the snippet (bash, in $T, 90 s timeout); every REGEX must match some
# line of its output (stdout+stderr), and its exit status must be 0.
# A REGEX starting with '!' must match NO line.
check() {
  local title=$1; shift
  local pats=() p miss=() out rc
  while [[ $1 != -- ]]; do pats+=("$1"); shift; done; shift
  out=$(cd "$T" && timeout 90 bash -c "$1" 2>&1); rc=$?
  for p in "${pats[@]}"; do
    if [[ $p == !* ]]; then grep -Eq -- "${p:1}" <<<"$out" && miss+=("no /${p:1}/")
    else grep -Eq -- "$p" <<<"$out" || miss+=("/$p/"); fi
  done
  (( rc == 0 )) || miss+=("exit status $rc")
  if (( ${#miss[@]} )); then
    FAILED+=("$title"); printf 'FAIL  %s\n      expected: %s\n' "$title" "${miss[*]}"
    tail -n 8 <<<"$out" | sed 's/^/      | /'
  else
    PASSED=$((PASSED+1)); printf 'ok    %s\n' "$title"
  fi
}
skip() { SKIPPED+=("$1"); printf 'SKIP  %s (%s)\n' "$1" "$2"; }
section() { printf '\n== %s\n' "$1"; }
export BIN NB T

# Rexx programs used below (files in $T)
cat > "$T/server.rex" <<'EOF'
-- echo server: accepts N connections on 127.0.0.1:port, echoes one message each
parse arg port n
s = .socket~new; s~setOption('SO_REUSEADDR', 1)
if s~bind(.inetaddress~new('127.0.0.1', port)) < 0 then do; say 'bind failed' s~errno; exit 1; end
if s~listen(5) < 0 then do; say 'listen failed' s~errno; exit 1; end
say 'listening'
do n
  cs = s~accept
  if cs == .nil then do; say 'accept failed' s~errno; exit 1; end
  cs~send(cs~recv(65536)); cs~close
end
s~close
::requires 'socket.cls'
EOF
cat > "$T/client.rex" <<'EOF'
parse arg host port msg
c = .socket~new
if c~connect(.inetaddress~new(host, port)) < 0 then do; say 'connect failed' c~errno; exit 1; end
c~send(msg); say 'echo='c~recv(65536); c~close
::requires 'socket.cls'
EOF
cat > "$T/threads.rex" <<'EOF'
-- server thread and client in one process; 256 KiB echo
srv = .socket~new; srv~setOption('SO_REUSEADDR', 1)
srv~bind(.inetaddress~new('127.0.0.1', arg(1))); srv~listen(1)
.echoer~new(srv)
c = .socket~new; c~connect(.inetaddress~new('127.0.0.1', arg(1)))
big = xrange()~copies(1024); c~send(big)
got = .mutablebuffer~new
do while got~length < big~length
  d = c~recv(65536); if d == .nil | d == '' then leave; got~append(d)
end
say 'same=' || (got~string == big) 'len=' || got~length
::class echoer
::method init
  use arg srv; reply
  cs = srv~accept; total = 0
  do while total < 262144; d = cs~recv(65536); if d == .nil | d == '' then leave; cs~send(d); total += d~length; end
  cs~close; srv~close
::requires 'socket.cls'
EOF
cat > "$T/timeout.rex" <<'EOF'
s = .socket~new; s~setOption('SO_REUSEADDR', 1)
say 'set='s~setOption('SO_RCVTIMEO', 300) 'get='s~getOption('SO_RCVTIMEO')
s~bind(.inetaddress~new('127.0.0.1', arg(1))); s~listen(1)
call time 'R'; cs = s~accept
say 'accept='cs 'errno='s~errno 'elapsed='format(time('E'),,1)
r.0 = 1; r.1 = s~string
say 'select='SockSelect('r.', , , 0.2)
::requires 'socket.cls'
EOF
cat > "$T/udp.rex" <<'EOF'
-- UDP: receive one datagram on port, send it back upper-cased (or send+receive)
parse arg mode port
u = .socket~new(, 'SOCK_DGRAM')
if mode = 'serve' then do
  u~bind(.inetaddress~new('127.0.0.1', port)); say 'bound'
  from = .inetaddress~new('0.0.0.0', 0); d = u~recvfrom(100, from)
  a.!family = 'AF_INET'; a.!addr = from~address; a.!port = from~port
  call SockSendTo u~string, d~upper, 'a.!'
end
else do
  a.!family = 'AF_INET'; a.!addr = '127.0.0.1'; a.!port = port
  call SockSendTo u~string, 'hello udp', 'a.!'
  say 'reply='u~recvfrom(100, .inetaddress~new('0.0.0.0', 0))
end
u~close
::requires 'socket.cls'
EOF
cat > "$T/cmds.rex" <<'EOF'
'echo hi'; say 'rc='rc
address system 'exit 3'; say 'rc='rc
address system 'printf "a\nb\n"' with output stem o.; say 'stem='o.0 o.2
EOF
cat > "$T/parent.rex" <<'EOF'
queue 'parent'
address system '"'value('NB',,'ENVIRONMENT')'/rexx" child.rex'
EOF
cat > "$T/child.rex" <<'EOF'
parse pull x; say 'child got=' || x
EOF
cat > "$T/dns.rex" <<'EOF'
say 'localhost='SockGetHostByName('localhost', 'h.') h.addr
say 'invalid='SockGetHostByName('no-such-host.invalid', 'x.')
say 'reverse='SockGetHostByAddr('127.0.0.1', 'r.') r.name
say 'hostname='.socket~gethostname
say 'hostid='.socket~gethostid
::requires 'socket.cls'
EOF

# ---------------------------------------------------------------------------
section "MEMFS build under Node ($BIN)"
if [[ -x $OOREXX/wasm/tests/qualify-node.sh ]]; then
  check "qualify-node.sh (WebSocket RxSock, StreamSocket)" '^QUALIFICATION PASS$' -- \
    "'$OOREXX/wasm/tests/qualify-node.sh' '$BUILD'"
else
  skip "qualify-node.sh" "not found under $OOREXX"
fi
R() { printf '%s' "cd \"\$BIN\" && node ./rexx.js -e $(printf '%q' "$1")"; }
check "data queue"        '^2$'                   -- "$(R 'push "a"; queue "b"; say queued()')"
check "START"             '^thread ok$'           -- "$(R 'say .o~new~start("f")~result; ::class o; ::method f; return "thread ok"')"
check "REPLY"             '^early$' '^post-reply$' '^after$' -- "$(R 'say .t~new~go; call syssleep 0.2; say "after"; ::class t; ::method go; reply "early"; say "post-reply"')"
check ".Alarm"            '^alarm fired$' '^DONE$' -- "$(R 'a=.alarm~new(0.2, .message~new(.stdout,"lineout","I","alarm fired")); call syssleep 0.6; say done')"
check "SysSleep"          '^slept 0\.[5-7]$'      -- "$(R 'call time "R"; call syssleep 0.5; say "slept" format(time("E"),,1)')"
check "SYNTAX trap"       '^trapped 41\.1$'       -- "$(R 'signal on syntax; x=1+"a"; syntax: say "trapped" condition("o")~code')"
check "MEMFS files"       '^hola$'                -- "$(R 'f="/tmp/x.txt"; call lineout f,"hola"; call lineout f; say linein(f)')"
check "rxregexp, rxmath"  '^match=1 sqrt=1\.414'  -- "$(R 'r=.RegularExpression~new("[0-9]+"); call rxfuncadd "MathLoadFuncs","rxmath","MathLoadFuncs"; call MathLoadFuncs; say "match="r~match("123") "sqrt="RxCalcSqrt(2,4); ::requires "rxregexp.cls"')"
check "external commands (host processes under Node)" '^tmp$' '^rc=0$' -- "$(R '"ls /"; say "rc="rc')"
if (( ! QUICK )); then
  check "thread stress: 10 x 10 concurrent START" '^10/10 ok$' -- "'$HERE/stress.sh' '$BIN' 10 10 | tail -1"
  check "deep recursion -> Error 11 (9 cases)" '!RangeError|HANG|exited rc' '!^node +[a-z]+ +$' -- \
    "'$HERE/probe-recursion.sh' '$BIN' node | tee /dev/stderr | grep -cE '(Error 11|trapped|depth [0-9]+|parsed)' | grep -qx 9 && echo all-ok"
fi

# ---------------------------------------------------------------------------
section "Node command-line build ($NB)"
if [[ ! -x $NB/rexx ]]; then
  skip "Node command-line build" "no $NB/rexx (run oorexx/wasm/build-node.sh)"
else
  X="\"\$NB/rexx\""
  check "host files + environment" '^hola$' '^env=xyz$' -- \
    "QTEST_VAR=xyz $X -e 'call lineout \"$T/h.txt\",\"hola\"; call lineout \"$T/h.txt\"; say linein(\"$T/h.txt\"); say \"env=\"value(\"QTEST_VAR\",,\"ENVIRONMENT\")' && test -f '$T/h.txt'"
  check "external commands: output, rc, ADDRESS WITH" '^hi$' '^rc=0$' '^rc=3$' '^stem=2 b$' -- "$X cmds.rex"
  check ".RexxInfo~executable" "^$NB/rexx\$" -- "$X -e 'say .RexxInfo~executable'"
  check "rexxc compile + run" '^compiled ok$' -- \
    "echo 'say \"compiled ok\"' > c.rex && \"\$NB/rexxc\" c.rex c.rxc >/dev/null && $X c.rxc"
  check "rxapi daemon: named queue across processes + rxqueue" '^queued=2 first=X$' -- \
    "$X -e 'call rxqueue \"create\",\"QUALIFYQ\"' >/dev/null; printf 'x\\ny\\n' | \"\$NB/rxqueue\" QUALIFYQ && $X -e 'call rxqueue \"set\",\"QUALIFYQ\"; n=queued(); pull a; say \"queued=\"n \"first=\"a; call rxqueue \"set\",\"SESSION\"; call rxqueue \"delete\",\"QUALIFYQ\"'"
  check "rxapi daemon: session queue parent -> child" '^child got=parent$' -- "$X parent.rex"
  check "sockets: server and client in separate processes" '^echo=ping$' -- \
    "$X server.rex 50110 1 & sleep 1.5; $X client.rex 127.0.0.1 50110 ping; wait"
  check "sockets: localhost, server thread, 256 KiB echo" '^same=1 len=262144$' -- "$X threads.rex 50111"
  check "sockets: SO_RCVTIMEO ends a blocking accept" '^set=0 get=300$' '^accept=The NIL object errno=EWOULDBLOCK elapsed=0\.[3-5]$' '^select=0$' -- \
    "$X timeout.rex 50112"
  check "sockets: interop with a Python TCP client" '^py got b.pong.$' -- \
    "$X server.rex 50113 1 & sleep 1.5; python3 -c \"import socket; c=socket.create_connection(('127.0.0.1',50113)); c.sendall(b'pong'); print('py got', c.recv(100))\"; wait"
  check "sockets: UDP between processes" '^reply=HELLO UDP$' -- \
    "$X udp.rex serve 50114 & sleep 1.5; $X udp.rex send 50114; wait"
  check "name resolution (host resolver)" '^localhost=1 127\.0\.0\.1$' '^invalid=0$' '^reverse=1 ' "^hostname=$(hostname)\$" '^hostid=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' -- \
    "$X dns.rex"
fi

# ---------------------------------------------------------------------------
section "Browser (headless Chromium, $BIN)"
if [[ $BROWSER == no ]]; then
  skip "browser" "--no-browser"
elif ! python3 -c 'import playwright' 2>/dev/null; then
  skip "browser" "Python Playwright not installed"
else
  cp "$HERE/t.html" "$BIN/"
  if ! (exec 3<>/dev/tcp/127.0.0.1/8000) 2>/dev/null; then
    python3 "$OOREXX/wasm/tests/http_isolated.py" "$BIN" >/dev/null 2>&1 & PIDS+=($!)
  fi
  if ! (exec 3<>/dev/tcp/127.0.0.1/50010) 2>/dev/null; then
    OOREXX_WASM_TEST_PORT=50010 python3 "$OOREXX/wasm/tests/ws_echo.py" >/dev/null 2>&1 & PIDS+=($!)
  fi
  sleep 1
  BR() { printf '%s' "timeout 40 python3 '$HERE/browser_run.py' $(printf '%q' "$1")"; }
  check "browser: hello"     'hello from the browser \| 1267650600228229401496703205376' 'exited rc=0' -- "$(BR 'numeric digits 50; say "hello from the browser"; say 2**100')"
  check "browser: START"     'thread ok' 'exited rc=0'          -- "$(BR 'say .o~new~start("f")~result; ::class o; ::method f; return "thread ok"')"
  check "browser: REPLY"     'early \| post-reply \| after' -- "$(BR 'say .t~new~go; call syssleep 0.2; say "after"; ::class t; ::method go; reply "early"; say "post-reply"')"
  check "browser: .Alarm"    'alarm fired \| DONE'           -- "$(BR 'a=.alarm~new(0.2, .message~new(.stdout,"lineout","I","alarm fired")); call syssleep 0.6; say done')"
  check "browser: 10 concurrent START" 'sum=55'             -- "$(BR 'do i=1 to 10; m.i=.obj~new~start("hi",i); end; s=0; do i=1 to 10; s=s+m.i~result; end; say "sum="s; ::class obj; ::method hi; use arg k; return k')"
  check "browser: SysSleep"  'slept 0\.[5-7]'               -- "$(BR 'call time "R"; call syssleep 0.5; say "slept" format(time("E"),,1)')"
  check "browser: recursion -> Error 11" 'Error 11\.1' '!RangeError' -- "$(BR 'say f(1500); exit; f: procedure; arg n; if n=0 then return 0; return 1+f(n-1)')"
  check "browser: RxSock over WebSocket" 'connect= 0 same= 1' -- "$(BR 's=SockSocket("AF_INET","SOCK_STREAM","IPPROTO_TCP"); h.!family="AF_INET"; h.!addr="127.0.0.1"; h.!port="50010"; rc=SockConnect(s,"h.!"); n1=SockSend(s,"ping"); n2=SockRecv(s,"back",100); say "connect=" rc "same=" (back=="ping"); call SockClose s')"
  check "browser: StreamSocket"  'open= READY: in= Hello'  -- "$(BR 's=.StreamSocket~new("localhost",50010); o=s~open; n=s~lineOut("Hello"); b=s~lineIn; say "open=" o "in=" b; ::requires "/streamsocket.cls"')"
fi

# ---------------------------------------------------------------------------
# the browser build of the playground: oorexx/wasm/build-web.sh -> BUILD/bin-web
section "Web build + playground (headless Chromium, $BUILD/bin-web)"
if [[ $BROWSER == no ]]; then
  skip "web build" "--no-browser"
elif [[ ! -f $BUILD/bin-web/ooRexx.js ]]; then
  skip "web build" "no $BUILD/bin-web (run oorexx/wasm/build-web.sh)"
elif ! python3 -c 'import playwright' 2>/dev/null; then
  skip "web build" "Python Playwright not installed"
else
  # the in-tree cases (wasm/tests/web-api.py: also JDOR and .JSObject)
  check "web API: stdin, stop, files, threads, rexxtry, extension classes, JDOR, JavaScript" '^== [0-9]+ passed, 0 failed$' -- \
    "timeout 300 python3 '$OOREXX/wasm/tests/web-api.py' '$BUILD/bin-web'"
  SITE=$(mktemp -d)
  check "playground page: driven like a user (light/dark, desktop/mobile)" '^== 0 failed$' -- \
    "'$HERE/../playground/build-site.sh' '$BUILD/bin-web' '$SITE' >/dev/null && timeout 300 python3 '$HERE/playground_check.py' '$SITE'"
fi

# ---------------------------------------------------------------------------
printf '\n== summary: %d passed, %d failed, %d skipped\n' "$PASSED" "${#FAILED[@]}" "${#SKIPPED[@]}"
for f in "${FAILED[@]}"; do echo "   FAILED:  $f"; done
for s in "${SKIPPED[@]}"; do echo "   SKIPPED: $s"; done
(( ${#FAILED[@]} == 0 )) && echo "QUALIFICATION PASS" && exit 0
echo "QUALIFICATION FAIL"; exit 1
