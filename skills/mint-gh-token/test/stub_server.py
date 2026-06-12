#!/usr/bin/env python3
"""Stub of the two GitHub API endpoints mint-gh-token talks to.

Usage: stub_server.py PORT CAPTURE_DIR

Writes the received app JWT to CAPTURE_DIR/jwt.txt so the test script can
verify the RS256 signature out-of-band with openssl.
"""
import json
import sys
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = int(sys.argv[1])
CAPTURE = Path(sys.argv[2])

EXPECTED_HEADERS = ["Accept", "X-GitHub-Api-Version", "User-Agent"]


class Handler(BaseHTTPRequestHandler):
    def _reply(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _check_auth(self):
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer ") or auth.count(".") != 2:
            self._reply(401, {"message": "bad or missing app JWT"})
            return False
        for h in EXPECTED_HEADERS:
            if not self.headers.get(h):
                self._reply(400, {"message": f"missing header {h}"})
                return False
        (CAPTURE / "jwt.txt").write_text(auth.removeprefix("Bearer "))
        return True

    def do_GET(self):
        if not self._check_auth():
            return
        if self.path == "/repos/test-owner/test-repo/installation":
            self._reply(200, {"id": 424242})
        else:
            self._reply(404, {"message": f"unexpected GET {self.path}"})

    def do_POST(self):
        if not self._check_auth():
            return
        if self.path == "/app/installations/424242/access_tokens":
            expires = datetime.now(timezone.utc) + timedelta(hours=1)
            self._reply(201, {
                "token": "ghs_stubtoken1234567890",
                "expires_at": expires.strftime("%Y-%m-%dT%H:%M:%SZ"),
            })
        else:
            self._reply(404, {"message": f"unexpected POST {self.path}"})

    def log_message(self, *args):
        pass  # keep test output clean


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
