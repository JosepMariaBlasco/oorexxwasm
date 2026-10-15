#!/usr/bin/env python3
"""The debugger for pages with <script type="text/rexx"> (debugger/ooRexx-debugger.js,
loaded by ooRexx.js with ?rexx-debug=1): drives tests/page-debugger/test.html.

Usage: python3 tests/page-debugger/check.py [BIN_WEB=$ORX_WASM_WORK/build-wasm/bin-web] [ENGINE=chromium]
ENGINE: chromium, firefox or webkit (Playwright's; set PLAYWRIGHT_BROWSERS_PATH as needed).
Exits non-zero on any failure."""
import os, sys, time, shutil, tempfile, threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
WORK = os.environ.get("ORX_WASM_WORK", os.path.dirname(REPO))
BIN = sys.argv[1] if len(sys.argv) > 1 else os.path.join(WORK, "build-wasm", "bin-web")
ENGINE = sys.argv[2] if len(sys.argv) > 2 else "chromium"
RUNTIME = ["rexx.js", "rexx.wasm", "rexx.data", "ooRexx.js", "ooRexx-worker.js", "polygon-clipping.umd.min.js", "js-realm.js"]

site = tempfile.mkdtemp(prefix="page-debugger-")
for f in RUNTIME: shutil.copy(os.path.join(BIN, f), site)
shutil.copy(os.path.join(REPO, "debugger", "ooRexx-debugger.js"), site)
os.makedirs(os.path.join(site, "debugger"))
for f in ("RexxDebugger.rex", "RexxDebuggerWebUI.rex"): shutil.copy(os.path.join(REPO, "debugger", f), os.path.join(site, "debugger"))
for f in ("test.html", "handlers.rex"): shutil.copy(os.path.join(HERE, f), site)

class H(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=site, **k)
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
    def log_message(self, *a): pass
srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()
BASE = "http://127.0.0.1:%d/" % srv.server_address[1]
H_REX = BASE + "handlers.rex"

fails = []
def check(cond, what, detail=""):
    print(("ok   " if cond else "FAIL ") + what + ("" if cond or not detail else "  -- " + str(detail)[:300]))
    if not cond:
        fails.append(what)
        if os.environ.get("DIAG"): diag()

diag = lambda: None
def until(fn, t=30):
    end = time.time() + t
    while time.time() < end:
        try:
            v = fn()
            if v: return v
        except Exception: pass
        time.sleep(0.1)
    return None

