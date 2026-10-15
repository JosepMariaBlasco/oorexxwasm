/*----------------------------------------------------------------------------*/
/* ooRexx-debugger.js: a debugger for the Rexx scripts of a web page          */
/* (<script type="text/rexx">), for ooRexx/WASM.                               */
/*                                                                            */
/* Open the page with rexx-debug=1 in its address (page.html?rexx-debug=1):   */
/* ooRexx.js then loads this file from its own directory before it runs the   */
/* scripts (ooRexx.debugger: prepare, attach, instrument).  A panel at the    */
/* foot of the page shows the scripts; click a line number to set a           */
/* breakpoint (they are remembered for the page, so a reload stops in the     */
/* scripts' first run), and a breakpoint stops the scripts, or the handlers   */
/* they set up, when they get there.  Then Step (F10), Run (F8), the stack,   */
/* the variables, and Rexx run in the program's context.  Break stops at the  */
/* next clause that runs.                                                     */
/*                                                                            */
/* The debugger is Dom Wise's ooRexx debugger (debugger/RexxDebugger.rex,     */
/* https://sourceforge.net/p/oorexxdebugger/, MIT), with the front end of     */
/* debugger/RexxDebuggerWebUI.rex, which draws through window.orxDebugger     */
/* (below; its interface is described at the top of that file).  Each script */
/* runs with "::OPTIONS TRACE ?A" appended, which makes it, and the methods   */
/* and routines it defines, trace interactively into the debugger: they run   */
/* slower while debugging.  The program's output goes to the console, as      */
/* without the debugger; "say" typed in the panel shows there.  Standard      */
/* input is the debugger's: the panel sends it the user's actions.            */
/*                                                                            */
/* Copyright (c) 2026 Josep Maria Blasco.  MIT License, as RexxDebugger.rex.  */
/*----------------------------------------------------------------------------*/
(function () {
  'use strict';
  if (!window.ooRexx) { console.error('ooRexx-debugger.js: load ooRexx.js first'); return; }
  const here = (document.currentScript && document.currentScript.src) || '';
  const DIR = here.slice(0, here.lastIndexOf('/') + 1) + 'debugger/';
  const LIB = '/usr/lib/rexxdebugger/';
  const FILES = ['RexxDebugger.rex', 'RexxDebuggerWebUI.rex'];
  const INJECT = '/*REXX.DEBUGGER.INJECT*/ ::OPTIONS TRACE ?A';
  const KEY = 'ooRexx-debugger ' + location.origin + location.pathname;

  // ---- what is remembered for this page: breakpoints, the panel's size ----------------
  let saved = {};
  try { saved = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (e) { saved = {}; }
  const bps = new Set(Array.isArray(saved.bps) ? saved.bps : []);      // "NAME|LINE"
  let height = +saved.height || Math.round(window.innerHeight * 0.4);
  let collapsed = !!saved.collapsed;
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify({ bps: [...bps], height, collapsed })); } catch (e) { /* not kept */ }
  }

  // ---- the user's actions, for the front end's thread --------------------------------
  // One per line on the session's standard input (RexxDebuggerWebUI.rex, page mode):
  // the front end's thread waits there, never for JavaScript.  Before the session
  // starts they wait here (breakpoints need not: the front end asks for them).
  let session = null;
  const early = [];
  function send(action) {
    if (session) session.write(action + '\n'); else early.push(action);
  }

  // ---- the panel ---------------------------------------------------------------------
  const CSS = `
:host { all: initial; }
.panel { --bg: #f7f7f8; --fg: #1d1d1f; --mute: #6e6e73; --line: #d2d2d7; --cur: #fff3b0; --bp: #d70015;
  --btn: #fff; --hover: #ececf0; --sel: #e4e4ea; --err: #c4161c;
  position: fixed; left: 0; right: 0; bottom: 0; z-index: 2147483000; display: flex; flex-direction: column;
  background: var(--bg); color: var(--fg); border-top: 1px solid var(--line);
  font: 12px/1.45 ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif; box-shadow: 0 -2px 8px rgba(0,0,0,.08); }
@media (prefers-color-scheme: dark) {
  .panel { --bg: #1e1e20; --fg: #e8e8ea; --mute: #98989d; --line: #3a3a3c; --cur: #5a4a00; --bp: #ff453a;
    --btn: #2c2c2e; --hover: #3a3a3c; --sel: #343437; --err: #ff6961; }
}
.grip { height: 5px; margin-top: -3px; cursor: ns-resize; }
.bar { display: flex; align-items: center; gap: 6px; padding: 3px 8px 4px; border-bottom: 1px solid var(--line); flex: none; }
.title { font-weight: 600; margin-right: 6px; }
button { font: inherit; color: var(--fg); background: var(--btn); border: 1px solid var(--line); border-radius: 5px; padding: 1px 9px; cursor: pointer; }
button:hover:not(:disabled) { background: var(--hover); }
button:disabled { opacity: .45; cursor: default; }
.status { color: var(--mute); margin-left: 6px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.status.paused { color: var(--fg); font-weight: 600; }
.grow { flex: 1; }
.body { flex: 1; display: grid; grid-template-columns: minmax(0, 3fr) minmax(220px, 2fr); min-height: 0; }
.collapsed .body, .collapsed .grip { display: none; }
.code { display: flex; flex-direction: column; min-height: 0; border-right: 1px solid var(--line); }
.tabs { display: flex; gap: 2px; padding: 3px 6px 0; border-bottom: 1px solid var(--line); overflow-x: auto; flex: none; }
.tab { border: 1px solid transparent; border-bottom: none; border-radius: 5px 5px 0 0; padding: 2px 10px; cursor: pointer; color: var(--mute); white-space: nowrap; background: none; }
.tab.on { background: var(--btn); border-color: var(--line); color: var(--fg); margin-bottom: -1px; }
.tab.stopped::after { content: " \\25CF"; color: #c99a00; }
.view { flex: 1; overflow: auto; font: 12px/1.5 ui-monospace, "SF Mono", Menlo, Consolas, monospace; background: var(--btn); }
.src { display: none; padding: 4px 0; min-width: max-content; }
.src.on { display: block; }
.ln { display: flex; white-space: pre; }
.ln.cur { background: var(--cur); }
.n { flex: none; width: 4.5em; padding-right: 10px; text-align: right; color: var(--mute); cursor: pointer; user-select: none; position: relative; }
.n:hover { color: var(--fg); }
.ln.bp .n { color: #fff; }
.ln.bp .n::before { content: ""; position: absolute; inset: 1px 4px 1px 6px; background: var(--bp); border-radius: 3px 9px 9px 3px; z-index: -1; }
.n { z-index: 0; }
.t { padding-right: 16px; }
.side { display: flex; flex-direction: column; min-height: 0; }
.sec { display: flex; flex-direction: column; min-height: 0; border-bottom: 1px solid var(--line); }
.sec.stack { flex: 0 1 auto; max-height: 32%; }
.sec.vars { flex: 1 1 0; }
.sec.dbg { flex: 0 0 auto; height: 36%; border-bottom: none; }
.scroll { flex: 1; min-height: 0; overflow: auto; }
h3 { margin: 0; padding: 4px 8px; font-size: 11px; font-weight: 600; color: var(--mute); text-transform: uppercase; letter-spacing: .04em; flex: none; }
ol, table { margin: 0; font: 12px/1.45 ui-monospace, "SF Mono", Menlo, Consolas, monospace; }
ol { padding: 0 8px 4px 2.6em; }
li.cur { font-weight: 600; }
.vars { border-collapse: collapse; width: 100%; }
.vars td { padding: 1px 8px; vertical-align: top; border-bottom: 1px solid var(--line); word-break: break-all; }
.vars td:first-child { color: var(--mute); white-space: nowrap; word-break: normal; width: 1%; }
.empty { color: var(--mute); padding: 2px 8px 6px; font-style: italic; }
.out { margin: 0; padding: 2px 8px; white-space: pre-wrap; font: 12px/1.45 ui-monospace, "SF Mono", Menlo, Consolas, monospace; }
.out .e { color: var(--err); }
.exec { flex: none; margin: 4px 8px 6px; font: 12px ui-monospace, "SF Mono", Menlo, Consolas, monospace; padding: 3px 6px; color: var(--fg); background: var(--btn); border: 1px solid var(--line); border-radius: 5px; }
.exec:disabled { opacity: .5; }
`;
  let root, panel, statusEl, tabsEl, viewEl, stackEl, varsEl, outEl, execEl, btn = {};
  const sources = new Map();          // name -> {tab, pane, lines}
  let shown = null, stop = null, waiting = false, ended = false;

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }
  function build() {
    const host = el('div');
    host.id = 'ooRexx-debugger';
    root = host.attachShadow({ mode: 'open' });
    const style = el('style'); style.textContent = CSS; root.appendChild(style);
    panel = el('div', 'panel');
    const grip = el('div', 'grip');
    const bar = el('div', 'bar');
    bar.appendChild(el('span', 'title', 'ooRexx debugger'));
    for (const [k, label, title] of [['step', 'Step', 'Run the next clause (F10)'], ['run', 'Run', 'Run to the next breakpoint (F8)'],
      ['break', 'Break', 'Stop at the next clause that runs']]) {
      const b = el('button', '', label); b.title = title; b.addEventListener('click', () => act(k)); bar.appendChild(b); btn[k] = b;
    }
    statusEl = el('span', 'status'); bar.appendChild(statusEl);
    bar.appendChild(el('span', 'grow'));
    const fold = el('button', '', collapsed ? '▴' : '▾');
    fold.title = 'Hide or show the panel';
    fold.addEventListener('click', () => { collapsed = !collapsed; fold.textContent = collapsed ? '▴' : '▾'; layout(); save(); });
    bar.appendChild(fold);
    const body = el('div', 'body');
    const code = el('div', 'code');
    tabsEl = el('div', 'tabs'); viewEl = el('div', 'view');
    code.append(tabsEl, viewEl);
    const side = el('div', 'side');
    stackEl = el('ol'); varsEl = el('table', 'vars');
    outEl = el('pre', 'out');
    execEl = el('input', 'exec');
    execEl.placeholder = 'Rexx, run where the program is paused';
    execEl.spellcheck = false;
    execEl.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter' || !waiting) return;
      e.preventDefault();
      const t = execEl.value.trim();
      execEl.value = '';
      if (t === '') { act('step'); return; }
      write('> ' + t + '\n');
      // "say" here shows in the panel (the debugger's console), not in the page's
      const say = /^say(\s+(.*))?$/is.exec(t);
      send('exec ' + (say ? '.rexxdebugger.debugger~SendDebugMessage((' + (say[2] || "''") + ')~string)' : t));
    });
    const sec = (cls, title, ...content) => {
      const d = el('div', 'sec ' + cls), sc = el('div', 'scroll');
      sc.append(...content); d.append(el('h3', '', title), sc);
      return d;
    };
    const dbg = sec('dbg', 'Debugger', outEl);
    dbg.appendChild(execEl);
    side.append(sec('stack', 'Stack', stackEl), sec('vars', 'Variables', varsEl), dbg);
    body.append(code, side);
    panel.append(grip, bar, body);
    root.appendChild(panel);
    document.body.appendChild(host);
    grip.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      grip.setPointerCapture(e.pointerId);
      const move = (m) => { height = Math.max(120, Math.min(window.innerHeight - 40, window.innerHeight - m.clientY)); layout(); };
      const upf = () => { grip.removeEventListener('pointermove', move); grip.removeEventListener('pointerup', upf); save(); };
      grip.addEventListener('pointermove', move); grip.addEventListener('pointerup', upf);
    });
    window.addEventListener('keydown', (e) => {
      if (!waiting || (e.key !== 'F10' && e.key !== 'F8')) return;
      e.preventDefault();
      act(e.key === 'F10' ? 'step' : 'run');
    }, true);
    showVars(null); showStack([]);
    status('Loading the debugger…');
    layout(); controls();
  }
  function layout() {
    panel.classList.toggle('collapsed', collapsed);
    panel.style.height = collapsed ? '' : height + 'px';
    document.body.style.paddingBottom = (collapsed ? panel.offsetHeight : height) + 'px';
  }
  function controls() {
    btn.step.disabled = btn.run.disabled = !waiting;
    btn.break.disabled = waiting || ended;
    execEl.disabled = !waiting;
  }
  function status(text, paused) { statusEl.textContent = text; statusEl.classList.toggle('paused', !!paused); }
  function act(kind) {
    if (ended) return;
    if ((kind === 'step' || kind === 'run') && !waiting) return;
    if (kind === 'break') status('Break: stops at the next clause that runs', true);
    send(kind);
  }
  function write(text, cls) {
    const s = el('span', cls, text);
    outEl.appendChild(s);
    outEl.parentNode.scrollTop = outEl.parentNode.scrollHeight;
  }

  // ---- sources and breakpoints -------------------------------------------------------
  function shortName(name) { return name.split('/').pop() || name; }
  function addSource(name, lines) {
    if (sources.has(name)) return sources.get(name);
    const tab = el('button', 'tab', shortName(name));
    tab.title = name;
    tab.addEventListener('click', () => show(name));
    const pane = el('div', 'src');
    lines.forEach((text, i) => {
      if (text.startsWith('/*REXX.DEBUGGER.INJECT*/')) return;
      const n = i + 1, row = el('div', 'ln'), num = el('span', 'n', String(n));
      row.dataset.line = n;
      if (bps.has(name + '|' + n)) row.classList.add('bp');
      num.addEventListener('click', () => toggle(name, n, row));
      row.append(num, el('span', 't', text === '' ? ' ' : text));
      pane.appendChild(row);
    });
    tabsEl.appendChild(tab); viewEl.appendChild(pane);
    const s = { tab, pane, lines };
    sources.set(name, s);
    if (!shown) show(name);
    return s;
  }
  function show(name) {
    const s = sources.get(name);
    if (!s) return;
    if (shown) { shown.tab.classList.remove('on'); shown.pane.classList.remove('on'); }
    s.tab.classList.add('on'); s.pane.classList.add('on');
    shown = s;
  }
  function toggle(name, line, row) {
    const k = name + '|' + line, on = !bps.has(k);
    if (on) bps.add(k); else bps.delete(k);
    row.classList.toggle('bp', on);
    save();
    send('bp ' + k + (on ? ' on' : ' off'));
  }
  function showStack(frames, index) {
    stackEl.textContent = '';
    if (!frames.length) { stackEl.appendChild(el('li', 'empty', 'Not paused')); return; }
    frames.forEach((t, i) => { const li = el('li', i + 1 === index ? 'cur' : '', t); stackEl.appendChild(li); });
  }
  function showVars(rows) {
    varsEl.textContent = '';
    if (!rows) { const r = varsEl.insertRow(), c = r.insertCell(); c.className = 'empty'; c.textContent = 'Not paused'; return; }
    for (const [k, v] of rows) { const r = varsEl.insertRow(); r.insertCell().textContent = k; r.insertCell().textContent = v; }
  }

  // ---- what RexxDebuggerWebUI.rex calls (page mode) ----------------------------------
  window.orxDebugger = {
    mode: 'page',
    begin() { status('Running — click a line number to set a breakpoint'); },
    next() { return new Promise(() => {}); },        // program mode only
    wake() { },
    setSource(name, lines) { addSource(String(name), Array.from(lines || [], String)); },
    getBreakpoints() { return [...bps]; },
    stopAt(name, line, stack, index) {
      name = String(name); line = +line;
      for (const r of root.querySelectorAll('.ln.cur')) r.classList.remove('cur');
      for (const t of root.querySelectorAll('.tab.stopped')) t.classList.remove('stopped');
      stop = { name, line };
      const s = sources.get(name);
      if (s) {
        show(name);
        s.tab.classList.add('stopped');
        const row = s.pane.querySelector('[data-line="' + line + '"]');
        if (row) { row.classList.add('cur'); row.scrollIntoView({ block: 'nearest' }); }
      }
      showStack(Array.from(stack || [], String), +index);
    },
    setVars(rows) { showVars(Array.from(rows || [], (r) => [String(r[0]), String(r[1])])); },
    setWaiting(w) {
      waiting = w === true || w === '1';
      if (waiting && stop) status('Paused after line ' + stop.line + ' of ' + shortName(stop.name), true);
      else if (!waiting) {
        status('Running');
        for (const r of root.querySelectorAll('.ln.cur')) r.classList.remove('cur');
        for (const t of root.querySelectorAll('.tab.stopped')) t.classList.remove('stopped');
        showStack([]); showVars(null);
      }
      controls();
      if (waiting) execEl.focus({ preventScroll: true });
    },
    write(text, nl) {
      const t = String(text) + (nl === true || nl === '1' ? '\n' : '');
      write(t.replace(/^<-> /, ''), /^(<-> )?(\+\+\+|Error)/.test(t) ? 'e' : '');
    },
    clearConsole() { outEl.textContent = ''; },
    end() { ended = true; waiting = false; status('The debugger has ended'); controls(); },
  };

  // ---- what ooRexx.js calls (ooRexx.debugger) ----------------------------------------
  ooRexx.debugger = {
    async prepare(options) {
      build();
      const files = {};
      await Promise.all(FILES.map(async (n) => {
        const r = await fetch(DIR + n);
        if (!r.ok) throw new Error(DIR + n + ': HTTP ' + r.status);
        files[LIB + n] = new Uint8Array(await r.arrayBuffer());
      }));
      options.files = Object.assign({}, options.files, files);
      // standard input is the debugger's: no "REXXin?>" when its thread waits there
      options.prefixes = Object.assign({}, typeof options.prefixes === 'object' ? options.prefixes : {}, { input: null });
    },
    async attach(s) {
      // the program's output where it goes without the debugger (NOCAPTURE)
      await s.eval('.local~rexxdebugger.captureoption = "NOCAPTURE"; call "' + LIB + 'RexxDebugger.rex"');
      session = s;
      for (const a of early.splice(0)) send(a);
    },
    instrument(name, source) {
      addSource(name, source.split(/\r?\n/));
      return source + '\n' + INJECT;
    },
  };
})();
