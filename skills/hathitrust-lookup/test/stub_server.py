#!/usr/bin/env python3
"""Minimal stub of the HathiTrust Bibliographic API for ht-lookup tests.

Serves /<brief|full>/json/<query> where <query> is one or more
"idtype:id" pairs joined by ';'. A pair whose id is "404" yields an empty
record (the API's not-found shape); anything else yields one record with two
items. With the "full" form a record gains a "marc-xml" field.

    python3 stub_server.py <port>
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import unquote


def result_for(pair, full):
    record = {
        "recordURL": "https://catalog.hathitrust.org/Record/000000001",
        "titles": ["Stub Title"],
        "isbns": ["9780000000001"],
        "issns": [],
        "oclcs": ["12345"],
        "lccns": ["00000001"],
        "publishDates": ["1999"],
    }
    if full:
        record["marc-xml"] = "<collection><record/></collection>"
    return {
        "records": {"000000001": record},
        "items": [
            {
                "orig": "Stub University",
                "fromRecord": "000000001",
                "htid": "stub.0001",
                "itemURL": "https://babel.hathitrust.org/cgi/pt?id=stub.0001",
                "rightsCode": "pd",
                "lastUpdate": "20990101",
                "enumcron": False,
                "usRightsString": "Full view",
            },
            {
                "orig": "Stub College",
                "fromRecord": "000000001",
                "htid": "stub.0002",
                "itemURL": "https://babel.hathitrust.org/cgi/pt?id=stub.0002",
                "rightsCode": "ic",
                "lastUpdate": "20990101",
                "enumcron": "v.2 1999",
                "usRightsString": "Limited (search-only)",
            },
        ],
    }


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.lstrip("/").split("/")
        # expect: <kind>/json/<query>
        if len(parts) < 3 or parts[1] != "json":
            self.send_error(404)
            return
        full = parts[0] == "full"
        query = unquote("/".join(parts[2:]))
        out = {}
        for pair in query.split(";"):
            _, _, idv = pair.partition(":")
            out[pair] = {"records": [], "items": []} if idv == "404" else result_for(pair, full)
        body = json.dumps(out).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):  # silence request logging
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
