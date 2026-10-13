// oorexxwasm: run a tool of ooRexx/WASM (lib/rexx.js, one multi-call
// WebAssembly module) with Node, as the shell launchers of
// wasm/build-node.sh do: lib/ first in PATH (REXX_PATH on Windows), so that
// the interpreter finds the extension classes, and the arguments passed on.
'use strict';
const path = require('node:path');
const { spawn } = require('node:child_process');

module.exports = function launch(toolFlag) {
  const lib = path.join(__dirname, '..', 'lib');
  const env = Object.assign({}, process.env);
  // Windows: lib/ goes into REXX_PATH, not PATH: cmd.exe would take
  // lib/rexx.js for the command "rexx" (.JS is in PATHEXT, Windows Script
  // Host).  The interpreter finds rexx.img next to rexx.js by itself, and
  // the classes through REXX_PATH
  const name = process.platform === 'win32' ? 'REXX_PATH' : 'PATH';
  const key = Object.keys(env).find((k) => k.toUpperCase() === name) || name;
  env[key] = lib + path.delimiter + (env[key] || '');
  const args = [path.join(lib, 'rexx.js')];
  if (toolFlag) args.push(toolFlag);
  args.push(...process.argv.slice(2));
  const child = spawn(process.execPath, args, { stdio: 'inherit', env });
  // Ctrl-C reaches both processes from the terminal: the interpreter decides;
  // a termination sent to this process alone is passed on
  try { process.on('SIGINT', () => {}); } catch (e) { /* not on this platform */ }
  for (const sig of ['SIGTERM', 'SIGHUP']) {
    try { process.on(sig, () => child.kill(sig)); } catch (e) { /* not on this platform */ }
  }
  child.on('error', (e) => { console.error('oorexxwasm: ' + e.message); process.exit(127); });
  child.on('exit', (code, signal) => {
    if (signal) { process.removeAllListeners(signal); process.kill(process.pid, signal); }
    else process.exit(code === null ? 1 : code);
  });
};
