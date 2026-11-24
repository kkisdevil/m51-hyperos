#!/usr/bin/env python3
"""mock_mercury.py — local stub of the Mercury chat-completions API.

Used ONLY by tests/run_mock_e2e.sh to prove the rename driver, cache,
and applier work without spending a real API call.

Behaviour:
  POST /v1/chat/completions
      Reads the user message, finds the "Function: <name> at <addr>"
      line, and answers with a fixed rename:
        {"name": "renamed_<old>", "summary": "Mock rename of <old>",
         "confidence": 0.95}
      Appends one line to the call-count file for every request.
  GET /v1/models
      {"data": [{"id": "mercury-3"}]} (so MercuryClient.ping() works).

Usage:
  MOCK_COUNT_FILE=/tmp/calls.txt python3 mock_mercury.py [port]
Default port 8931. No key is needed; the stub ignores Authorization.
"""

from __future__ import annotations

import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

COUNT_FILE = os.environ.get("MOCK_COUNT_FILE", "/tmp/mock_mercury_calls.txt")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # keep test output clean
        pass

    def _count(self):
        with open(COUNT_FILE, "a", encoding="utf-8") as fh:
            fh.write("1\n")

    def do_GET(self):
        if self.path.rstrip("/").endswith("/v1/models"):
            body = json.dumps({"data": [{"id": "mercury-3"}]}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if not self.path.rstrip("/").endswith("/v1/chat/completions"):
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        user_text = ""
        for message in payload.get("messages", []):
            if message.get("role") == "user":
                user_text = message.get("content", "")
        match = re.search(r"Function:\s*(\S+)\s+at\s+(\S+)", user_text)
        old_name = match.group(1) if match else "unknown"
        self._count()
        reply = {"name": "renamed_%s" % old_name,
                 "summary": "Mock rename of %s" % old_name,
                 "confidence": 0.95}
        body = json.dumps({
            "id": "mock-1",
            "choices": [{"message": {"role": "assistant",
                                     "content": json.dumps(reply)}}],
            "usage": {"prompt_tokens": 10, "completion_tokens": 10},
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8931
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
