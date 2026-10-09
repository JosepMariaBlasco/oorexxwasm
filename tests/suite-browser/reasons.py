#!/usr/bin/env python3
"""reasons.py LOGDIR GROUP...: one line per failure/error of an ooTest log:
group test line: what (expected/actual or the error message)."""
import re, sys, os
d = sys.argv[1]
for g in sys.argv[2:]:
    p = os.path.join(d, g.replace('/', '_') + ('' if g.endswith('.log') else '.log'))
    t = open(p).read()
    for m in re.finditer(r'^\[(failure|error)\][^\n]*\n(.*?)(?=^\[|^File search:|\Z)', t, re.M | re.S):
        b = m.group(2)
        test = re.search(r'Test:\s+(\S+)', b); line = re.search(r'Line:\s+(\S+)', b)
        if m.group(1) == 'failure':
            exp = re.search(r'Expected:\s*(.*)', b); act = re.search(r'Actual:\s*(.*)', b)
            msg = re.search(r'Message:\s*(.*)', b)
            what = f"exp={exp.group(1)[:50] if exp else ''} act={act.group(1)[:50] if act else ''}" + (f" msg={msg.group(1)[:60]}" if msg else '')
        else:
            em = re.findall(r'^\s*(Error \d+.*|.*Error \d+\.\d+.*)$', b, re.M)
            what = ' | '.join(e.strip()[:90] for e in em[:2]) or b.strip().splitlines()[-1][:120]
        print(f"{g[:-10] if g.endswith('.testGroup') else g} {test.group(1) if test else '?'}:{line.group(1) if line else '?'} [{m.group(1)}] {what}")
