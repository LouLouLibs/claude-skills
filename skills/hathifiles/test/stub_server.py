#!/usr/bin/env python3
"""Minimal stub of the HathiFiles host for hathifiles tests.

Serves /hathi_file_list.json (a small listing) and any /hathi_*.txt.gz path
(arbitrary bytes — the download path only cares that bytes arrive).

    python3 stub_server.py <port>
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LISTING = [
    {"filename": "hathi_full_20260501.txt.gz", "full": True, "size": 1200000000,
     "created": "2026-05-01 12:00:00 -0400", "modified": "2026-05-01 12:00:00 -0400"},
    {"filename": "hathi_full_20260601.txt.gz", "full": True, "size": 1215000000,
     "created": "2026-06-01 12:00:00 -0400", "modified": "2026-06-01 12:00:00 -0400"},
    {"filename": "hathi_upd_20260617.txt.gz", "full": False, "size": 500000,
     "created": "2026-06-17 05:00:00 -0400", "modified": "2026-06-17 05:00:00 -0400"},
    {"filename": "hathi_upd_20260618.txt.gz", "full": False, "size": 1300000,
     "created": "2026-06-18 05:00:00 -0400", "modified": "2026-06-18 05:00:00 -0400"},
]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.endswith("/hathi_file_list.json"):
            body = json.dumps(LISTING).encode()
            ctype = "application/json"
        elif self.path.endswith(".txt.gz"):
            body = b"STUB-GZIP-BYTES-" + self.path.rsplit("/", 1)[-1].encode()
            ctype = "application/x-gzip"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
