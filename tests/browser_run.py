"""Run one Rexx program in headless Chromium against the WASM runtime.

Setup (from the build's bin/ directory):
    cp <project>/tests/t.html <bin>/
    python3 <oorexx>/wasm/tests/http_isolated.py <bin> &      # COOP/COEP on :8000
    OOREXX_WASM_TEST_PORT=50010 python3 <oorexx>/wasm/tests/ws_echo.py &   # for socket tests

Usage:
    timeout 40 python3 browser_run.py 'say "hello"' || echo HANG

The page's main thread can freeze (e.g. thread creation without a pthread
pool); the outer `timeout` is what detects that.
"""
import sys, time, urllib.parse
from playwright.sync_api import sync_playwright

prog = sys.argv[1]
with sync_playwright() as p:
    b = p.chromium.launch(args=["--no-sandbox"])
    pg = b.new_page()
    pg.goto("http://127.0.0.1:8000/t.html#" + urllib.parse.quote(prog),
            wait_until="commit", timeout=15000)
    t = time.time(); st = ""
    while time.time() - t < 15:
        time.sleep(0.5)
        try:
            st = pg.evaluate("document.getElementById('status').textContent")
        except Exception:
            st = "EVAL-FAIL (page hung?)"; break
        if "exited" in st or "JSERROR" in st:
            break
    try:
        out = pg.evaluate("document.getElementById('output').textContent")
    except Exception:
        out = "(unreadable)"
    print("   ", out.strip()[-300:].replace("\n", " | "))
    print("    status:", st, f"({time.time() - t:.1f}s)")
    b.close()
