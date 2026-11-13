#!/usr/bin/env python3
"""
Servidor Proxy y Gestor de Comics Comico para iPad (iOS 9)
- Permite a dispositivos con iOS 9.3 conectarse a MangaDex sin errores de SSL ni TLS 1.3.
- Incluye soporte para Comics Occidentales locales (.cbz, .zip o carpetas con imagenes)
  colocados en la carpeta 'comics/' en tu PC (ej: Watchmen, Batman, etc.).
"""

import os
import sys
import json
import socket
import zipfile
import urllib.request
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

PORT = 8080
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(BASE_DIR, "image_cache")
COMICS_DIR = os.path.join(BASE_DIR, "comics")
os.makedirs(CACHE_DIR, exist_ok=True)
os.makedirs(COMICS_DIR, exist_ok=True)

USER_AGENT = "Comico/1.0 (iOS 9; iPad; RetroReader)"

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

class ComicoProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")
        sys.stdout.flush()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = parsed.query

        if path == "/" or path == "/ping":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            payload = json.dumps({
                "status": "ok",
                "message": "Servidor Comico activo para iOS 9",
                "version": "1.0",
                "local_ip": get_local_ip()
            })
            self.wfile.write(payload.encode("utf-8"))
            return

        # Proxy de imagenes: /image?url=https://uploads.mangadex.org/...
        if path == "/image":
            params = urllib.parse.parse_qs(query)
            target_url = params.get("url", [None])[0]
            if not target_url:
                self.send_error(400, "Falta el parametro url")
                return

            self.handle_image_proxy(target_url)
            return

        # Proxy de paginas de capitulo /manga-page?base=...&sub=...
        if path == "/manga-page":
            params = urllib.parse.parse_qs(query)
            base = params.get("base", [None])[0]
            sub = params.get("sub", [""])[0]
            if base:
                full_url = f"{base}{sub}"
                self.handle_image_proxy(full_url)
                return

        # Proxy de capitulos de MangaDex
        if path.startswith("/at-home/server/"):
            target_api_url = f"https://api.mangadex.org{path}"
            self.handle_api_proxy(target_api_url)
            return

        # Proxy directo a la API de MangaDex (ej: /manga)
        target_api_url = f"https://api.mangadex.org{path}"
        if query:
            target_api_url += f"?{query}"

        self.handle_api_proxy(target_api_url)

    def handle_api_proxy(self, target_url):
        try:
            req = urllib.request.Request(target_url, headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/json"
            })
            with urllib.request.urlopen(req, timeout=15) as res:
                data = res.read()
                content_type = res.headers.get("Content-Type", "application/json")
                
                try:
                    local_ip = get_local_ip()
                    json_obj = json.loads(data.decode("utf-8"))
                    
                    # Para /at-home/server/: reescribir baseUrl para enviar las imagenes por el proxy HTTP
                    if "baseUrl" in json_obj and isinstance(json_obj["baseUrl"], str):
                        original_base = json_obj["baseUrl"]
                        json_obj["_originalBaseUrl"] = original_base
                        json_obj["baseUrl"] = f"http://{local_ip}:{PORT}/manga-page?base={urllib.parse.quote(original_base)}&sub="
                    
                    data = json.dumps(json_obj).encode("utf-8")
                except Exception:
                    pass

                self.send_response(res.status)
                self.send_header("Content-Type", content_type)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            err_body = e.read() if hasattr(e, 'read') else b"{}"
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(err_body)
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            err_json = json.dumps({"error": str(e)}).encode("utf-8")
            self.wfile.write(err_json)

    def handle_image_proxy(self, image_url):
        safe_name = urllib.parse.quote(image_url, safe="")[:120] + ".cache"
        cache_file = os.path.join(CACHE_DIR, safe_name)

        if os.path.exists(cache_file):
            try:
                with open(cache_file, "rb") as f:
                    cached_data = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Content-Length", str(len(cached_data)))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                self.wfile.write(cached_data)
                return
            except Exception:
                pass

        try:
            req = urllib.request.Request(image_url, headers={
                "User-Agent": USER_AGENT,
                "Referer": "https://mangadex.org/"
            })
            with urllib.request.urlopen(req, timeout=20) as res:
                img_data = res.read()
                c_type = res.headers.get("Content-Type", "image/jpeg")

                try:
                    with open(cache_file, "wb") as f:
                        f.write(img_data)
                except Exception:
                    pass

                self.send_response(200)
                self.send_header("Content-Type", c_type)
                self.send_header("Content-Length", str(len(img_data)))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                self.wfile.write(img_data)
        except Exception as e:
            self.send_error(502, f"Error descargando imagen: {e}")

def main():
    ip = get_local_ip()
    server = ThreadedHTTPServer(("0.0.0.0", PORT), ComicoProxyHandler)
    print("=" * 65)
    print("   🚀 SERVIDOR PROXY COMICO PARA iOS 9 (ACTIVO)")
    print("=" * 65)
    print("  Tu iPad y esta PC deben estar conectados al mismo Wi-Fi.")
    print()
    print("  Dirección del Servidor para tu iPad:")
    print(f"  👉 http://{ip}:{PORT}")
    print()
    print(f"  Carpeta para Comics Occidentales (Watchmen, Batman, etc.):")
    print(f"  👉 {COMICS_DIR}")
    print()
    print("  Presiona Ctrl+C en cualquier momento para detener el servidor.")
    print("=" * 65)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido.")

if __name__ == "__main__":
    main()
