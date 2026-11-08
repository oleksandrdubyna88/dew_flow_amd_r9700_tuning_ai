#!/usr/bin/env python3
"""The local file server of the comfyui/fetch_model.sh tests (E1.S3). Stdlib only, no temp files.

    file_server.py <folder> <log file> <port file>

Binds 127.0.0.1 on port 0 and writes the port to the port file. HEAD and GET serve the files of the folder. A file `<name>.etag` beside a file makes the server send
`X-Linked-Etag: "<its content>"` for it. `/r/<name>` answers 302 to `/<name>` with the same header, the way the real source does. `Range: bytes=<n>-` answers 206 with
Content-Range. A missing file is 404. Every request is one log line: `<METHOD> <path> <range or ->`.
"""
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT, LOG, PORT_FILE = sys.argv[1], sys.argv[2], sys.argv[3]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):  # the access log of http.server goes nowhere; the test's log is written below
        pass

    def _log(self):
        with open(LOG, "a", encoding="utf-8") as handle:
            handle.write("%s %s %s\n" % (self.command, self.path, self.headers.get("Range") or "-"))

    def _file(self, name):
        if ".." in name.split("/"):
            return None
        path = os.path.join(ROOT, name)
        return path if os.path.isfile(path) else None

    def _etag_header(self, path):
        etag = path + ".etag"
        if not os.path.isfile(etag):
            return None
        with open(etag, encoding="utf-8") as handle:
            return '"%s"' % handle.read().strip()

    def _answer(self, send_body):
        self._log()
        name = self.path.split("?", 1)[0].lstrip("/")
        redirect = name.startswith("r/")
        path = self._file(name[2:] if redirect else name)
        if path is None:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        etag = self._etag_header(path)
        if redirect:
            self.send_response(302)
            self.send_header("Location", "/" + name[2:])
            if etag:
                self.send_header("X-Linked-Etag", etag)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        size = os.path.getsize(path)
        start, status = 0, 200
        wanted = self.headers.get("Range")
        if wanted and wanted.startswith("bytes=") and wanted.endswith("-"):
            start, status = int(wanted[6:-1]), 206
        if start >= size and status == 206:
            self.send_response(416)
            self.send_header("Content-Range", "bytes */%d" % size)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.send_response(status)
        if status == 206:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, size - 1, size))
        if etag:
            self.send_header("X-Linked-Etag", etag)
        self.send_header("Content-Length", str(size - start))
        self.end_headers()
        if send_body:
            with open(path, "rb") as handle:
                handle.seek(start)
                self.wfile.write(handle.read())

    def do_HEAD(self):
        self._answer(False)

    def do_GET(self):
        self._answer(True)


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(PORT_FILE, "w", encoding="utf-8") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
