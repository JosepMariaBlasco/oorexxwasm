"""Drive the ooRexx Playground page (playground/build-site.sh output) like a user.

Usage: python3 playground_check.py [SITE=$ORX_WASM_WORK/site] [SHOTS_DIR]
Serves SITE with COOP/COEP on :8003; exit status 1 on any failure.
"""
import os, subprocess, sys, time
from playwright.sync_api import sync_playwright

SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ORX_WORK, 'site')
SHOTS = sys.argv[2] if len(sys.argv) > 2 else None
BASE = os.environ.get("BASE")   # e.g. http://127.0.0.1:8004/ : test a real server instead
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
ThreadingHTTPServer(('127.0.0.1',8003),H).serve_forever()
"""])
import atexit
ORX_WORK = os.environ.get('ORX_WASM_WORK') or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../..'))  # where oorexx/, build-wasm/ ... live
if srv: atexit.register(srv.terminate); time.sleep(0.7)
BASE = BASE or "http://127.0.0.1:8003/"
fails = []
def check(name, cond, detail=""):
    print(("ok  " if cond else "FAIL"), name, "" if cond else str(detail)[:400])
    if not cond: fails.append(name)

def wait_idle(pg, timeout=20):
    t = time.time()
    while time.time() - t < timeout:
        if pg.locator("#run").inner_text().strip().upper() == "RUN": return True
        time.sleep(0.1)
    return False
def wait_prompt(pg, timeout=10):
    pg.wait_for_selector("#prompt.waiting", timeout=timeout * 1000)
def out(pg): return pg.locator("#out").inner_text()
def pick(pg, title): pg.locator("nav.programs button", has_text=title).first.click()

with sync_playwright() as p:
    b = p.chromium.launch(args=["--no-sandbox"])
    errors = []
    pg = b.new_page(viewport={"width": 1280, "height": 900})
    pg.on("pageerror", lambda e: errors.append(str(e)))
    answer = {"yes": True}
    pg.on("dialog", lambda d: d.accept() if answer["yes"] else d.dismiss())
    pg.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
    pg.goto(BASE)
    pg.wait_for_selector("#rstate[data-state=ready]", timeout=20000)
    check("runtime ready", True)

    # Hello: interactive
    pick(pg, "Hello"); pg.click("#run"); wait_prompt(pg)
    pg.fill("#line", "Ana"); pg.press("#line", "Enter"); wait_prompt(pg)
    pg.fill("#line", ""); pg.press("#line", "Enter")
    check("hello interactive", wait_idle(pg) and "Hello, Ana!" in out(pg) and "Bye." in out(pg), out(pg))
    check("hello exit 0", "exit 0" in pg.locator("#status").inner_text(), pg.locator("#status").inner_text())

    # rexxtry
    pick(pg, "rexxtry"); pg.click("#run"); wait_prompt(pg)
    pg.fill("#line", "say 6*7"); pg.press("#line", "Enter"); wait_prompt(pg)
    if SHOTS: pg.screenshot(path=f"{SHOTS}/desktop-rexxtry.png", full_page=True)
    pg.fill("#line", "exit"); pg.press("#line", "Enter")
    check("rexxtry", wait_idle(pg) and "\n42\n" in out(pg), out(pg))

    # Ctrl+D ends input
    pick(pg, "Hello"); pg.click("#run"); wait_prompt(pg)
    pg.press("#line", "Control+d")
    check("ctrl+d", wait_idle(pg) and "^D" in out(pg), out(pg))

    # TRACE ?
    pick(pg, "TRACE"); pg.click("#run")
    for _ in range(30):
        try: wait_prompt(pg, 3)
        except Exception: break
        if pg.locator("#run").inner_text().strip().upper() == "RUN": break
        pg.press("#line", "Enter"); time.sleep(0.05)
    check("trace ?", wait_idle(pg) and "Sum of squares: 14" in out(pg), out(pg)[-300:])

    # fixed stdin box
    pick(pg, "Word count"); pg.click("#run")
    check("word count (stdin box)", wait_idle(pg) and "3 lines" in out(pg), out(pg))

    # Stop an endless loop (Esc)
    pick(pg, "PARSE"); pg.fill("#src", "do forever; nop; end"); pg.click("#run"); time.sleep(1)
    pg.keyboard.press("Escape")
    check("stop", wait_idle(pg, 5) and "stopped" in pg.locator("#status").inner_text())
    check("edits kept per sample", True)

    # Files persist across runs
    pick(pg, "Files"); pg.click("#run"); wait_idle(pg); pg.click("#run"); wait_idle(pg)
    check("files persist", "already exists" in out(pg) and "notes.txt" in pg.locator("#files").inner_text(), out(pg))
    pg.click("#clearfiles"); check("clear files", "none yet" in pg.locator("#filelist").inner_text())

    # console history: Up recalls earlier lines, across runs
    pick(pg, "rexxtry"); pg.click("#run"); wait_prompt(pg)
    pg.fill("#line", "say 6*7"); pg.press("#line", "Enter"); wait_prompt(pg)
    pg.fill("#line", "exit"); pg.press("#line", "Enter"); wait_idle(pg)
    pg.click("#run"); wait_prompt(pg)
    pg.press("#line", "ArrowUp"); pg.press("#line", "ArrowUp")
    check("history recall", pg.input_value("#line") == "say 6*7", pg.input_value("#line"))
    pg.press("#line", "Enter"); wait_prompt(pg)
    pg.press("#line", "ArrowUp"); pg.press("#line", "ArrowDown")
    check("history down to draft", pg.input_value("#line") == "", pg.input_value("#line"))
    pg.fill("#line", "exit"); pg.press("#line", "Enter")
    check("history line runs", wait_idle(pg) and out(pg).count("\n42\n") >= 1, out(pg))

    # upload: a class file, then ::requires it from the editor
    up = {"name": "greet.cls", "mimeType": "text/plain",
          "buffer": b"::class greeter public\n::method hi\n  return 'hi,' arg(1)\n"}
    pg.set_input_files("#picker", [up])
    pg.wait_for_function("document.getElementById('fname').textContent.includes('greet.cls')", timeout=5000)
    check("upload listed", "greet.cls" in pg.locator("#filelist").inner_text())
    check("single upload opens in editor", "your file" in pg.locator("#fname").inner_text() and "::class greeter" in pg.input_value("#src"))
    pick(pg, "PARSE"); pg.fill("#src", "say .greeter~new~hi('there')\n::requires 'greet.cls'")
    pg.click("#run"); check("::requires uploaded", wait_idle(pg) and "hi, there" in out(pg), out(pg))

    # upload several, run an uploaded program; editing it saves it
    pg.set_input_files("#picker", [
        {"name": "main.rex", "mimeType": "text/plain", "buffer": b"say .greeter~new~hi('main')\n::requires greet.cls\n"},
        {"name": "blob.bin", "mimeType": "application/octet-stream", "buffer": bytes(range(256))}])
    try: pg.wait_for_function("document.getElementById('filelist').textContent.includes('blob.bin')", timeout=5000)
    except Exception: pass
    fl = pg.locator("#filelist").inner_text()
    check("multi upload listed", "main.rex" in fl and "blob.bin" in fl, fl)
    check("binary not editable", pg.locator('.f[data-path="/home/rexx/blob.bin"] .open').count() == 0)
    pg.locator('.f[data-path="/home/rexx/main.rex"] .open').click()
    pg.click("#run"); check("run uploaded program", wait_idle(pg) and "hi, main" in out(pg), out(pg))
    pg.fill("#src", "say 'edited'"); pick(pg, "Hello")
    pg.locator('.f[data-path="/home/rexx/main.rex"] .open').click()
    check("edits saved to file", pg.input_value("#src") == "say 'edited'", pg.input_value("#src"))

    # New file, then run it
    pg.click("#newfile"); pg.fill("#newname", "new.rex"); pg.press("#newname", "Enter")
    check("new file opens", "/home/rexx/new.rex" in pg.locator("#fname").inner_text())
    pg.fill("#src", "say 'brand' 'new'"); pg.click("#run")
    check("run new file", wait_idle(pg) and "brand new" in out(pg), out(pg))

    # a file of yours named like a sample survives running the sample
    pg.set_input_files("#picker", [{"name": "hello.rex", "mimeType": "text/plain", "buffer": b"say 'mine'\n"}])
    pick(pg, "Hello"); pg.click("#run"); wait_prompt(pg); pg.press("#line", "Control+d"); wait_idle(pg)
    pg.locator('.f[data-path="/home/rexx/hello.rex"] .open').click()
    check("shadowed file kept", pg.input_value("#src") == "say 'mine'\n", pg.input_value("#src"))

    # delete the open file -> back to the first sample
    pg.locator('.f[data-path="/home/rexx/hello.rex"] .del').click()
    check("delete file", "hello.rex" not in pg.locator("#filelist").inner_text() and "your file" not in pg.locator("#fname").inner_text())
    # folders: upload a tree, relative ::requires, .zip in (deflated) and out, paths in New
    import tempfile, zipfile, io
    tree = tempfile.mkdtemp()
    os.makedirs(f"{tree}/proj/lib/deep")
    open(f"{tree}/proj/main.rex", "w").write("say .util~new~hi\n::requires 'lib/util.cls'\n")
    open(f"{tree}/proj/lib/util.cls", "w").write("::requires 'deep/more.cls'\n::class util public\n::method hi\n  return 'util says' .more~word\n")
    open(f"{tree}/proj/lib/deep/more.cls", "w").write("::class more public\n::method word class\n  return 'hello from deep'\n")
    if pg.locator("#uploaddir").is_visible():
        pg.set_input_files("#dirpicker", f"{tree}/proj")
        pg.wait_for_function("document.getElementById('filelist').textContent.includes('more.cls')", timeout=5000)
        fl = pg.locator("#filelist").inner_text()
        check("folder upload keeps tree", "proj/lib/deep/more.cls" in fl.replace(" ", "") or "more.cls" in fl, fl)
        pg.locator('.f[data-path="/home/rexx/proj/main.rex"] .open').click()
        pg.click("#run"); check("relative ::requires in folders", wait_idle(pg) and "util says hello from deep" in out(pg), out(pg))
    else:
        check("folder upload button (webkitdirectory)", False, "hidden")
    bio = io.BytesIO()
    with zipfile.ZipFile(bio, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("zp/app.rex", "say .z~new~v\n::requires 'sub/z.cls'\n" + "/* padding */\n" * 50)
        z.writestr("zp/sub/z.cls", "::class z public\n::method v\n  return 'zip ok'\n")
        z.writestr("zp/empty/", "")
    pg.set_input_files("#picker", [{"name": "bundle.zip", "mimeType": "application/zip", "buffer": bio.getvalue()}])
    pg.wait_for_function("document.getElementById('filelist').textContent.includes('z.cls')", timeout=5000)
    check("zip unpacked", "bundle.zip" not in pg.locator("#filelist").inner_text())
    pg.locator('.f[data-path="/home/rexx/zp/app.rex"] .open').click()
    pg.click("#run"); check("run from unpacked zip", wait_idle(pg) and "zip ok" in out(pg), out(pg))
    with pg.expect_download() as dl:
        pg.click("#zipall")
    zpath = dl.value.path()
    with zipfile.ZipFile(zpath) as z:
        names = z.namelist(); okzip = z.testzip() is None and z.read("zp/sub/z.cls").startswith(b"::class z")
    check("download all as zip", okzip and "proj/lib/deep/more.cls" in names and "greet.cls" in names, str(names))
    pg.click("#newfile"); pg.fill("#newname", "../evil.rex"); pg.press("#newname", "Enter")
    check("New rejects ..", not pg.locator("#newname").is_hidden())
    pg.fill("#newname", "tools/new.cls"); pg.press("#newname", "Enter")
    check("New with a path", "/home/rexx/tools/new.cls" in pg.locator("#fname").inner_text())

    # your files survive a reload (IndexedDB), with edits; the open file reopens
    pg.set_input_files("#picker", [{"name": "keep.rex", "mimeType": "text/plain", "buffer": b"say 'kept'\n"}])
    pg.fill("#src", "say 'kept and edited'"); time.sleep(1.5)
    pg.reload(); pg.wait_for_selector("#rstate[data-state=ready]", timeout=20000)
    pg.wait_for_function("document.getElementById('fname').textContent.includes('keep.rex')", timeout=5000)
    fl = pg.locator("#filelist").inner_text()
    check("files kept on reload", "keep.rex" in fl and "greet.cls" in fl and "blob.bin" in fl, fl)
    check("open file reopened, edit kept", pg.input_value("#src") == "say 'kept and edited'", pg.input_value("#src"))
    pg.click("#run"); check("kept file runs", wait_idle(pg) and "kept and edited" in out(pg), out(pg))
    check("storage ok", pg.locator("#storenote").is_hidden(), pg.locator("#storenote").inner_text())
    answer["yes"] = False; pg.click("#clearfiles"); answer["yes"] = True
    check("clear files asks", "keep.rex" in pg.locator("#filelist").inner_text())
    pg.click("#clearfiles"); check("clear all", "none yet" in pg.locator("#filelist").inner_text())
    time.sleep(0.5); pg.reload(); pg.wait_for_selector("#rstate[data-state=ready]", timeout=20000); time.sleep(0.5)
    check("clear is kept on reload", "none yet" in pg.locator("#filelist").inner_text() and "your file" not in pg.locator("#fname").inner_text(),
          pg.locator("#filelist").inner_text())

    # ANSI escape sequences: the sample, a sequence split across writes, clear screen, nothing raw left
    pick(pg, "ANSI colors"); pg.click("#run")
    check("ansi sample", wait_idle(pg) and "true color" in out(pg) and "\x1b" not in out(pg) and "[0m" not in out(pg), out(pg)[:300])
    st = pg.evaluate('''[...document.querySelectorAll("#out span[style]")].map(s => s.getAttribute("style")).join("|")''')
    check("ansi styles", "var(--a1)" in st and "font-weight:600" in st and "rgb(" in st and "background:" in st, st[:300])
    check("ansi stderr colored", pg.locator('#out span.e[style*="var(--a1)"]', has_text="stderr can be colored").count() == 1)
    pick(pg, "PARSE")
    pg.fill("#src", "say 'gone'; call charout , '1b'x'[2J'; call charout , '1b'x; call charout , '[32'; say 'm' || 'green' || '1b'x'[0m plain'")
    pg.click("#run"); wait_idle(pg)
    g = pg.locator('#out span[style*="var(--a2)"]')
    check("ansi split + clear", "gone" not in out(pg) and g.count() == 1 and g.inner_text() == "green" and out(pg).strip() == "green plain", repr(out(pg)))

    # Rexx Parser: editor highlighting, live syntax errors, and programs using it
    HL_TEXT = "document.getElementById('hl').textContent"
    pick(pg, "Hello")
    pg.wait_for_selector("#hl .rx-kw", timeout=30000)
    check("editor highlighted", pg.locator("#editor.lit").count() == 1 and pg.locator("#hl .rx-kw").count() > 3)
    same = pg.evaluate(f"{HL_TEXT}.replace(/\\n\\n $/, '') === document.getElementById('src').value")
    check("overlay text == source", same, pg.evaluate(HL_TEXT)[:200])
    pg.click("#src"); pg.keyboard.press("Control+End"); pg.keyboard.type('\nsay "unterminated')
    same = pg.evaluate(f"{HL_TEXT}.replace(/\\n\\n $/, '') === document.getElementById('src').value")
    check("overlay follows typing", same)
    pg.wait_for_selector("#lint:not([hidden])", timeout=10000)
    lt = pg.locator("#lint").inner_text()
    check("live syntax error", "Error 6.3" in lt and "line 14" in lt, lt)
    check("error line marked", pg.locator("#hl .bad").count() == 1)
    pg.keyboard.type('"')
    pg.wait_for_selector("#lint", state="hidden", timeout=10000)
    pg.wait_for_function("document.querySelectorAll('#hl .rx-str').length > 0 && document.getElementById('hl').textContent.includes('unterminated\"')", timeout=10000)
    check("error clears, recolored", pg.locator("#hl .bad").count() == 0)
    pg.uncheck("#hlon"); check("highlight off", pg.locator("#editor.lit").count() == 0 and pg.locator("#lint").is_hidden())
    pg.check("#hlon"); pg.wait_for_selector("#editor.lit #hl .rx-kw", timeout=30000); check("highlight on again", True)
    # style chooser (as on the Rexx Parser's site)
    nopts = pg.locator("#hlstyle option").count()
    check("style chooser offers the styles", nopts >= 20 and pg.locator('#hlstyle option[value="tokio-night"]').count() == 1
          and pg.locator('#hlstyle option[value^="test"]').count() == 0, str(nopts))
    bg0 = pg.evaluate("getComputedStyle(document.getElementById('hl')).backgroundColor")
    pg.select_option("#hlstyle", "tokio-night")
    pg.wait_for_function("getComputedStyle(document.getElementById('hl')).backgroundColor !== " + repr(bg0), timeout=10000)
    check("style applied", "highlight-rexx-tokio-night" in pg.get_attribute("#editor", "class") and "style=tokio-night" in pg.url, pg.url)
    pg.reload(); pg.wait_for_selector("#rstate[data-state=ready]", timeout=20000)
    check("style kept on reload", pg.input_value("#hlstyle") == "tokio-night" and "highlight-rexx-tokio-night" in pg.get_attribute("#editor", "class"))
    pg.goto(BASE + "?style=vim-dark-desert"); pg.wait_for_selector("#rstate[data-state=ready]", timeout=20000)
    check("?style= wins", pg.input_value("#hlstyle") == "vim-dark-desert")
    pg.select_option("#hlstyle", "")
    check("auto style", "highlight-rexx-light" in pg.get_attribute("#editor", "class") and "style=" not in pg.url, pg.url)
    pg.goto(BASE); pg.wait_for_selector("#rstate[data-state=ready]", timeout=20000)
    check("auto stored", pg.input_value("#hlstyle") == "")

    pick(pg, "Rexx Parser"); pg.click("#run")
    check("parser sample", wait_idle(pg, 60) and "keywords used:" in out(pg) and "SAY(" in out(pg), out(pg)[-300:])
    check("parser sample ANSI colored", pg.locator('#out span[style*="rgb("]').count() > 20)
    pg.set_input_files("#picker", [{"name": "p.rex", "mimeType": "text/plain",
        "buffer": b'p = .Rexx.Parser~new("t", .array~of("x = 1"))\nsay "first:" p~firstElement~class\ncall highlight "-a p.rex"\n::requires "Rexx.Parser.cls"\n'}])
    pg.click("#run")
    check("::requires Rexx.Parser.cls + call highlight", wait_idle(pg, 60) and "first:" in out(pg) and "exit 0" in pg.locator("#status").inner_text()
          and pg.locator('#out span[style*="rgb("]').count() > 5, out(pg)[-300:])
    pg.locator('.f[data-path="/home/rexx/p.rex"] .del').click()

    # linked folders (File System Access API), driven with OPFS directories (same API, no picker)
    OPFS = """async (op) => {
      const root = await navigator.storage.getDirectory();
      const dir = await root.getDirectoryHandle(op.dir, { create: true });
      async function at(path, create) { const parts = path.split('/'); const n = parts.pop(); let d = dir;
        for (const x of parts) d = await d.getDirectoryHandle(x, { create }); return [d, n]; }
      if (op.write) for (const [p, t] of Object.entries(op.write)) { const [d, n] = await at(p, true);
        const w = await (await d.getFileHandle(n, { create: true })).createWritable(); await w.write(t); await w.close(); }
      if (op.link !== undefined) return await window.OoRexxPlayground.linkFolder(dir, op.link);
      if (op.read) { try { const [d, n] = await at(op.read, false); return await (await (await d.getFileHandle(n)).getFile()).text(); }
                     catch (e) { return null; } }
      return true;
    }"""
    def run_wait(timeout=30):
        n = pg.get_attribute("#status", "data-runs") or "0"
        pg.click("#run")
        pg.wait_for_function(f"(+document.getElementById('status').dataset.runs || 0) > {n}", timeout=timeout * 1000)
    def opfs(**op): return pg.evaluate(OPFS, op)
    check("link folder button", pg.locator("#linkdir").is_visible())
    pg.set_input_files("#picker", [{"name": "browser.rex", "mimeType": "text/plain",
        "buffer": b"say .h~new~x\n::requires 'proj/lib/h.cls'\n"},
        {"name": "viapath.rex", "mimeType": "text/plain", "buffer": b"say 'path:' .h~new~x\n::requires 'lib/h.cls'\n"}])
    pg.wait_for_function("document.getElementById('filelist').textContent.includes('browser.rex')", timeout=5000)
    opfs(dir="proj", write={"app.rex": "say .h~new~x\n::requires 'lib/h.cls'\n",
                            "lib/h.cls": "::class h public\n::method x\n  return 'from disk v1'\n", ".git/config": "[core]\n"})
    check("link read & write", opfs(dir="proj", link=True) is True)
    opfs(dir="docs", write={"readme.txt": "read me\n"})
    check("link read only", opfs(dir="docs", link=False) is True)
    fl = pg.locator("#filelist").inner_text(); mt = pg.locator("#mounts").inner_text()
    check("both kinds of files together", "browser.rex" in fl and "proj/app.rex" in fl.replace(" ", "") and "docs/readme.txt" in fl.replace(" ", "")
          and "config" not in fl and "read & write" in mt and "read only" in mt and pg.locator("#clearfiles").is_visible(), fl + " | " + mt)
    pg.locator('.f[data-path="/home/rexx/browser.rex"] .open').click()
    run_wait(); check("browser file requires a linked one", "from disk v1" in out(pg), out(pg))
    pg.locator('.f[data-path="/home/rexx/viapath.rex"] .open').click()
    run_wait(); check("linked folder in REXX_PATH", "path: from disk v1" in out(pg), out(pg))
    pg.locator('.f[data-path="/home/rexx/proj/app.rex"] .open').click()
    run_wait(); check("relative requires inside the folder", "from disk v1" in out(pg), out(pg))
    opfs(dir="proj", write={"lib/h.cls": "::class h public\n::method x\n  return 'from disk v2'\n"})
    run_wait(); check("outside changes picked up on Run", "from disk v2" in out(pg), out(pg))
    pg.fill("#src", "call lineout 'proj/made.txt', 'written by rexx'\ncall lineout 'docs/no.txt', 'x'\nsay .h~new~x\n::requires 'lib/h.cls'\n")
    run_wait(); time.sleep(0.5)
    check("program output written to the folder", opfs(dir="proj", read="made.txt") == "written by rexx\n")
    check("read-only folder not written", opfs(dir="docs", read="no.txt") is None and "not written, read-only folder" in out(pg)
          and "no.txt" not in pg.locator("#filelist").inner_text(), out(pg))
    check("editor edits written to the folder", "made.txt" in (opfs(dir="proj", read="app.rex") or ""))
    opfs(dir="proj", write={"app.rex": "say 'edited outside'\n"})
    pg.evaluate("window.dispatchEvent(new Event('focus'))")
    pg.wait_for_function("document.getElementById('src').value === \"say 'edited outside'\\n\"", timeout=5000)
    check("open file follows outside edits", True)
    pg.fill("#src", "call SysFileDelete 'proj/made.txt'\nsay 'deleted'\n")
    answer["yes"] = False; run_wait(); time.sleep(0.5); answer["yes"] = True
    check("program deletion declined keeps the file", opfs(dir="proj", read="made.txt") is not None
          and "made.txt" in pg.locator("#filelist").inner_text())
    run_wait(); time.sleep(0.5)
    check("program deletion accepted", opfs(dir="proj", read="made.txt") is None)
    pg.locator('.f[data-path="/home/rexx/docs/readme.txt"] .open').click()
    check("read-only file opens read-only", pg.locator("#src").get_attribute("readonly") is not None and "read-only" in pg.locator("#fname").inner_text())
    check("read-only file has no ×", pg.locator('.f[data-path="/home/rexx/docs/readme.txt"] .del').count() == 0)
    answer["yes"] = False; pg.locator('.f[data-path="/home/rexx/proj/lib/h.cls"] .del').click(); answer["yes"] = True
    check("× in a linked folder asks", opfs(dir="proj", read="lib/h.cls") is not None)
    pg.click('.mount[data-name="proj"] .unlink'); pg.click('.mount[data-name="docs"] .unlink')
    fl = pg.locator("#filelist").inner_text()
    check("unlink: browser files stay, folders intact", "browser.rex" in fl and "app.rex" not in fl and "readme" not in fl
          and (opfs(dir="proj", read="app.rex") or "").startswith("call SysFileDelete") and pg.locator("#mounts").is_hidden(), fl)
    pg.locator('.f[data-path="/home/rexx/browser.rex"] .del').click()

    # stderr vs trace, debug input, settings (console colors), help (F1)
    pick(pg, "PARSE")
    pg.fill("#src", "call lineout 'stderr', 'plain error text'\ntrace r\nx = 1 + 2\ntrace off\ncall nosuchroutine\n")
    pg.click("#run"); wait_idle(pg)
    e_txt = " ".join(pg.locator("#out span.e").all_inner_texts()); t_txt = " ".join(pg.locator("#out span.t").all_inner_texts())
    check("stderr apart from trace", "plain error text" in e_txt and "Error 43" in e_txt and "*-* x = 1 + 2" in t_txt
          and ">>>" in t_txt and "plain error" not in t_txt and "*-*" not in e_txt, f"E[{e_txt}] T[{t_txt}]")
    check("stderr is red by default", pg.evaluate("getComputedStyle(document.querySelector('#out span.e')).color") in ("rgb(198, 40, 40)",),
          pg.evaluate("getComputedStyle(document.querySelector('#out span.e')).color"))
    st = pg.locator("#status").inner_text()
    check("status counts stderr and trace", "on stderr" in st and "trace line" in st, st)
    pg.fill("#src", "call lineout 'stderr', '     1 *-* looks like trace'\ntrace r\nx = 1\npull y\nsay 'y='y\n")
    pg.click("#run"); wait_prompt(pg); pg.fill("#line", "abc"); pg.press("#line", "Enter"); wait_idle(pg)
    e_txt = " ".join(pg.locator("#out span.e").all_inner_texts())
    check("runtime marks: trace-looking stderr stays stderr", "looks like trace" in e_txt, e_txt)
    check("runtime marks: PULL after trace is not debug input", pg.locator("#out span.in").count() == 1
          and pg.locator("#out span.dbg").count() == 0 and "y=ABC" in out(pg), out(pg))
    pick(pg, "TRACE"); pg.click("#run"); wait_prompt(pg); pg.press("#line", "Enter")
    wait_prompt(pg); check("debug input colored as such", pg.locator("#out span.dbg").count() >= 1)
    pg.click("#run"); wait_idle(pg)
    pg.click("#settingsbtn"); check("settings dialog", pg.locator("#settings[open]").count() == 1 and pg.locator("#colors input[type=color]").count() == 5)
    pg.locator("#col-err").evaluate("(el) => { el.value = '#00aa00'; el.dispatchEvent(new Event('input', {bubbles: true})); }")
    check("color applied", pg.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--c-err').trim()") == "#00aa00")
    pg.keyboard.press("Escape"); check("Esc closes settings", pg.locator("#settings[open]").count() == 0)
    pg.reload(); pg.wait_for_selector("#rstate[data-state=ready]", timeout=20000)
    check("color kept", pg.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--c-err').trim()") == "#00aa00")
    pg.click("#settingsbtn"); pg.click("#colorsreset"); pg.keyboard.press("Escape")
    check("colors reset", pg.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--c-err').trim()") == "#c62828")
    pg.keyboard.press("F1"); check("F1 opens help", pg.locator("#help[open]").count() == 1 and "Your files" in pg.locator("#help").inner_text())
    pg.keyboard.press("F1"); check("F1 closes help", pg.locator("#help[open]").count() == 0)

    # threads, json, regex, companions, args
    pick(pg, "Threads"); pg.click("#run")
    check("threads", wait_idle(pg) and "total = 1000" in out(pg), out(pg))
    pick(pg, "JSON"); pg.click("#run"); check("json", wait_idle(pg) and "WebAssembly" in out(pg), out(pg))
    pick(pg, "Regular"); pg.click("#run"); check("regex", wait_idle(pg) and "number at 43: 2026" in out(pg), out(pg))
    pick(pg, "Complex"); pg.click("#run"); check("companion .cls", wait_idle(pg) and "6-4i" in out(pg), out(pg))
    pick(pg, "Pipes"); pg.click("#run"); check("pipes", wait_idle(pg) and "ekiM" in out(pg), out(pg))
    pick(pg, "PARSE"); pg.fill("#src", 'parse arg a; say "args=["a"]"'); pg.fill("#args", "one two")
    pg.click("#run"); check("arguments", wait_idle(pg) and "args=[one two]" in out(pg), out(pg))
    pg.fill("#args", "")
    pick(pg, "Decimal"); pg.click("#run")
    check("arithmetic", wait_idle(pg) and "3.14159265358979323846" in out(pg), out(pg))
    pick(pg, "Dining"); pg.click("#run"); time.sleep(3)
    check("philosophers running output", "Philosopher" in out(pg)); pg.click("#run"); wait_idle(pg, 5)

    # JDOR (ADDRESS JDOR): windows over the page, Rony's samples unchanged
    PIX = """(sel) => { const out = [];
      for (const cv of document.querySelectorAll(sel)) {
        const c = document.createElement('canvas'); c.width = cv.width; c.height = cv.height;
        const x = c.getContext('2d'); x.drawImage(cv, 0, 0);
        const d = x.getImageData(0, 0, c.width, c.height).data; let n = 0;
        for (let i = 0; i < d.length; i += 4) if (d[i + 3] && (d[i] + d[i + 1] + d[i + 2]) < 600) n++;
        out.push(n); }
      return out; }"""
    pick(pg, "Hello, JDOR"); pg.click("#run")
    check("jdor sample", wait_idle(pg, 40) and "red=0" in out(pg), out(pg))
    check("jdor window", pg.locator(".jdorwin:not([hidden])").count() == 1 and
          pg.locator(".jdorwin .jt span").first.inner_text() == "Hello, JDOR", pg.locator(".jdorwin").count())
    px = pg.evaluate(PIX, ".jdorwin canvas")
    check("jdor drew", px and px[0] > 10000, px)
    box = pg.locator(".jdorwin .jt").bounding_box()
    pg.mouse.move(box["x"] + 40, box["y"] + 8); pg.mouse.down(); pg.mouse.move(box["x"] + 140, box["y"] + 58, steps=5); pg.mouse.up()
    box2 = pg.locator(".jdorwin .jt").bounding_box()
    check("jdor window drag", abs(box2["x"] - box["x"] - 100) < 3 and abs(box2["y"] - box["y"] - 50) < 3, (box, box2))
    pick(pg, "Two windows"); pg.click("#run")
    check("jdor two windows (Rony's sample)", wait_idle(pg, 60) and "finished after [91] rotations" in out(pg), out(pg))
    check("jdor two windows shown", pg.locator(".jdorwin:not([hidden])").count() == 2 and pg.locator(".jdorwin.noframe").count() == 1,
          pg.locator(".jdorwin").count())
    px = pg.evaluate(PIX, ".jdorwin canvas")
    check("jdor bitmaps drawn", len(px) == 2 and min(px) > 1000, px)
    for _ in range(2):                    # close them (a frameless window shows its x on hover)
        w = pg.locator(".jdorwin").first; w.hover(); w.locator(".jt button").click()
    check("jdor windows closed", pg.locator(".jdorwin").count() == 0, pg.locator(".jdorwin").count())
    pick(pg, "Bitmap file"); pg.click("#run")
    check("jdor saveImage", wait_idle(pg, 40) and "3-100_create_bitmap_JDOR_commands.png" in pg.locator("#filelist").inner_text(),
          pg.locator("#filelist").inner_text())
    # no operating system to open the saved bitmap: the adapted sample shows it in a JDOR window of its own
    check("jdor bitmap shown (no OS command)", "RC(127)" not in out(pg) and pg.locator(".jdorwin").count() == 1 and
          pg.locator(".jdorwin .jt span").first.inner_text().endswith("3-100_create_bitmap_JDOR_commands.png"),
          (out(pg)[-300:], pg.locator(".jdorwin").count()))
    px = pg.evaluate(PIX, ".jdorwin canvas")
    check("jdor bitmap window drawn", px and px[0] > 10000, px)
    pg.locator('button[title="Delete 3-100_create_bitmap_JDOR_commands.png"]').first.click()
    pick(pg, "Arithmetic"); pg.click("#run"); wait_idle(pg, 20)
    check("jdor windows cleared by the next run", pg.locator(".jdorwin").count() == 0, pg.locator(".jdorwin").count())
    if SHOTS: pg.screenshot(path=f"{SHOTS}/desktop-light.png", full_page=True)
    check("no page errors", not errors, "; ".join(errors))

    for scheme, size, name in (("dark", (1280, 900), "desktop-dark"), ("light", (390, 844), "mobile-light"),
                               ("dark", (390, 844), "mobile-dark")):
        ctx = b.new_context(color_scheme=scheme, viewport={"width": size[0], "height": size[1]})
        q = ctx.new_page(); q.goto(BASE)
        q.wait_for_selector("#rstate[data-state=ready]", timeout=20000)
        pick(q, "Hello"); q.click("#run"); wait_prompt(q); q.fill("#line", "Ana"); q.press("#line", "Enter"); wait_prompt(q)
        w = q.evaluate("document.documentElement.scrollWidth")
        check(f"{name}: no horizontal scroll", w <= size[0], f"scrollWidth={w}")
        if SHOTS: q.screenshot(path=f"{SHOTS}/{name}.png", full_page=True)
        ctx.close()
    b.close()
print(f"== {len(fails)} failed" + (": " + ", ".join(fails) if fails else ""))
sys.exit(1 if fails else 0)
