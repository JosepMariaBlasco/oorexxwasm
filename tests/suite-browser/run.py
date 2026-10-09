#!/usr/bin/env python3
"""Run the official ooRexx test suite inside the browser build, one test group
per run (a fresh interpreter in its own worker), driven by Playwright, and
collect the same CSV as tests/run-suite.sh:

    group,status,ran,assertions,failures,errors,seconds
    status: ok | fail | crash | timeout | noresult

Usage: run.py ENGINE BIN_WEB OUTDIR [--jobs 2] [--timeout 300] [--pattern RE]
  ENGINE  chromium | firefox | webkit (firefox/webkit from $PW_EXTRA,
          default $ORX_WASM_WORK/pw-browsers; chromium from the default path)
  BIN_WEB the web build (build-wasm/bin-web)
  OUTDIR  results.csv, logs/, www/ (page + test tree bundle), hangs.csv
          (group,attempt,stage: runs that produced no output within --start
          seconds, and with --retry-timeouts runs that timed out; retried)
Resumes: groups already in OUTDIR/results.csv are skipped.
Needs the suite checked out in $SUITE (default $ORX_WASM_WORK/oorexx-test).
"""
import argparse, asyncio, json, os, re, shutil, socket, subprocess, sys, time
ORX_WORK = os.environ.get('ORX_WASM_WORK') or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # where oorexx/, build-wasm/ ... live

ap = argparse.ArgumentParser()
ap.add_argument('engine'); ap.add_argument('bin'); ap.add_argument('out')
ap.add_argument('--jobs', type=int, default=2); ap.add_argument('--timeout', type=int, default=300)
ap.add_argument('--pattern', default='.')
ap.add_argument('--start', type=int, default=30, help='seconds without any output = the run did not start: retry')
ap.add_argument('--retries', type=int, default=2)
ap.add_argument('--retry-timeouts', action='store_true', help='also retry runs that time out (WebKit)')
a = ap.parse_args()
HERE = os.path.dirname(os.path.abspath(__file__))
SUITE = os.environ.get('SUITE', os.path.join(ORX_WORK, 'oorexx-test'))
OUT = os.path.abspath(a.out); WWW = OUT + '/www'
os.makedirs(OUT + '/logs', exist_ok=True); os.makedirs(WWW, exist_ok=True)
if a.engine != 'chromium':
    os.environ['PLAYWRIGHT_BROWSERS_PATH'] = os.environ.get('PW_EXTRA', os.path.join(ORX_WORK, 'pw-browsers'))

# the test tree as one bundle: suite.idx [[path, offset, length], ...] + suite.bin
idx, blobs, off = [], [], 0
for root, dirs, fs in os.walk(SUITE):
    dirs[:] = sorted(d for d in dirs if d != '.svn' and not (root == SUITE and d == 'doc'))
    for f in sorted(fs):
        p = os.path.join(root, f); b = open(p, 'rb').read()
        idx.append([os.path.relpath(p, SUITE), off, len(b)]); blobs.append(b); off += len(b)
open(WWW + '/suite.bin', 'wb').write(b''.join(blobs))
json.dump(idx, open(WWW + '/suite.idx', 'w'))
shutil.copy(HERE + '/page.html', WWW + '/page.html')
if os.path.lexists(WWW + '/bin'): os.remove(WWW + '/bin')
os.symlink(os.path.abspath(a.bin), WWW + '/bin')

groups = sorted(os.path.relpath(os.path.join(r, f), SUITE) for r, _, fs in os.walk(SUITE + '/ooRexx')
                for f in fs if f.endswith('.testGroup'))
groups = [g for g in groups if re.search(a.pattern, g)]
csv = OUT + '/results.csv'
done = set()
if os.path.exists(csv):
    done = {l.split(',')[0] for l in open(csv).read().splitlines()[1:]}
else:
    open(csv, 'w').write('group,status,ran,assertions,failures,errors,seconds\n')
