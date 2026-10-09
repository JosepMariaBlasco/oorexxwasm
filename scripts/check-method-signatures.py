#!/usr/bin/env python3
"""Find native methods registered in interpreter/memory/Setup.cpp whose C++
declaration does not match the signature CPPCode::run calls them with.

WebAssembly traps on an indirect call whose function type differs from the
call site ("null function or function signature mismatch"); x86 tolerates it.
CPPCode::run calls every method as  RexxObject *(T::*)(RexxObject *...)  with
N arguments, or  RexxObject *(T::*)(RexxObject **, size_t)  for A_COUNT.
So the declaration must return a pointer and take exactly N pointer args.

Usage: check-method-signatures.py [OOREXX_DIR]
"""
import re, sys, os, glob
ORX_WORK = os.environ.get('ORX_WASM_WORK') or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../..'))  # where oorexx/, build-wasm/ ... live
root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ORX_WORK, 'oorexx')
setup = open(os.path.join(root, 'interpreter/memory/Setup.cpp')).read()
regs = re.findall(r'Add(?:Class)?(?:Protected|Private)?Method\("([^"]*)",\s*([A-Za-z_]\w*)::(\w+),\s*([A-Z_0-9]+)', setup)
hdrs = {}
for h in glob.glob(os.path.join(root, 'interpreter/**/*.hpp'), recursive=True):
    hdrs[h] = open(h, errors='replace').read()
def decls(cls, meth):
    out = []
    for h, txt in hdrs.items():
        m = re.search(r'class\s+' + cls + r'\b[^;{]*\{', txt)
        if not m: continue
        body = txt[m.end():]
        for d in re.finditer(r'^\s*(?:static\s+|virtual\s+|inline\s+)*([\w:<>\s\*&]+?)\s*\b' + meth + r'\s*\(([^)]*)\)', body, re.M):
            out.append((d.group(1).strip(), d.group(2).strip(), os.path.relpath(h, root)))
    return out
bad = 0
for name, cls, meth, argc in regs:
    ds = decls(cls, meth)
    if not ds:
        continue
    for ret, args, h in ds:
        nargs = 0 if args in ('', 'void') else len([a for a in args.split(',')])
        retok = ret.endswith('*')
        if argc == 'A_COUNT':
            argok = nargs == 2
        else:
            try: argok = nargs == int(argc)
            except ValueError: argok = True
        ptrargs = argc == 'A_COUNT' or all(('*' in a) for a in args.split(',')) if nargs else True
        if not (retok and argok and ptrargs):
            bad += 1
            print(f'{cls}::{meth} ("{name}", {argc}): {ret} ({args})  [{h}]')
print(f'-- {len(regs)} registrations checked, {bad} suspicious', file=sys.stderr)
