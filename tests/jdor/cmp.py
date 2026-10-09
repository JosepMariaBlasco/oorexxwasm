#!/usr/bin/env python3
"""cmp.py CMDFILE [CMDFILE...]: run JDOR command files through Rony's Java handler
(headless harness) and through ours in the browser; compare results and images."""
import sys, os, subprocess, re, shutil
from PIL import Image, ImageChops, ImageDraw
ORX_WORK = os.environ.get('ORX_WASM_WORK') or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # where oorexx/, build-wasm/ ... live
HERE=os.path.dirname(os.path.abspath(__file__))
W=os.environ.get('WORK',os.path.join(ORX_WORK, 'jdor-work'))       # see compare.sh
T=HERE; J=W+'/java'; S=W+'/samples'; R=W+'/cmp'
os.makedirs(R, exist_ok=True)
# Objects and errors are described differently on purpose (ours say they are
# JDOR objects of the browser build, not Java's): both sides are brought to one
# form, "<Kind ...>", keeping what both describe (colour, font, image size and
# type, transform matrix, rectangle bounds) and the error messages proper.
JAVA_KINDS={'BasicStroke':'Stroke','GradientPaint':'Gradient','AlphaComposite':'Composite'}
NFE=re.compile(r'java\.lang\.NumberFormatException: (?:For input string: (".*?")|empty String)')
def objs_java(l):
    l=re.sub(r'java\.awt\.Color\[(r=\d+,g=\d+,b=\d+)\]',r'<Color \1>',l)
    l=re.sub(r'java\.awt\.Font\[([^\]]*)\]',r'<Font \1>',l)
    l=re.sub(r'java\.awt\.(BasicStroke|GradientPaint|AlphaComposite)@[0-9a-f]+',lambda m:'<'+JAVA_KINDS[m.group(1)]+'>',l)
    l=re.sub(r'AffineTransform(\[\[[^\]]*\], \[[^\]]*\]\])',r'<Transform \1>',l)
    l=re.sub(r'BufferedImage@[0-9a-f]+: type = (\d+) .*?width = (\d+) height = (\d+) .*?dataOffset\[0\] \d+',r'<Image \2x\3 type \1>',l)
    l=re.sub(r'sun\.java2d\.SunGraphics2D\[[^\]]*\]\]?','<Graphics>',l)
    l=re.sub(r'java\.awt\.geom\.Rectangle2D\$Double\[(x=[^\]]*)\]',r'<Shape Rectangle \1>',l)
    l=re.sub(r'java\.awt\.geom\.(?:Path2D\$Iterator|PathIterator)@[0-9a-f]+','<PathIterator>',l)
    l=re.sub(r'java\.awt\.(?:geom\.)?(\w+?)(?:2D)?(?:\$Double|\$Float)?@[0-9a-f]+',r'<Shape \1>',l)
    l=re.sub(r'org\.rexxla\.bsf\.engines\.rexx\.RexxProxy@[0-9a-f]+','<a Rexx object>',l)   # getState: a StringTable
    l=NFE.sub(lambda m:'not a number: '+(m.group(1) or '""'),l)
    l=re.sub(r'(?:java|javax)\.[\w.$]+(?:Exception|Error): ','',l)
    return l
def objs_web(l):
    l=re.sub(r'JDOR Color #\d+: (r=\d+,g=\d+,b=\d+),a=\d+',r'<Color \1>',l)
    l=re.sub(r'JDOR Font #\d+: ([^\]\n]*?size=\d+)',r'<Font \1>',l)
    l=re.sub(r'JDOR (Stroke|Gradient|Composite|Graphics|PathIterator) #\d+(?:: .*?(?=\]|$))?',r'<\1>',l)
    l=re.sub(r'JDOR Transform #\d+: (\[\[[^\]]*\], \[[^\]]*\]\])',r'<Transform \1>',l)
    l=re.sub(r'JDOR Image #\d+: (\d+x\d+), type (\d+) \([A-Z_]+\), an OffscreenCanvas',r'<Image \1 type \2>',l)
    l=re.sub(r'JDOR Shape #\d+: Rectangle(?:2D)? (x=[^ \]]*)',r'<Shape Rectangle \1>',l)
    l=re.sub(r'JDOR Shape #\d+: (\w+?)(?:2D)? x=[^ \]]*',r'<Shape \1>',l)
    l=l.replace('JDOR (web): ','')
    l=re.sub(r'-> a StringTable$','-> <a Rexx object>',l)
    return l