todo = [g for g in groups if g not in done]
print(f'{a.engine}: {len(groups)} groups, {len(todo)} to run', flush=True)

s = socket.socket(); s.bind(('127.0.0.1', 0)); port = s.getsockname()[1]; s.close()
srv = subprocess.Popen([sys.executable, os.path.join(HERE, '..', 'jdor', 'serve.py'), str(port), WWW])
time.sleep(1)
URL = f'http://127.0.0.1:{port}/page.html'

def field(log, label):
    m = re.search(r'^' + label + r':?\s+(\d+)', log, re.M)
    return m.group(1) if m else ''

def classify(g, r):
    log = r.get('out', '') + r.get('err', '')
    if r.get('error'): log += '\n[runner] ' + r['error']
    ran = field(log, 'Tests ran'); asr = field(log, 'Assertions')
    fl = field(log, 'Failures'); er = field(log, 'Errors')
    if r.get('stopped'): st = 'timeout'
    elif not ran:
        st = 'crash' if re.search(r'RuntimeError|Aborted|worker|Segmentation|unreachable|out of memory|\[runner\]', log) else 'noresult'
    elif (fl or '0') == '0' and (er or '0') == '0': st = 'ok'
    else: st = 'fail'
    open(OUT + '/logs/' + g.replace('/', '_') + '.log', 'w').write(log)
    return f"{g},{st},{ran},{asr},{fl},{er},{round(r.get('ms', 0) / 1000)}"

async def main():
    from playwright.async_api import async_playwright
    q = asyncio.Queue()
    for g in todo: q.put_nowait(g)
    async with async_playwright() as p:
        b = await getattr(p, a.engine).launch()
        async def newpage():
            pg = await b.new_page()
            await pg.goto(URL); await pg.evaluate('window.ready')
            return pg
        async def worker():
            pg = await newpage()
            while not q.empty():
                g = q.get_nowait()
                d, n = os.path.dirname(g), os.path.basename(g)[:-len('.testGroup')]
                for attempt in range(a.retries + 1):
                    try:
                        r = await asyncio.wait_for(pg.evaluate('([d, n, t, s]) => runGroup(d, n, t, s)',
                                                               [d, n, a.timeout * 1000, a.start * 1000]), a.timeout + 60)
                    except Exception as e:      # the page itself died or hung: record, start a new one
                        r = {'error': 'page: ' + str(e).splitlines()[0], 'ms': 0}
                        try: await pg.close()
                        except Exception: pass
                        pg = await newpage()
                    hung = r.get('starthang') or (a.retry_timeouts and r.get('stopped'))
                    if not hung: break
                    lines = [l for l in (r.get('out', '') + r.get('err', '')).splitlines() if l.strip()]
                    stage = 'start' if r.get('starthang') else (lines[-1].strip()[:50] if lines else '(no output)')
                    with open(OUT + '/hangs.csv', 'a') as f: f.write(f'{g},{attempt + 1},{stage}\n')
                    print(f'{g}: hung at [{stage}] (attempt {attempt + 1})', flush=True)
                if r.get('starthang'): r['error'] = f'the run did not start ({a.retries + 1} attempts)'
                row = classify(g, r)
                with open(csv, 'a') as f: f.write(row + '\n')
                print(row, flush=True)
            await pg.close()
        await asyncio.gather(*[worker() for _ in range(a.jobs)])
        await b.close()
try:
    asyncio.run(main())
finally:
    srv.terminate()
rows = [l.split(',') for l in open(csv).read().splitlines()[1:]]
st = {}
for r in rows: st[r[1]] = st.get(r[1], 0) + 1
tot = lambda i: sum(int(r[i] or 0) for r in rows)
print(f'{a.engine}: groups {len(rows)}:', ' '.join(f'{k}={v}' for k, v in sorted(st.items())),
      f'| tests {tot(2)} failures {tot(4)} errors {tot(5)}')
