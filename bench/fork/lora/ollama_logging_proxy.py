#!/usr/bin/env python3
"""
Ollama-side logging proxy for Phase 3.1 corpus capture (stream 3).

Sits in front of Ollama's /v1/chat/completions on azza. For each request:
logs the full request body + response body to
  ~/wireclaw-corpus/ollama-raw/<YYYY-MM-DD>/<client-ip>_<ts>.json
then forwards in/out UNCHANGED. Adds ~ms latency; chips don't notice.

Stdlib only (http.server + urllib) — deliberately NO third-party deps so it
needs no venv/pip on azza.

Usage:
    python3 ollama_logging_proxy.py            # listen :11435 -> 127.0.0.1:11434
    LISTEN_PORT=11435 UPSTREAM=http://127.0.0.1:11434 python3 ollama_logging_proxy.py

Run (background):
    nohup python3 ~/ollama_logging_proxy.py > ~/ollama_proxy.log 2>&1 &
Stop:
    pkill -f ollama_logging_proxy.py

LIMITATION (Phase 3.1 hardening): this passes the upstream response back as a
single buffered body. WireClaw issues non-streaming requests (Connection: close,
full JSON), so buffering is correct for the chip fleet. If a future client sets
"stream": true (SSE), this proxy would buffer the stream and break incremental
delivery — add chunked/SSE passthrough before using with streaming clients.
"""
import json, os, time, datetime, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "11435"))
UPSTREAM = os.environ.get("UPSTREAM", "http://127.0.0.1:11434")
CORPUS_DIR = os.path.expanduser("~/wireclaw-corpus/ollama-raw")


def _log(client_ip, path, req_body, status, resp_body, t_ms):
    day = datetime.date.today().isoformat()
    d = os.path.join(CORPUS_DIR, day)
    os.makedirs(d, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%dT%H%M%S_%f")
    rec = {
        "ts": ts,
        "client_ip": client_ip,
        "path": path,
        "upstream_latency_ms": round(t_ms, 1),
        "status": status,
    }
    # Store bodies as parsed JSON when possible, else raw text.
    for key, raw in (("request", req_body), ("response", resp_body)):
        try:
            rec[key] = json.loads(raw) if raw else None
        except (ValueError, TypeError):
            rec[key] = {"_raw": raw.decode("utf-8", "replace") if isinstance(raw, bytes) else raw}
    fn = os.path.join(d, f"{client_ip}_{ts}.json")
    with open(fn, "w") as f:
        json.dump(rec, f, indent=2)
    return fn


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _proxy(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        url = UPSTREAM.rstrip("/") + self.path
        fwd = urllib.request.Request(url, data=body if body else None,
                                     method=self.command)
        for h, v in self.headers.items():
            if h.lower() not in ("host", "content-length", "connection"):
                fwd.add_header(h, v)
        t0 = time.time()
        status = 599
        resp_body = b""
        try:
            with urllib.request.urlopen(fwd, timeout=300) as r:
                status = r.status
                resp_body = r.read()
                resp_headers = dict(r.headers)
        except urllib.error.HTTPError as e:
            status = e.code
            resp_body = e.read()
            resp_headers = dict(e.headers)
        except Exception as e:  # upstream unreachable etc.
            status = 502
            resp_body = json.dumps({"proxy_error": repr(e)}).encode()
            resp_headers = {"Content-Type": "application/json"}
        dt_ms = (time.time() - t0) * 1000.0

        try:
            fn = _log(self.client_address[0], self.path, body, status,
                      resp_body, dt_ms)
            self.log_message("logged -> %s", fn)
        except Exception as e:  # logging must never break the passthrough
            self.log_message("LOG FAILED (passthrough still OK): %r", e)

        self.send_response(status)
        for h, v in resp_headers.items():
            if h.lower() not in ("transfer-encoding", "connection",
                                 "content-length"):
                self.send_header(h, v)
        self.send_header("Content-Length", str(len(resp_body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(resp_body)

    def do_POST(self):
        self._proxy()

    def do_GET(self):
        self._proxy()


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), Handler)
    print(f"ollama_logging_proxy :{LISTEN_PORT} -> {UPSTREAM} "
          f"logging to {CORPUS_DIR}/<date>/", flush=True)
    srv.serve_forever()
