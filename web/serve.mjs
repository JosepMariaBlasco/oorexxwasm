#!/usr/bin/env node
// serve.mjs: a small static web server for ooRexx/WASM pages, with no
// dependencies (Node.js 18 or later).
//
// ooRexx in the browser uses threads, that is SharedArrayBuffer, which
// browsers only give to a cross-origin isolated page: one served with
//   Cross-Origin-Opener-Policy: same-origin
//   Cross-Origin-Embedder-Policy: require-corp
// Opening the page as a file (file://), or from a server that does not send
// these headers, does not work. This server sends them, and the right types
// (application/wasm for rexx.wasm).
//
// Usage: node serve.mjs [DIR=directory of this file] [--port N=8000] [--host H=127.0.0.1]
//   then open http://localhost:8000/
// For testing and local work; for a public site, configure your web server
// (INSTALL.md: Apache, nginx).
import { createServer } from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import { resolve, join, extname, sep, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
let root = dirname(fileURLToPath(import.meta.url));
let port = 8000, host = '127.0.0.1';
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--port' || a === '-p') port = Number(args[++i]);
  else if (a === '--host') host = args[++i];
  else if (a === '--help' || a === '-h') {
    console.log('usage: node serve.mjs [DIR] [--port N] [--host H]');
    process.exit(0);
  } else root = a;
}
root = resolve(root);
if (!Number.isInteger(port) || port < 0 || port > 65535) {
  console.error('serve.mjs: bad port');
  process.exit(2);
}

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.htm': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm', '.data': 'application/octet-stream',
  '.rex': 'text/plain; charset=utf-8', '.cls': 'text/plain; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8', '.md': 'text/plain; charset=utf-8',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
};
const ISOLATION = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Resource-Policy': 'same-origin',
  'Cache-Control': 'no-cache',
};

function fail(res, status, text) {
  res.writeHead(status, { ...ISOLATION, 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(text + '\n');
}

const server = createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') return fail(res, 405, 'Method Not Allowed');
  let path;
  try {
    path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  } catch {
    return fail(res, 400, 'Bad Request');
  }
  let file = join(root, path);
  if (file !== root && !file.startsWith(root + sep)) return fail(res, 403, 'Forbidden');
  let st;
  try {
    st = statSync(file);
    if (st.isDirectory()) {
      if (!path.endsWith('/')) {
        res.writeHead(301, { ...ISOLATION, Location: path + '/' });
        return res.end();
      }
      file = join(file, 'index.html');
      st = statSync(file);
    }
  } catch {
    return fail(res, 404, 'Not Found');
  }
  if (!st.isFile()) return fail(res, 404, 'Not Found');
  res.writeHead(200, {
    ...ISOLATION,
    'Content-Type': TYPES[extname(file).toLowerCase()] || 'application/octet-stream',
    'Content-Length': st.size,
  });
  if (req.method === 'HEAD') return res.end();
  createReadStream(file).on('error', () => res.destroy()).pipe(res);
});

server.on('error', (e) => {
  console.error('serve.mjs: ' + e.message);
  process.exit(1);
});
server.listen(port, host, () => {
  const a = server.address();
  const local = ['127.0.0.1', '::1', '0.0.0.0', '::'].includes(a.address);
  const shown = local ? 'localhost' : a.address.includes(':') ? `[${a.address}]` : a.address;
  console.log(`Serving ${root} at http://${shown}:${a.port}/ (cross-origin isolated). Ctrl+C to stop.`);
});
