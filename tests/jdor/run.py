import asyncio, sys, json, os, base64
from playwright.async_api import async_playwright
ORX_WORK = os.environ.get('ORX_WASM_WORK') or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))  # where oorexx/, build-wasm/ ... live
# usage: run.py ENGINE PROGRAM.rex [extra files...] [--shot out.png] [--w W --h H]
async def main():
    a=sys.argv[1:]; engine=a.pop(0)
    if engine!='chromium' and os.path.isdir(os.environ.get('PW_EXTRA',os.path.join(ORX_WORK, 'pw-browsers'))):
        os.environ['PLAYWRIGHT_BROWSERS_PATH']=os.environ.get('PW_EXTRA',os.path.join(ORX_WORK, 'pw-browsers'))
    shot=None; W,H=1100,800
    if '--shot' in a: i=a.index('--shot'); shot=a[i+1]; del a[i:i+2]
    parg=''
    if '--arg' in a: i=a.index('--arg'); parg=a[i+1]; del a[i:i+2]
    prog=a.pop(0); files={}
    base=os.path.dirname(os.path.abspath(prog))
    for f in [prog]+a:
        files['/home/rexx/'+os.path.basename(f)]=list(open(f,'rb').read())
    async with async_playwright() as p:
        kw={'executable_path':os.environ['CHROMIUM']} if engine=='chromium' and os.environ.get('CHROMIUM') else {}
        b=await getattr(p,engine).launch(**kw)
        pg=await b.new_page(viewport={'width':W,'height':H})
        pg.on('console',lambda m: print('console:',m.text) if m.type in('error','warning') else None)
        pg.on('pageerror',lambda e: print('pageerror:',e))
        await pg.goto(os.environ.get('PAGE','http://127.0.0.1:8124/page.html'))
        res=await pg.evaluate("""async (f)=>{const files={};for(const[k,v] of Object.entries(f))files[k]=new Uint8Array(v);
           return await runRexx(files,[Object.keys(f)[0].split('/').pop()].concat(PARG?[PARG]:[]),{width:%d,height:%d});}""".replace('PARG',json.dumps(parg))%(W,H), files)
        await asyncio.sleep(0.3)
        print('rc=',res['rc'],'error=',res.get('error'))
        print(res['out'],end=''); 
        if res['err'] and not os.environ.get('NOERR'): print('--- stderr ---'); print(res['err'],end='')
        if shot: await pg.screenshot(path=shot)
        od=os.environ.get('OUTDIR')
        if od:
            os.makedirs(od,exist_ok=True)
            for k,v in (res.get('files') or {}).items():
                if k.endswith('.png'): open(os.path.join(od,os.path.basename(k)),'wb').write(bytes(v))
        await b.close()
asyncio.run(main())
