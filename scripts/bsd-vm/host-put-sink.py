#!/usr/bin/env python3
"""guest->host upload sink for the BSD QEMU harness (port 8097).

The build VM pushes probe results back with
  curl -s -X PUT --data-binary @/tmp/x.out http://10.0.2.2:8097/x.out
which plain http.server rejects, hence this handler. Writes land in
/tmp/guest-uploads. Path components are stripped so the guest cannot escape.
"""
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

SINK = "/tmp/guest-uploads"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _sink_path(self):
        name = os.path.basename(self.path.split("?", 1)[0].strip("/"))
        return os.path.join(SINK, name or "unnamed")

    def do_PUT(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        path = self._sink_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(body)
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    do_POST = do_PUT

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    os.makedirs(SINK, exist_ok=True)
    HTTPServer(("0.0.0.0", 8097), Handler).serve_forever()
