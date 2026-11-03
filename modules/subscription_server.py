#!/usr/bin/env python3

import base64
import http.server
import json
import logging
import secrets
import ssl
import subprocess
from pathlib import Path
from urllib.parse import urlsplit


BASE_DIR = Path("/root/nast-singbox-vvc")
CONFIG_FILE = BASE_DIR / "data" / "subscription.json"
EXPORT_SCRIPT = BASE_DIR / "modules" / "subscription_export.sh"


def load_config():
    with CONFIG_FILE.open(encoding="utf-8") as config_file:
        config = json.load(config_file)

    if not isinstance(config, dict):
        raise ValueError("Subscription configuration must be a JSON object.")

    token = config.get("token")
    port = config.get("port")
    cert = Path(config.get("cert", ""))
    key = Path(config.get("key", ""))
    if not isinstance(token, str) or len(token) != 64:
        raise ValueError("Subscription token must be a 64-character secret.")
    if not isinstance(port, int) or not 1 <= port <= 65535:
        raise ValueError("Subscription port is invalid.")
    if not cert.is_file() or not key.is_file():
        raise ValueError("Configured TLS certificate or private key is unavailable.")
    return token, port, cert, key


class SubscriptionHandler(http.server.BaseHTTPRequestHandler):
    token = ""

    def do_GET(self):
        request_path = urlsplit(self.path).path
        if not secrets.compare_digest(request_path, f"/sub/{self.token}"):
            self.send_error(404)
            return

        try:
            result = subprocess.run(
                ["/bin/bash", str(EXPORT_SCRIPT)],
                check=True,
                capture_output=True,
                text=True,
                timeout=15,
            )
        except subprocess.CalledProcessError as error:
            logging.error("Unable to generate subscription: %s", error.stderr.strip())
            self.send_error(503, "Subscription data could not be generated.")
            return
        except subprocess.TimeoutExpired:
            logging.error("Timed out while generating subscription.")
            self.send_error(503, "Subscription data generation timed out.")
            return
        except OSError as error:
            logging.error("Unable to run subscription exporter: %s", error)
            self.send_error(503, "Subscription exporter is unavailable.")
            return

        links = result.stdout.strip()
        if not links:
            self.send_error(503, "No nodes are available for this subscription.")
            return

        payload = base64.b64encode(links.encode("utf-8"))
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, _format, *_args):
        return


def main():
    token, port, cert, key = load_config()
    SubscriptionHandler.token = token
    server = http.server.ThreadingHTTPServer(("0.0.0.0", port), SubscriptionHandler)
    tls_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls_context.load_cert_chain(certfile=str(cert), keyfile=str(key))
    server.socket = tls_context.wrap_socket(server.socket, server_side=True)
    logging.info("Subscription HTTPS service listening on port %d.", port)
    server.serve_forever()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    main()
