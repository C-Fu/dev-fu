#!/bin/sh
PORT=18765
SCRIPT="./fu.sh"

python3 - <<'PY'
import os, socket, signal, sys
from http.server import BaseHTTPRequestHandler
from socketserver import ThreadingMixIn, TCPServer

PORT = int(os.environ.get("PORT", "8080"))
SCRIPT = os.environ.get("SCRIPT", "./myscript.sh")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            with open(SCRIPT, "rb") as f:
                body = f.read()
        except Exception:
            self.send_response(404)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(b"Not found\n")
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        # keep minimal logging to stdout
        sys.stdout.write("%s - - [%s] %s\n" % (self.client_address[0], self.log_date_time_string(), fmt%args))

class ThreadedTCPServer(ThreadingMixIn, TCPServer):
    allow_reuse_address = True
    # allow_reuse_port may not be available on all platforms; set if present
    if hasattr(socket, "SO_REUSEPORT"):
        allow_reuse_port = True

def create_server(address):
    # create socket manually so we can set options before bind
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    # try to set SO_REUSEPORT if available
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    except Exception:
        pass
    sock.bind(address)
    sock.listen(5)
    return sock

server = None
def shutdown(signum, frame):
    global server
    print("Shutting down...")
    if server:
        try:
            server.shutdown()
        except Exception:
            pass
        try:
            server.server_close()
        except Exception:
            pass
    sys.exit(0)

signal.signal(signal.SIGINT, shutdown)
signal.signal(signal.SIGTERM, shutdown)

addr = ("0.0.0.0", PORT)
sock = create_server(addr)
server = ThreadedTCPServer(addr, Handler, bind_and_activate=False)
# replace server.socket with our pre-configured socket and activate
server.socket = sock
server.server_activate()
print("Serving on http://0.0.0.0:%d (script: %s)" % (PORT, SCRIPT))
server.serve_forever()
PY