with sync_playwright() as p:
    b = getattr(p, ENGINE).launch()
    ctx = b.new_context()
    # the console as the page writes it (Playwright's console events may come late)
    ctx.add_init_script("window.__logs = []; for (const k of ['log', 'warn', 'error']) {"
                        " const o = console[k].bind(console); console[k] = (...a) => { window.__logs.push(a.join(' ')); o(...a); }; }")
    page = ctx.new_page()
    class Logs:
        def __iter__(self): return iter(page.evaluate("window.__logs || []"))
        def __getitem__(self, i): return list(self)[i]
        def __repr__(self): return repr(list(self))
        def clear(self): pass                  # each page load starts afresh
    logs = Logs()
    text = lambda sel: page.locator(sel).first.inner_text()
    status = lambda: page.locator("#ooRexx-debugger .status").inner_text()
    paused = lambda: until(lambda: status().startswith("Paused"))
    def tab(label): return page.locator("#ooRexx-debugger .tab", has_text=label)
    diag = lambda: print("   status:", status(), "| out:", repr(page.locator("#ooRexx-debugger .out").text_content())[-300:], "| logs:", logs[-6:], "| exec:", page.evaluate("(() => { const e = document.getElementById('ooRexx-debugger').shadowRoot.querySelector('.exec'); return [e.value, e.disabled, document.activeElement && document.activeElement.id, e.getRootNode().activeElement === e]; })()"))
    def src_row(label, n):
        tab(label).click()
        return page.locator('#ooRexx-debugger .src.on .ln[data-line="%d"]' % n)

    # 1. without rexx-debug=1: no debugger
    page.goto(BASE + "test.html")
    check(until(lambda: text("#sum") == "sum 6"), "without rexx-debug=1 the scripts run")
    check(page.locator("#ooRexx-debugger").count() == 0, "  and there is no debugger")

    # 2. with it: the panel, the scripts' sources, no stops, output in the console
    logs.clear()
    page.goto(BASE + "test.html?rexx-debug=1")
    check(until(lambda: text("#sum") == "sum 6", 60), "with rexx-debug=1 the scripts run (no breakpoints: no stops)")
    check(until(lambda: any("handlers set" in l for l in logs) and any("script 1 done" in l for l in logs)), "  their output goes to the console", logs)
    check(not any("+++" in l for l in logs), "  and no interactive trace messages", logs)
    check(until(lambda: status().startswith("Running")), "  the panel says Running", status())
    check(page.locator("#ooRexx-debugger .tab").count() == 2, "  a tab per script")
    check(not any("*-*" in l for l in logs), "  no trace output in the console", [l for l in logs if "*-*" in l][:3])

    # 3. a breakpoint in the click handler
    src_row("handlers.rex", 12).locator(".n").click()
    check("bp" in src_row("handlers.rex", 12).get_attribute("class"), "a click on a line number sets a breakpoint")
    page.click("#btn")
    check(paused(), "the click stops at the breakpoint in the handler", status())
    check("line 12 of handlers.rex" in status(), "  after line 12 of handlers.rex", status())
    check("cur" in src_row("handlers.rex", 12).get_attribute("class"), "  the line is marked")
    check(until(lambda: "COUNT" in text("#ooRexx-debugger .vars") and "1" in text("#ooRexx-debugger .vars")), "  the variables", text("#ooRexx-debugger .vars"))
    check(page.locator("#ooRexx-debugger ol li").count() == 1 and "handlers.rex:12" in text("#ooRexx-debugger ol"), "  the stack: the handler only", text("#ooRexx-debugger ol"))
    t0 = time.time(); page.evaluate("document.title"); check(time.time() - t0 < 1, "  the page answers while paused")

    # 4. step (F10), Rexx in context, run (F8)
    page.keyboard.press("F10")
    check(until(lambda: "line 13 of" in status()), "F10 steps to line 13", status())
    page.locator("#ooRexx-debugger .exec").fill("say 'count is' count")
    page.locator("#ooRexx-debugger .exec").press("Enter")
    check(until(lambda: "count is 1" in page.locator("#ooRexx-debugger .out").text_content()), "say in the panel shows there", page.locator("#ooRexx-debugger .out").text_content())
    page.keyboard.press("F8")
    check(until(lambda: text("#out") == "clicked 1"), "F8 runs on: the handler finishes")
    check(until(lambda: status().startswith("Running")), "  Running again", status())

    # 5. clear it; a click runs straight through
    src_row("handlers.rex", 12).locator(".n").click()
    page.click("#btn")
    check(until(lambda: text("#out") == "clicked 2"), "breakpoint cleared: the next click is not stopped")

    # 6. Break, then a click: stops in the handler
    page.locator("#ooRexx-debugger button", has_text="Break").click()
    page.click("#btn")
    check(paused(), "Break, then a click: stops at the handler's next clause", status())
    page.locator("#ooRexx-debugger button", has_text="Run").click()
    check(until(lambda: text("#out") == "clicked 3"), "  Run: it finishes")

    # 7. an error in a handler shows in the panel and in the console
    page.click("#btn")
    check(until(lambda: "Error 41" in page.locator("#ooRexx-debugger .out").text_content(), 20), "an error in a handler shows in the panel", page.locator("#ooRexx-debugger .out").text_content())
    if status().startswith("Paused"): page.keyboard.press("F8")

    # 8. breakpoints are remembered: a reload stops in the scripts' first run
    src_row("script 1", 4).locator(".n").click()
    logs.clear()
    page.reload()
    check(paused(), "reload: a remembered breakpoint stops the first run of script 1", status())
    check("line 4 of script 1" in status(), "  after line 4 (in the loop)", status())
    check(until(lambda: "TOTAL\t1" in text("#ooRexx-debugger .vars")), "  TOTAL = 1", text("#ooRexx-debugger .vars"))
    check(page.locator("#sum").inner_text() == "", "  the script has not finished")
    page.locator("#ooRexx-debugger .status").click()     # the keyboard to the page (Firefox, after a reload)
    page.keyboard.press("F8")
    check(until(lambda: "TOTAL\t3" in text("#ooRexx-debugger .vars")), "  F8: the next time round, TOTAL = 3", text("#ooRexx-debugger .vars"))
    src_row("script 1", 4).locator(".n").click()
    page.keyboard.press("F8")
    check(until(lambda: text("#sum") == "sum 6"), "  breakpoint cleared, F8: the script finishes")

    # 9. the panel folds, and stays folded
    page.locator("#ooRexx-debugger .bar button").last.click()
    check(page.locator("#ooRexx-debugger .body").is_hidden(), "the panel folds")
    page.reload()
    check(until(lambda: page.locator("#ooRexx-debugger .panel").count() == 1), "  after a reload")
    check(until(lambda: page.locator("#ooRexx-debugger .body").is_hidden()), "  it is still folded")
    b.close()

srv.shutdown()
shutil.rmtree(site, ignore_errors=True)
print("== %s: %d failed" % (ENGINE, len(fails)))
sys.exit(1 if fails else 0)
