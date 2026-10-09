#!/usr/bin/env python3
"""Adapt Rony's JDOR samples (BSF4ooRexx850) to the JDOR environment of the
ooRexx/WASM browser build: no BSF, no Java.

  .bsf~new("org.oorexx.handlers.jdor.JavaDrawingHandler") + BsfCommandHandler
      -> nothing: ::requires "jdor.cls" sets up the JDOR environment
         (the program still selects it, ADDRESS JDOR, as before)
         (a second environment, e.g. SDOR: call addJdorHandler "SDOR")
  bsf.importClass(...)~version, handler~version  -> jdorVersion()
  bsf.createJavaArrayOf("int.class", ...)        -> .array~of(...)
  ::requires "BSF.CLS"                           -> ::requires "jdor.cls"
  .java.lang.System~getProperty("user.home")     -> value("HOME", , "ENVIRONMENT")
  pp(value)                                      -> a routine pp at the end
  ADDRESS SYSTEM "xdg-open" of the saved bitmap  -> shown in a JDOR window

Everything else is left as Rony wrote it.  Each adapted file gets a first
line (after any #! line) saying so (Apache License 2.0, 4b).  Idempotent.
Usage: adapt-bsf4oorexx-samples.py FILE.rxj...
"""
import re
import sys

MARK = '-- Adapted for ooRexx/WASM: JDOR without BSF4ooRexx or Java (see NOTICE)\n'
PP = '::routine pp       -- as in BSF4ooRexx: the value in brackets\n  return "[" || arg(1)~string || "]"\n'
SHOW = """   -- show the bitmap just created: no operating system here to open it with,
   -- so a second JDOR environment loads the saved file into a window of its own
call addJdorHandler "SHOW"           -- set up a second JDOR environment, SHOW
address show "loadImage bitmap" fileName  -- RC: width height
parse var rc w h
address show "newImage" w h
address show "drawImage bitmap"
address show "winTitle" fileName
address show "winShow"
"""
HANDLER = r'\.bsf~new\("org\.oorexx\.handlers\.jdor\.JavaDrawingHandler"\)'


def adapt(s):
    if MARK in s.split('\n', 2)[0] + '\n' + s.split('\n', 2)[1] + '\n':
        return s
    vers = {}                                   # handler variable -> its version source
    # the handler class (bsf.importClass) and its instance
    for m in re.finditer(r'(?m)^(\w+)=bsf\.importClass\("org\.oorexx\.handlers\.jdor\.JavaDrawingHandler"\)\n', s):
        vers[m.group(1)] = True
    s = re.sub(r'(?m)^\w+=bsf\.importClass\("org\.oorexx\.handlers\.jdor\.JavaDrawingHandler"\)\n', '', s)
    for v in list(vers):
        for m in re.finditer(r'(?m)^(\w+)=' + v + r'~new\n', s):
            vers[m.group(1)] = True
        s = re.sub(r'(?m)^\w+=' + v + r'~new\n', '', s)
    s = re.sub(r'(?m)^[ \t]*-- create JDOR handler\n(?=\w+=' + HANDLER + ')', '', s)
    for m in re.finditer(r'(?m)^(\w+)=' + HANDLER, s):
        vers[m.group(1)] = True
    s = re.sub(r'(?m)^\w+=' + HANDLER + r'.*\n', '', s)
    s = re.sub(r'(?m)^[ \t]*-- define "JDOR" address environment serviced by our JDOR handler\n', '', s)
    for v in vers:
        s = re.sub(r'\b' + v + r'~version\b', 'jdorVersion()', s)

    def env(m):
        name = m.group(1)
        if name.upper() == 'JDOR':
            return ''           # set up by ::requires "jdor.cls"; ADDRESS JDOR selects it
        return 'call addJdorHandler "' + name.upper() + '"   -- set up a second JDOR environment, ' + name.upper() + '\n'
    s = re.sub(r'(?m)^call BsfCommandHandler "add", "(\w+)", \w+.*\n', env, s)
    s = re.sub(r'bsf\.createJavaArrayOf\("\w+\.class", *', '.array~of(', s)
    s = s.replace('.java.lang.System~getProperty("user.home")', 'value("HOME", , "ENVIRONMENT")')
    s = re.sub(r'(?ms)^[ \t]*-- create the operating system dependent command to load and show the just created bitmap\n'
               r'.*?^address system cmd[^\n]*\n', SHOW, s)
    s = re.sub(r'(?mi)^::requires +"?bsf\.cls"?.*$', '::requires "jdor.cls"   -- set up the JDOR environment', s)
    if re.search(r'\bpp\(', s):                # BSF4ooRexx's pp(): the value in brackets
        s = s.rstrip('\n') + '\n\n' + PP
    left = [l for l in s.splitlines() if re.search(r'\.bsf\b|\bbsf\.|bsfcommandhandler|"bsf\.cls"|\.java\.|^\s*address\s+system\b', l, re.I)
            and not l.lstrip().startswith('--')]
    if left:
        raise SystemExit('BSF or an OS command left over:\n' + '\n'.join(left))
    if s.startswith('#!'):                       # after the interpreter line
        nl = s.index('\n') + 1
        return s[:nl] + MARK + s[nl:]
    return MARK + s


for path in sys.argv[1:]:
    with open(path, encoding='utf-8') as f:
        s = f.read()
    t = adapt(s)
    if t != s:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(t)
        print('adapted', path)