def norm(lines, web=False):
    r=[]
    for l in lines:
        l=objs_web(l) if web else objs_java(l)
        l=re.sub(r'line # \S+ in \S+ \[[^\]]*\]','line # . in . [.]',l)
        l=re.sub(r'@[0-9a-f]+','@#',l); l=re.sub(r'-> null$','-> 0',l)
        r.append(l.rstrip())
    return r
for cf in sys.argv[1:]:
    name=os.path.splitext(os.path.basename(cf))[0]
    out=R+'/'+name
    os.makedirs(out, exist_ok=True)
    cmds=[l.rstrip('\n') for l in open(cf)]
    cmds=[l for l in cmds if not l.lower().startswith('saveimage')]+['saveImage '+name+'.png']
    open(out+'/cmds.txt','w').write('\n'.join(cmds)+'\n')
    # Java
    shutil.copy(out+'/cmds.txt', S+'/'+name+'.cmds')
    j=subprocess.run(['java','-cp',J+'/classes','org.rexxla.bsf.engines.rexx.Harness',name+'.cmds','-o','-v'],cwd=S,capture_output=True,text=True)
    jl=[l for l in j.stdout.splitlines()]
    if os.path.exists(S+'/'+name+'.png'): shutil.move(S+'/'+name+'.png', out+'/java.png')
    # browser
    env=dict(os.environ, OUTDIR=out+'/b', NOERR='1')
    pngs=[S+'/'+f for f in os.listdir(S) if f.endswith('_256.png')]
    b=subprocess.run(['python3',T+'/run.py','chromium',T+'/driver.rex',out+'/cmds.txt']+pngs+['--arg','cmds.txt'],capture_output=True,text=True,env=env,cwd=W)
    bl=[l for l in b.stdout.splitlines() if l.startswith(('[','E:','O:'))]
    if os.path.exists(out+'/b/'+name+'.png'): shutil.move(out+'/b/'+name+'.png', out+'/browser.png')
    jn,bn=norm(jl),norm(bl,web=True)
    open(out+'/java.txt','w').write('\n'.join(jn)+'\n'); open(out+'/browser.txt','w').write('\n'.join(bn)+'\n')
    d=subprocess.run(['diff',out+'/java.txt',out+'/browser.txt'],capture_output=True,text=True).stdout
    nd=sum(1 for l in d.splitlines() if l[:1] in '<>')
    msg=f'{name}: {len(jn)} lines, {nd} differing'
    if os.path.exists(out+'/java.png') and os.path.exists(out+'/browser.png'):
        a=Image.open(out+'/java.png').convert('RGBA'); c=Image.open(out+'/browser.png').convert('RGBA')
        if a.size==c.size:
            diff=ImageChops.difference(a,c); px=sum(1 for p in diff.get_flattened_data() if max(p)>64)
            msg+=f'; image {a.size}: {px} pixels differ by >64 ({100*px/(a.size[0]*a.size[1]):.2f}%)'
            bg=Image.new('RGBA',a.size,(238,238,238,255))
            sheet=Image.new('RGB',(a.size[0]*3+20,a.size[1]+20),'white'); dr=ImageDraw.Draw(sheet)
            sheet.paste(Image.alpha_composite(bg,a).convert('RGB'),(0,20)); sheet.paste(Image.alpha_composite(bg,c).convert('RGB'),(a.size[0]+10,20))
            dd=diff.convert('RGB').point(lambda v: 255 if v>64 else 0); sheet.paste(dd,(2*a.size[0]+20,20))
            dr.text((2,2),'Java (Rony)',fill='black'); dr.text((a.size[0]+12,2),'browser',fill='black'); dr.text((2*a.size[0]+22,2),'difference',fill='black')
            sheet.save(out+'/side.png')
        else: msg+=f'; image sizes differ {a.size} {c.size}'
    else: msg+='; missing image'
    print(msg)
    if nd: print(d[:3000])
