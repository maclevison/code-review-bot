#!/usr/bin/env python3
"""Minimal mock of an OpenAI-compatible (OpenRouter) chat endpoint.

Used only by test/selftest.sh. Responds to any POST with a canned reply so
the review pipeline can be exercised deterministically, with no real API
call, no token cost, and no network. Behaviour is selected via MOCK_MODE:

  ok    (default) -> valid JSON with a canned review + usage
  empty            -> valid JSON whose message content is ""
  html             -> HTTP 200 with a NON-JSON body (proxy/CDN error page)
"""
import http.server
import json
import os

MODE = os.environ.get("MOCK_MODE", "ok")
PORT = int(os.environ.get("PORT", "8137"))

# Canned review text — references the planted bug in fixtures/sample.diff so
# the happy-path test can assert the pipeline carried it through.
REVIEW_TEXT = (
    "Bloqueadores encontrados\n"
    "- src/discount.js:2 off-by-one: `>` deveria ser `>=` para incluir 100."
)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)

        if MODE == "html":
            body = b"<html>502 Bad Gateway</html>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(body)
            return

        content = "" if MODE == "empty" else REVIEW_TEXT
        payload = {
            "choices": [{"message": {"content": content}}],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 0 if MODE == "empty" else 20,
                "total_tokens": 10 if MODE == "empty" else 30,
                "cost": 0.0001,
            },
        }
        data = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):  # silence request logging
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
