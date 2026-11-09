"""Acceptance-only reverse proxy. No fault switches are added to product APIs."""
import http.client
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = os.environ.get("UPSTREAM", "sf-business-fridge:8082")
state = {"mode": "healthy", "forwarded": 0}
lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # Never log access tokens or request bodies.

    def reply(self, status, body):
        raw = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        try:
            self.wfile.write(raw)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        with lock:
            snapshot = dict(state)
        self.reply(200, snapshot)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path == "/__test__/mode":
            mode = json.loads(raw).get("mode")
            if mode not in {"healthy", "reject", "lose-response", "timeout", "slow"}:
                return self.reply(400, {"error": "unsupported test mode"})
            with lock:
                state["mode"] = mode
            return self.reply(200, {"mode": mode})
        with lock:
            mode = state["mode"]
        if mode == "reject":
            return self.reply(503, {"code": "INTERNAL_ERROR", "message": "test dependency unavailable"})
        with lock:
            state["forwarded"] += 1
        headers = {key: value for key, value in self.headers.items()
                   if key.lower() not in {"host", "connection", "content-length"}}
        connection = http.client.HTTPConnection(UPSTREAM, timeout=20)
        try:
            connection.request("POST", self.path, body=raw, headers=headers)
            response = connection.getresponse()
            body = response.read()
            status = response.status
            if mode == "lose-response":
                return self.reply(503, {"code": "INTERNAL_ERROR", "message": "test response lost after write"})
            if mode == "timeout":
                time.sleep(2.5)
            if mode == "slow":
                time.sleep(0.45)
            self.reply(status, body)
        except Exception as error:
            self.reply(503, {"code": "INTERNAL_ERROR", "message": type(error).__name__})
        finally:
            connection.close()


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8099), Handler).serve_forever()
