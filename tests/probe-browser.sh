#!/usr/bin/env bash
# Browser (headless Chromium) probes, mirroring probe-node.sh.
# Usage: probe-browser.sh /path/to/build-wasm/bin [/path/to/oorexx]
# Starts the COOP/COEP HTTP server (:8000) and the WebSocket echo (:50010)
# if they are not already running, and stops the ones it started.
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
BIN=$(cd "${1:?usage: probe-browser.sh BIN [OOREXX]}" && pwd)
OOREXX=${2:-$ORX_WASM_WORK/oorexx}
HERE=$(cd "$(dirname "$0")" && pwd)
cp "$HERE/t.html" "$BIN/"
pids=()
if ! (exec 3<>/dev/tcp/127.0.0.1/8000) 2>/dev/null; then
  python3 "$OOREXX/wasm/tests/http_isolated.py" "$BIN" >/dev/null 2>&1 & pids+=($!)
fi
if ! (exec 3<>/dev/tcp/127.0.0.1/50010) 2>/dev/null; then
  OOREXX_WASM_TEST_PORT=50010 python3 "$OOREXX/wasm/tests/ws_echo.py" >/dev/null 2>&1 & pids+=($!)
fi
sleep 1
R() { echo "== $1"; timeout 40 python3 "$HERE/browser_run.py" "$2" || echo "    HANG (timeout)"; }

R hello     'say "hello from the browser"; say 2**100'
R start     'say .o~new~start("f")~result; ::class o; ::method f; return "thread ok"'
R reply     'say .t~new~go; say "after"; ::class t; ::method go; reply "early"; say "post-reply"'
R alarm     'a=.alarm~new(0.2, .message~new(.stdout,"lineout","I","alarm fired")); call syssleep 0.6; say done'
R stress10  'do i=1 to 10; m.i=.obj~new~start("hi",i); end; s=0; do i=1 to 10; s=s+m.i~result; end; say "sum="s; ::class obj; ::method hi; use arg k; return k'
R syssleep  'call time "R"; call syssleep 0.5; say "slept" format(time("E"),,1)'
R recursion 'say f(1500); exit; f: procedure; arg n; if n=0 then return 0; return 1+f(n-1)'
R socket    's=SockSocket("AF_INET","SOCK_STREAM","IPPROTO_TCP"); h.!family="AF_INET"; h.!addr="127.0.0.1"; h.!port="50010"; rc=SockConnect(s,"h.!"); n1=SockSend(s,"ping"); n2=SockRecv(s,"back",100); say "connect=" rc "same=" (back=="ping"); call SockClose s'
R streamsock 's=.StreamSocket~new("localhost",50010); o=s~open; n=s~lineOut("Hello"); b=s~lineIn; say "open=" o "in=" b; ::requires "/streamsocket.cls"'

for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done
