#!/usr/bin/env python3
"""compare.py NAME=results.csv ... [--known known.tsv] [--md out.md] [--csv out.csv]

Puts suite results of several platforms side by side (CSV format of
run-suite.sh / suite-browser/run.py): a summary per platform, and every group
that does not pass everywhere, with its category from known.tsv.  Browser
groups that fail without a known reason are listed as UNEXPLAINED.
"""
import csv, sys, os

args = sys.argv[1:]
known_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'known.tsv')
md_out = csv_out = None
plats = []
i = 0
while i < len(args):
    if args[i] == '--known': known_path = args[i + 1]; i += 2; continue
    if args[i] == '--md': md_out = args[i + 1]; i += 2; continue
    if args[i] == '--csv': csv_out = args[i + 1]; i += 2; continue
    name, path = args[i].split('=', 1); plats.append((name, path)); i += 1

data = {n: {r['group']: r for r in csv.DictReader(open(p))} for n, p in plats}
known = {}
for line in open(known_path):
    if line.startswith('#') or not line.strip(): continue
    cat, grp, note = line.rstrip('\n').split('\t')
    known['ooRexx/' + grp + '.testGroup'] = (cat, note)
names = [n for n, _ in plats]
browsers = [n for n in names if n in ('chromium', 'firefox', 'webkit')]
groups = sorted(set().union(*[set(d) for d in data.values()]))

out = []
out.append('| platform | groups | ok | fail | crash | timeout | tests ran | assertions | failures | errors |')
out.append('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
for n in names:
    rows = data[n].values()
    c = lambda s: sum(1 for r in rows if r['status'] == s)
    t = lambda k: sum(int(r[k] or 0) for r in rows)
    out.append(f"| {n} | {len(rows)} | {c('ok')} | {c('fail')} | {c('crash') + c('noresult')} | {c('timeout')} | "
               f"{t('ran')} | {t('assertions')} | {t('failures')} | {t('errors')} |")
out.append('')

def cell(r):
    if r is None: return '—'
    if r['status'] == 'ok': return 'ok'
    if r['status'] == 'fail': return f"fail {r['failures'] or 0}/{r['errors'] or 0}"
    return r['status']

bad = [g for g in groups if any(data[n].get(g, {}).get('status') not in ('ok', None) for n in names)]
out.append('| group | ' + ' | '.join(names) + ' | category | why |')
out.append('|---|' + '---|' * len(names) + '---|---|')
unexplained = []
rows_csv = []
for g in bad:
    cat, note = known.get(g, ('', ''))
    if not cat and any(data[n].get(g, {}).get('status') not in ('ok', None) for n in browsers):
        cat = 'UNEXPLAINED'; unexplained.append(g)
    cells = [cell(data[n].get(g)) for n in names]
    out.append(f"| {g[len('ooRexx/'):-len('.testGroup')]} | " + ' | '.join(cells) + f" | {cat} | {note} |")
    rows_csv.append([g] + cells + [cat, note])
out.append('')
cats = {}
for g in bad:
    if any(data[n].get(g, {}).get('status') not in ('ok', None) for n in browsers):
        c = known.get(g, ('UNEXPLAINED',))[0]; cats[c] = cats.get(c, 0) + 1
out.append('Browser groups not passing, by category: ' + ', '.join(f'{k} {v}' for k, v in sorted(cats.items(), key=lambda x: -x[1])))
if unexplained: out.append('UNEXPLAINED: ' + ', '.join(unexplained))
text = '\n'.join(out) + '\n'
if md_out: open(md_out, 'w').write(text)
if csv_out:
    with open(csv_out, 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['group'] + names + ['category', 'why']); w.writerows(rows_csv)
print(text)
