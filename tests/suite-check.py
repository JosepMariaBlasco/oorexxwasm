#!/usr/bin/env python3
"""suite-check.py BASELINE.csv RESULTS.csv [--known known.tsv] [--md out.md]

Compares a run of the official test suite (CSV of tests/run-suite.sh or
tests/suite-browser/run.py) with a reference run of the same platform
(results/suite-*-rREV-series.csv) and exits 1 if anything got worse:

  regression   a group that passed now does not, or a group that failed now
               has more failures + errors, or now crashes / times out
  missing      a group of the reference that did not run (a crash of the
               runner, a pattern that is too narrow is fine: see --pattern)

Groups whose category in known.tsv includes "flaky" (intermittent) or
"stack" (the recursion depth depends on the engine build) are reported but
never fail the check.  Improvements and new groups are reported too.

  --pattern RE  only compare groups matching RE (the run used a pattern)
"""
import csv, os, re, sys

args = sys.argv[1:]
known_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'suite-browser', 'known.tsv')
md_out, pattern, pos = None, '.', []
i = 0
while i < len(args):
    if args[i] == '--known': known_path = args[i + 1]; i += 2; continue
    if args[i] == '--md': md_out = args[i + 1]; i += 2; continue
    if args[i] == '--pattern': pattern = args[i + 1]; i += 2; continue
    pos.append(args[i]); i += 1
if len(pos) != 2:
    sys.exit(__doc__)

def load(p):
    return {r['group']: r for r in csv.DictReader(open(p)) if re.search(pattern, r['group'])}

base, new = load(pos[0]), load(pos[1])
flaky = set()
for line in open(known_path):
    if line.startswith('#') or not line.strip(): continue
    cat, grp, _ = line.rstrip('\n').split('\t')
    if 'flaky' in cat or 'stack' in cat: flaky.add('ooRexx/' + grp + '.testGroup')

SEVERITY = {'ok': 0, 'fail': 1, 'noresult': 2, 'crash': 2, 'timeout': 2}
def bad(r): return int(r['failures'] or 0) + int(r['errors'] or 0)
def cell(r):
    if r is None: return '—'
    if r['status'] == 'fail': return f"fail {r['failures'] or 0}/{r['errors'] or 0}"
    return r['status']

worse, better, missing, added = [], [], [], []
for g in sorted(set(base) | set(new)):
    b, n = base.get(g), new.get(g)
    if n is None: missing.append(g); continue
    if b is None: added.append(g); continue
    sb, sn = SEVERITY.get(b['status'], 2), SEVERITY.get(n['status'], 2)
    if sn > sb or (sn == sb == 1 and bad(n) > bad(b)): worse.append(g)
    elif sn < sb or (sn == sb == 1 and bad(n) < bad(b)): better.append(g)

def short(g): return g[len('ooRexx/'):-len('.testGroup')] if g.startswith('ooRexx/') else g
fatal = [g for g in worse if g not in flaky]
out = []
def summary(rows):
    c = lambda s: sum(1 for r in rows.values() if r['status'] == s)
    return f"{len(rows)} groups, {c('ok')} ok, {c('fail')} fail, {c('crash') + c('noresult')} crash, {c('timeout')} timeout"
out.append(f"Reference: {summary(base)}  ")
out.append(f"This run:  {summary(new)}")
out.append('')
if worse or better:
    out.append('| group | reference | this run | |')
    out.append('|---|---|---|---|')
    for g in worse:
        out.append(f"| {short(g)} | {cell(base[g])} | {cell(new[g])} | {'worse (flaky/stack, ignored)' if g in flaky else '**worse**'} |")
    for g in better:
        out.append(f"| {short(g)} | {cell(base[g])} | {cell(new[g])} | better |")
    out.append('')
if missing: out.append('**Did not run:** ' + ', '.join(short(g) for g in missing))
if added: out.append('New groups (not in the reference): ' + ', '.join(f"{short(g)} ({cell(new[g])})" for g in added))
ok = not fatal and not missing
out.append('')
out.append('**Result: no regressions.**' if ok else
           f"**Result: {len(fatal)} regression(s), {len(missing)} group(s) missing.**")
text = '\n'.join(out) + '\n'
if md_out: open(md_out, 'w').write(text)
print(text)
sys.exit(0 if ok else 1)
