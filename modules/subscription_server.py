#!/usr/bin/env python3

import base64
import hmac
import ipaddress
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, urlencode


BASE_DIR = os.environ.get("VVC_BASE_DIR", "/root/nast-singbox-vvc")
DATA_DIR = os.path.join(BASE_DIR, "data")
CONFIG_FILE = os.path.join(DATA_DIR, "subscription.json")
NODES_FILE = os.path.join(DATA_DIR, "nodes.json")
USERS_FILE = os.path.join(DATA_DIR, "users.json")
FALLBACK_UUID = "12345678-1234-1234-1234-123456789abc"


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as file:
            return json.load(file)
    except FileNotFoundError:
        return default


def query_string(values):
    return urlencode(values)


def node_link(node, user_id):
    protocol = node.get("protocol", "")
    domain = str(node.get("domain", ""))
    if not domain or not node.get("port"):
        return None

    try:
        address = ipaddress.ip_address(domain)
        if address.version == 6:
            domain = f"[{domain}]"
    except ValueError:
        pass

    host_port = f"{domain}:{node['port']}"
    tag = quote(str(node.get("tag", "")), safe="")
    sni = str(node.get("server_name") or node.get("domain") or "")

    if protocol == "hysteria2":
        query = query_string({"sni": sni, "insecure": "1"})
        return f"hysteria2://{quote(user_id, safe='')}@{host_port}/?{query}#{tag}"

    if protocol == "tuic":
        password = quote(str(node.get("password") or node.get("public_key") or ""), safe="")
        query = query_string(
            {
                "sni": sni,
                "congestion_control": "bbr",
                "alpn": "h3",
                "allow_insecure": "1",
                "insecure": "1",
            }
        )
        return f"tuic://{quote(user_id, safe='')}:{password}@{host_port}/?{query}#{tag}"

    if protocol == "vless-reality":
        query = query_string(
            {
                "security": "reality",
                "encryption": "none",
                "pbk": str(node.get("public_key", "")),
                "headerType": "none",
                "fp": "chrome",
                "type": "tcp",
                "flow": "xtls-rprx-vision",
                "sni": sni,
                "sid": str(node.get("short_id", "")),
            }
        )
        return f"vless://{quote(user_id, safe='')}@{host_port}?{query}#{tag}"

    if protocol == "vless-grpc-reality":
        query = query_string(
            {
                "security": "reality",
                "encryption": "none",
                "pbk": str(node.get("public_key", "")),
                "fp": "chrome",
                "type": "grpc",
                "serviceName": str(node.get("service_name", "")),
                "sni": sni,
                "sid": str(node.get("short_id", "")),
            }
        )
        return f"vless://{quote(user_id, safe='')}@{host_port}?{query}#{tag}"

    if protocol == "vless-ws-tls":
        query = query_string(
            {
                "security": "tls",
                "encryption": "none",
                "type": "ws",
                "path": str(node.get("ws_path") or "/"),
                "sni": sni,
                "allowInsecure": "1",
                "insecure": "1",
            }
        )
        return f"vless://{quote(user_id, safe='')}@{host_port}?{query}#{tag}"

    return None


def build_subscription():
    nodes = read_json(NODES_FILE, [])
    users = read_json(USERS_FILE, [])
    default_uuid = users[0].get("uuid") if users and isinstance(users[0], dict) else None
    links = []

    if not isinstance(nodes, list):
        raise ValueError("nodes.json must contain a JSON array")

    for node in nodes:
        if not isinstance(node, dict):
            continue
        user_id = str(default_uuid or node.get("uuid") or FALLBACK_UUID)
        link = node_link(node, user_id)
        if link:
            links.append(link)

    if not links:
        raise ValueError("No supported nodes are configured")

    plain_text = "\n".join(links).encode("utf-8")
    return base64.b64encode(plain_text) + b"\n"


class SubscriptionHandler(BaseHTTPRequestHandler):
    server_version = "VVCSubscription/1.0"

    def do_GET(self):
        expected_path = f"/sub/{self.server.token}"
        if not hmac.compare_digest(self.path, expected_path):
            self.send_error(404)
            return

        try:
            content = build_subscription()
        except (OSError, ValueError, json.JSONDecodeError) as error:
            self.send_error(503, str(error))
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Profile-Title", "NAST Sing-box VVC")
        self.end_headers()
        self.wfile.write(content)

    def log_message(self, format_string, *args):
        print(f"{self.client_address[0]} - {args[1] if len(args) > 1 else 'request'}")


def main():
    config = read_json(CONFIG_FILE, {})
    token = config.get("token")
    port = config.get("port")
    if not isinstance(token, str) or not token or not isinstance(port, int):
        raise SystemExit(f"Invalid subscription configuration: {CONFIG_FILE}")

    server = ThreadingHTTPServer(("0.0.0.0", port), SubscriptionHandler)
    server.token = token
    server.serve_forever()


if __name__ == "__main__":
    main()
