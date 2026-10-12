// oorexxwasm: run a tool of ooRexx/WASM (lib/rexx.js, one multi-call
// WebAssembly module) with Node, as the shell launchers of
// wasm/build-node.sh do: lib/ first in PATH, so that the interpreter finds
// rexx.img and the extension classes, and the arguments passed on.
'use strict';
const path = require('node:path');
const { spawn } = require('node:child_process');

module.exports = function launch(toolFlag) {
  const lib = path.join(__dirname, '..', 'lib');
  const env = Object.assign({}, process.env);
  const key = Object.keys(env).find((k) => k.toUpperCase() === 'PATH') || 'PATH';
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
