"""Item list app — lists items on a web page and as JSON."""
import argparse
import html
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from store import Store

STORE = Store()


def page():
    items = "".join(f"<li>{html.escape(n)}</li>" for n in STORE.all())
    return (
        "<!doctype html><html><head><meta charset='utf-8'><title>Items</title></head><body>"
        f"<h1>Items</h1><p id='count'>{len(STORE.all())} items</p><ul id='items'>{items}</ul>"
        "</body></html>"
    )


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, ctype):
        data = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/":
            self.send(200, page(), "text/html; charset=utf-8")
        elif self.path == "/api/items":
            self.send(200, json.dumps({"items": STORE.all()}), "application/json")
        else:
            self.send(404, json.dumps({"error": "not found"}), "application/json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"listening on http://127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
