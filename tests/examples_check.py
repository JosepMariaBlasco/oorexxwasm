"""Drive the site's example pages (playground/examples/) like a user.

Usage: python3 examples_check.py [SITE=$ORX_WASM_WORK/site]
Serves SITE with COOP/COEP on :8005, or tests BASE (environment: the site's
address, e.g. https://rexx.epbcn.com/oorexx-wasm/). ENGINE=firefox or webkit
drives that engine instead of Chromium. Exit status 1 on any failure.
"""
import os, subprocess, sys, time, urllib.request
from playwright.sync_api import sync_playwright

ORX_WORK = os.environ.get('ORX_WASM_WORK') or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../..'))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ORX_WORK, 'site')
BASE = os.environ.get("BASE")
ENGINE = os.environ.get("ENGINE", "chromium")
srv = None if BASE else subprocess.Popen([sys.executable, "-c", f"""
import os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
os.chdir({SITE!r})
class H(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        self.send_header('Cache-Control','no-cache')
        super().end_headers()
    def log_message(self, *a): pass
ThreadingHTTPServer(('127.0.0.1',8005),H).serve_forever()
"""])
import atexit
if srv: atexit.register(srv.terminate); time.sleep(0.7)
BASE = BASE or "http://127.0.0.1:8005/"
EX = BASE + "examples/"
fails = []
def check(name, cond, detail=""):
    print(("ok  " if cond else "FAIL"), name, "" if cond else str(detail)[:400])
    if not cond: fails.append(name)
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
    b = getattr(p, ENGINE).launch(**({"args": ["--no-sandbox"]} if ENGINE == "chromium" else {}))
    ctx = b.new_context()
    ctx.add_init_script("window.__printed = 0; window.print = () => { window.__printed++; };")
    page = ctx.new_page()
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
    text = lambda sel: page.locator(sel).first.inner_text()

    # the playground links the examples
    html = urllib.request.urlopen(BASE).read().decode()
    check("the playground's footer links examples/", 'href="examples/"' in html)

    # the index
    page.goto(EX)
    check("index: two examples and the example page",
          [page.locator(f'a[href="{h}"]').count() for h in ("reverse/", "print/", "../example/")] == [1, 1, 1])
    check("index: each opens in the debugger too",
          all(page.locator(f'a[href="{h}?rexx-debug=1"]').count() == 1 for h in ("reverse/", "print/", "../example/")))
    d = page.locator('details[data-src="reverse/index.html"]')
    d.locator("summary").click()
    check("index: 'The whole page' shows the file", until(lambda: '<script type="text/rexx">' in d.locator("pre").text_content()),
          d.locator("pre").text_content()[:200])
    if os.environ.get("BASE"):
        st = urllib.request.urlopen(BASE + "example/").status
        check("../example/ is there", st == 200, st)

    # reverse
    page.goto(EX + "reverse/")
    today = page.evaluate("(() => { const d = new Date(); return d.getDate() + ' ' + d.toLocaleString('en', {month: 'short'}) + ' ' + d.getFullYear(); })()")
    check("reverse: today's date, from Rexx in the browser", until(lambda: text("#today") == today), text("#today"))
    check("reverse: the page is cross-origin isolated", page.evaluate("crossOriginIsolated"))
    page.click("#reverse")
    check("reverse: the button reverses the text", until(lambda: text("#result") == "!dlrow ,olleH"), text("#result"))
    page.fill("#text", "Rexx rocks"); page.click("#reverse")
    check("reverse: and again, with new text", until(lambda: text("#result") == "skcor xxeR"), text("#result"))
    check("reverse: no debugger without ?rexx-debug=1", page.locator("#ooRexx-debugger").count() == 0)

    # print
    page.goto(EX + "print/")
    cells = lambda: page.locator("#table td").count()
    check("print: a 5x5 table made by Rexx", until(lambda: cells() == 25 and page.locator("#table td").last.inner_text() == "25"), cells())
    page.fill("#size", "7"); page.click("#make")
    check("print: Make the table, 7x7", until(lambda: cells() == 49 and page.locator("#table td").last.inner_text() == "49"), cells())
    page.click("#print")
    check("print: the button calls the browser's print()", until(lambda: page.evaluate("window.__printed") == 1))
    page.emulate_media(media="print")
    check("print: the buttons and the link are not printed", page.locator(".controls").first.is_hidden() and page.locator(".controls").last.is_hidden())
    page.emulate_media(media="screen")

    # reverse, in the debugger: a breakpoint in the click handler
    page.goto(EX + "reverse/?rexx-debug=1")
    status = lambda: page.locator("#ooRexx-debugger .status").inner_text()
    check("debug: the debugger's panel", until(lambda: page.locator("#ooRexx-debugger .panel").count() == 1))
    row = page.locator('#ooRexx-debugger .src.on .ln', has_text="= reverse(text)")
    check("debug: the handler's line in the panel", until(lambda: row.count() == 1), row.count())
    check("debug: the script runs through", until(lambda: text("#today") == today), text("#today"))
    row.locator(".n").click()
    check("debug: a breakpoint on it", "bp" in (row.get_attribute("class") or ""))
    page.click("#reverse")
    check("debug: the click stops there", until(lambda: status().startswith("Paused")), status())
    check("debug: the variables: TEXT", until(lambda: "TEXT\tHello, world!" in text("#ooRexx-debugger .vars")), text("#ooRexx-debugger .vars"))
    row.locator(".n").click()
    page.locator("#ooRexx-debugger .status").click()
    page.keyboard.press("F8")
    check("debug: breakpoint cleared, F8: the handler finishes", until(lambda: text("#result") == "!dlrow ,olleH"), text("#result"))

    check("no errors in the pages", not errors, errors)
    b.close()
print(len(fails), "failed")
sys.exit(1 if fails else 0)
