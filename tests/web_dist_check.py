"""Check the browser distribution (scripts/web-package.sh): serve it with its
own serve.mjs and drive its example page in headless Chromium.

Usage: python3 web_dist_check.py DIR_OR_ZIP [PORT=8005] [chromium|firefox|webkit]
DIR_OR_ZIP is oorexxwasm-web-VERSION.zip or the directory it unpacks into.
Needs node and Python Playwright (and the browser). Exit status 1 on any failure.
"""
import os, subprocess, sys, tempfile, time, urllib.request, urllib.error, zipfile
from playwright.sync_api import sync_playwright

src = sys.argv[1]
port = int(sys.argv[2]) if len(sys.argv) > 2 else 8005
engine = sys.argv[3] if len(sys.argv) > 3 else 'chromium'
if src.endswith('.zip'):
    tmp = tempfile.mkdtemp(prefix='web-dist-')
    with zipfile.ZipFile(src) as z:
        z.extractall(tmp)
        top = {n.split('/')[0] for n in z.namelist()}
    assert len(top) == 1, f'the zip should unpack into one directory, not {sorted(top)}'
    root = os.path.join(tmp, top.pop())
else:
    root = src

fails = []
def check(name, cond, detail=''):
    print(('ok  ' if cond else 'FAIL'), name, '' if cond else str(detail)[:400])
    if not cond: fails.append(name)

for f in ('ooRexx.js', 'ooRexx-worker.js', 'rexx.js', 'rexx.wasm', 'rexx.data', 'js-realm.js',
          'polygon-clipping.umd.min.js', 'index.html', 'app.rex', 'serve.mjs', '.htaccess',
          'README.md', 'CPLv1.0.txt', 'LICENSE-Apache-2.0.txt'):
    check(f'file {f}', os.path.isfile(os.path.join(root, f)))

# serve.mjs is started from another directory: it must serve its own by default
srv = subprocess.Popen(['node', os.path.join(root, 'serve.mjs'), '--port', str(port)],
                       cwd=tempfile.gettempdir(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
try:
    banner = srv.stdout.readline()
    check('serve.mjs starts', 'cross-origin isolated' in banner, banner)
    base = f'http://127.0.0.1:{port}/'

    def head(path):
        try:
            with urllib.request.urlopen(urllib.request.Request(base + path, method='HEAD')) as r:
                return r.status, dict(r.headers)
        except urllib.error.HTTPError as e:
            return e.code, dict(e.headers)
    st, h = head('rexx.wasm')
    check('rexx.wasm: 200, application/wasm', st == 200 and h.get('Content-Type') == 'application/wasm', (st, h))
    st, h = head('')
    check('index: COOP same-origin, COEP require-corp',
          h.get('Cross-Origin-Opener-Policy') == 'same-origin' and h.get('Cross-Origin-Embedder-Policy') == 'require-corp', h)
    check('no path traversal', head('..%2f..%2fetc%2fpasswd')[0] in (403, 404))
    check('missing file: 404', head('nothing-here')[0] == 404)

    with sync_playwright() as p:
        b = getattr(p, engine).launch(**({'args': ['--no-sandbox']} if engine == 'chromium' else {}))
        print('   browser:', engine, b.version)
        pg = b.new_page()
        console, errors = [], []
        pg.on('console', lambda m: (errors if m.type == 'error' else console).append(m.text))
        pg.on('pageerror', lambda e: errors.append(str(e)))
        pg.goto(base)
        check('cross-origin isolated', pg.evaluate('crossOriginIsolated'))
        try:
            pg.wait_for_function("document.getElementById('greeting').textContent.startsWith('Hello from REXX-ooRexx')", timeout=30000)
            check('script 1 sets the greeting', True)
        except Exception as e:
            check('script 1 sets the greeting', False, pg.locator('#greeting').inner_text())
        pg.wait_for_function("ooRexx.scripts !== null", timeout=10000)
        pg.evaluate('ooRexx.scripts')            # all the scripts have run
        for _ in range(3): pg.click('#clicker')
        try:
            pg.wait_for_function("document.getElementById('clicks').textContent === 'Rexx counted 3 clicks.'", timeout=10000)
            check('app.rex handles the clicks', True)
        except Exception:
            check('app.rex handles the clicks', False, pg.locator('#clicks').inner_text())
        pg.click('#calc button')
        try:
            pg.wait_for_function("document.getElementById('result').textContent !== ''", timeout=10000)
        except Exception:
            pass
        check('JavaScript calls Evaluate: 2 ** 100', pg.locator('#result').inner_text() == '= 1267650600228229401496703205376',
              pg.locator('#result').inner_text())
        pg.fill('#expr', '1 +')
        pg.evaluate("document.getElementById('result').textContent = ''")
        pg.click('#calc button')
        try:
            pg.wait_for_function("document.getElementById('result').textContent !== ''", timeout=10000)
        except Exception:
            pass
        check('a Rexx error comes back as a RexxError', pg.locator('#result').inner_text().startswith('Error 35.1'),
              pg.locator('#result').inner_text())
        check('SAY goes to the console', any('The first script ran.' in t for t in console)
              and any('app.rex ran.' in t for t in console), console)
        check('no errors in the console', not errors, errors)
        b.close()
finally:
    srv.terminate()

print(f'== {len(fails)} failed' + (': ' + ', '.join(fails) if fails else ''))
sys.exit(1 if fails else 0)
