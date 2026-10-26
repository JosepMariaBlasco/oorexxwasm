# Serves this directory on http://127.0.0.1:8000/ with the headers that make
# the page cross-origin isolated (needed for a shared WebAssembly.Memory).
import os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
os.chdir(os.path.dirname(os.path.abspath(__file__)))
class H(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()
print('http://127.0.0.1:8000/')
ThreadingHTTPServer(('127.0.0.1', 8000), H).serve_forever()
