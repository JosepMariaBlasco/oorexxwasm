"""Like browser_run.py, but prints every console message / page error with
its stack (useful with a --profiling-funcs build to see wasm function names).
Usage: python3 browser_trace.py URL_PATH 'rexx program'
  e.g. python3 browser_trace.py names/t.html 'say 1'
"""
import sys, time, urllib.parse
from playwright.sync_api import sync_playwright
path, prog = sys.argv[1], sys.argv[2]
with sync_playwright() as p:
    b = p.chromium.launch(args=["--no-sandbox"])
    pg = b.new_page()
    pg.on("console", lambda m: print("console:", m.text))
    pg.on("pageerror", lambda e: print("pageerror:", e.message, "\n", (e.stack or "")))
    pg.goto("http://127.0.0.1:8000/" + path + "#" + urllib.parse.quote(prog), wait_until="commit")
    time.sleep(6)
    b.close()
