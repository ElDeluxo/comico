#!/usr/bin/env python3
"""
Servidor Proxy y Motor de Comics para Mangie / iPad iOS 9
- Conecta a MangaDex (Manga japones / coreano) eliminando errores de SSL/TLS en iOS 9.
- Scraper e integrador de Comics Occidentales (Watchmen, Batman, Spider-Man, etc.)
  usando la coleccion digital de Internet Archive (sin Cloudflare, sin CAPTCHA, 100% publico).
- Soporte para comics locales (.cbz, .cbr, .zip) en la carpeta 'comics/'.
- Cache inteligente en disco en 'image_cache/' para lecturas instantaneas.
"""

import os
import sys
import re
import json
import time
import socket
import zipfile
import urllib.request
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

PORT = 80
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(BASE_DIR, "image_cache")
COMICS_DIR = os.path.join(BASE_DIR, "comics")
os.makedirs(CACHE_DIR, exist_ok=True)
os.makedirs(COMICS_DIR, exist_ok=True)

USER_AGENT = "ComicoProxy/2.0 (iPad; iOS 9; RetroReader)"

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

LOCAL_IP = get_local_ip()

def get_local_comics():
    local_items = []
    if not os.path.exists(COMICS_DIR):
        return local_items

    for entry in os.listdir(COMICS_DIR):
        entry_path = os.path.join(COMICS_DIR, entry)
        if os.path.isdir(entry_path):
            comic_id = f"local_{urllib.parse.quote(entry)}"
            desc = f"Cómic almacenado localmente en tu biblioteca offline."
            local_items.append(make_mangadex_manga_obj(comic_id, f"📁 {entry} (Descargado)", desc, entry))
        elif entry.lower().endswith(".cbz") or entry.lower().endswith(".zip"):
            clean_name = os.path.splitext(entry)[0]
            comic_id = f"local_cbz_{urllib.parse.quote(entry)}"
            desc = f"Archivo CBZ descargado para lectura offline."
            local_items.append(make_mangadex_manga_obj(comic_id, f"📦 {clean_name} (CBZ)", desc, entry))

    return local_items
POPULAR_WESTERN = [
    {
        "id": "ia_Watchmen_201906",
        "title": "Watchmen (Alan Moore & Dave Gibbons)",
        "desc": "La aclamada novela grafica de Alan Moore y Dave Gibbons sobre moralidad, poder y vigilantes en plena Guerra Fria.",
        "ident": "Watchmen_201906"
    },
    {
        "id": "ia_BatmanTheKillingJokeDeluxeHCEdition2008MinutemenY2K",
        "title": "Batman: The Killing Joke (Deluxe)",
        "desc": "El origen definitivo del Joker creado por Alan Moore y Brian Bolland.",
        "ident": "BatmanTheKillingJokeDeluxeHCEdition2008MinutemenY2K"
    },
    {
        "id": "ia_BatmanTheDarkKnightReturns03of041986",
        "title": "Batman: The Dark Knight Returns",
        "desc": "La legendaria obra maestra de Frank Miller donde un Bruce Wayne envejecido retoma el manto.",
        "ident": "BatmanTheDarkKnightReturns03of041986"
    },
    {
        "id": "ia_v-for-vendetta-by-alan-moore-david-lloyd",
        "title": "V for Vendetta (Alan Moore & David Lloyd)",
        "desc": "En un futuro distopico, un misterioso anarquista con la mascara de Guy Fawkes inicia una revolucion.",
        "ident": "v-for-vendetta-by-alan-moore-david-lloyd"
    },
    {
        "id": "ia_batmanthelonghalloween1998digitalzoneempire",
        "title": "Batman: The Long Halloween",
        "desc": "Un asesino serial llamado Holiday aterroriza Gotham City en los primeros anos de carrera de Batman.",
        "ident": "batmanthelonghalloween1998digitalzoneempire"
    },
    {
        "id": "ia_871-amazing-spiderman",
        "title": "The Amazing Spider-Man (Comics Collection)",
        "desc": "Coleccion de aventuras clasicas del trepamuros favorito de Marvel Comics.",
        "ident": "871-amazing-spiderman"
    }
]

def make_mangadex_manga_obj(comic_id, title, desc, cover_ident):
    return {
        "id": comic_id,
        "type": "manga",
        "attributes": {
            "title": {"en": title},
            "altTitles": [{"es": title}],
            "description": {"en": desc, "es": desc},
            "status": "completed",
            "year": 1986,
            "contentRating": "safe",
            "tags": [
                {
                    "id": "western-comic",
                    "type": "tag",
                    "attributes": {
                        "name": {"en": "Western Comic"},
                        "group": "format"
                    }
                }
            ],
            "state": "published",
            "createdAt": "2020-01-01T00:00:00+00:00",
            "updatedAt": "2026-01-01T00:00:00+00:00",
            "latestUploadedChapter": "1"
        },
        "relationships": [
            {
                "id": f"cov_{comic_id}",
                "type": "cover_art",
                "attributes": {
                    "fileName": f"{cover_ident}.cover"
                }
            },
            {
                "id": "auth_western",
                "type": "author",
                "attributes": {
                    "name": "Comic Occidental"
                }
            }
        ]
    }

def search_internet_archive(query):
    try:
        search_q = f"title:({query}) AND mediatype:(texts) AND -collection:(inlibrary)"
        url = f"https://archive.org/advancedsearch.php?q={urllib.parse.quote(search_q)}&fl[]=identifier,title,downloads,description&sort[]=downloads+desc&output=json&rows=15"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=8) as r:
            data = json.loads(r.read().decode("utf-8"))
            docs = data.get("response", {}).get("docs", [])
            results = []
            for d in docs:
                ident = d.get("identifier")
                title = d.get("title", ident)
                desc = d.get("description", "Comic Occidental alojado en Internet Archive")
                if isinstance(desc, list):
                    desc = " ".join(desc)
                results.append(make_mangadex_manga_obj(f"ia_{ident}", title, desc, ident))
            return results
    except Exception as e:
        print(f"[IA-Search Error] {e}")
        return []

def get_ia_chapters(identifier):
    url = f"https://archive.org/metadata/{identifier}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))
            files = data.get("files", [])
            chapters = []

            # Buscar PDFs individuales (ej: Watchmen 01, 02...)
            pdf_files = []
            for f in files:
                name = f.get("name", "")
                if name.endswith(".pdf") and not name.endswith("_text.pdf"):
                    pdf_files.append(name)

            if len(pdf_files) > 1:
                # Multiples numeros / capitulos
                pdf_files.sort()
                for idx, pdf in enumerate(pdf_files, 1):
                    # Limpiar nombre
                    ch_title = pdf.replace(".pdf", "")
                    chapters.append({
                        "id": f"ia__{identifier}__sub__{idx-1}__{urllib.parse.quote(pdf)}",
                        "type": "chapter",
                        "attributes": {
                            "volume": "1",
                            "chapter": str(idx),
                            "title": ch_title,
                            "translatedLanguage": "en",
                            "publishAt": "2020-01-01T00:00:00+00:00",
                            "readableAt": "2020-01-01T00:00:00+00:00",
                            "pages": 35
                        },
                        "relationships": []
                    })
            else:
                # Tomo unico o novela grafica completa
                image_count = data.get("metadata", {}).get("imagecount", 35)
                try:
                    image_count = int(image_count)
                except Exception:
                    image_count = 35

                chapters.append({
                    "id": f"ia__{identifier}__full",
                    "type": "chapter",
                    "attributes": {
                        "volume": "1",
                        "chapter": "1",
                        "title": data.get("metadata", {}).get("title", "Edicion Completa"),
                        "translatedLanguage": "en",
                        "publishAt": "2020-01-01T00:00:00+00:00",
                        "readableAt": "2020-01-01T00:00:00+00:00",
                        "pages": image_count
                    },
                    "relationships": []
                })

            return chapters
    except Exception as e:
        print(f"[IA-Meta Error] {e}")
        return [{
            "id": f"ia__{identifier}__default",
            "type": "chapter",
            "attributes": {
                "volume": "1",
                "chapter": "1",
                "title": "Comic Completo",
                "translatedLanguage": "en",
                "pages": 35
            },
            "relationships": []
        }]

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
        params = urllib.parse.parse_qs(query)

        # 1. Endpoint de estado
        if path in ("/", "/ping"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            payload = json.dumps({
                "status": "ok",
                "server": "Comico Proxy iOS 9 v2.0",
                "ip": LOCAL_IP,
                "port": PORT
            })
            self.wfile.write(payload.encode("utf-8"))
            return

        # 2. Covers: /covers/{manga_id}/{filename}
        if path.startswith("/covers/"):
            parts = [p for p in path.split("/") if p]
            # parts: ['covers', '{manga_id}', '{filename}']
            if len(parts) >= 3:
                manga_id = parts[1]
                filename = parts[2]
                if manga_id.startswith("local_"):
                    self.serve_local_cover(manga_id)
                    return
                elif manga_id.startswith("ia_"):
                    ident = manga_id[3:]
                    self.serve_ia_cover(ident)
                    return
                else:
                    # Portada normal de MangaDex
                    clean_fn = filename.replace(".256.jpg", "").replace(".512.jpg", "")
                    target_url = f"https://uploads.mangadex.org/covers/{manga_id}/{clean_fn}"
                    self.handle_image_proxy(target_url)
                    return

        # 3. Paginas de comics: /comic-page/data/{hash}/{filename}
        if path.startswith("/comic-page/"):
            # path: /comic-page/data/{chapter_hash}/{page_file}
            parts = [p for p in path.split("/") if p]
            if len(parts) >= 4:
                chapter_hash = parts[2]
                page_file = parts[3]
                if chapter_hash.startswith("local_ch_"):
                    self.serve_local_page(chapter_hash, page_file)
                    return
                else:
                    self.serve_ia_page(chapter_hash, page_file)
                    return

        # 4. Proxy de paginas de capitulo MangaDex: /manga-page?base=...&sub=...
        if path == "/manga-page":
            base = params.get("base", [None])[0]
            sub = params.get("sub", [""])[0]
            if base:
                full_url = f"{base}{sub}"
                self.handle_image_proxy(full_url)
                return

        # 5. Obtener paginas de capitulo: /at-home/server/{chapterId}
        if path.startswith("/at-home/server/"):
            chapter_id = path.replace("/at-home/server/", "").strip("/")
            if chapter_id.startswith("local_"):
                self.serve_local_chapter_server(chapter_id)
                return
            elif chapter_id.startswith("ia_"):
                self.serve_ia_chapter_server(chapter_id)
                return
            else:
                target_api_url = f"https://api.mangadex.org{path}"
                self.handle_api_proxy(target_api_url)
                return

        # 6. Lista de capitulos: /manga/{id}/feed
        if "/feed" in path and path.startswith("/manga/"):
            manga_id = path.replace("/manga/", "").split("/feed")[0].strip("/")
            if manga_id.startswith("local_"):
                self.serve_local_feed(manga_id)
                return
            elif manga_id.startswith("ia_"):
                ident = manga_id[3:]
                self.serve_ia_feed(ident)
                return
            else:
                target_api_url = f"https://api.mangadex.org{path}"
                if query:
                    target_api_url += f"?{query}"
                self.handle_api_proxy(target_api_url)
                return

        # 7. Busqueda o Feed Principal: /manga
        if path == "/manga":
            title_query = params.get("title", [None])[0]
            if title_query:
                # Busqueda activa del usuario (ej: watchmen, batman, naruto)
                self.handle_combined_search(title_query, query)
                return
            else:
                # Pantalla principal (lista popular / recientes)
                self.handle_combined_frontpage(query)
                return

        # 8. Cualquier otro endpoint MangaDex
        target_api_url = f"https://api.mangadex.org{path}"
        if query:
            target_api_url += f"?{query}"
        self.handle_api_proxy(target_api_url)

    def serve_local_feed(self, manga_id):
        # manga_id: local_{encoded_name} o local_cbz_{encoded_name}
        is_single_cbz = manga_id.startswith("local_cbz_")
        encoded_name = manga_id.replace("local_cbz_", "").replace("local_", "")
        entry_name = urllib.parse.unquote(encoded_name)
        target_path = os.path.join(COMICS_DIR, entry_name)

        chapters = []
        if is_single_cbz or target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
            chapters.append({
                "id": f"local_ch_{encoded_name}",
                "type": "chapter",
                "attributes": {
                    "volume": "1",
                    "chapter": "1",
                    "title": os.path.splitext(entry_name)[0],
                    "translatedLanguage": "es",
                    "pages": 35
                },
                "relationships": []
            })
        elif os.path.isdir(target_path):
            files = sorted(os.listdir(target_path))
            cbz_files = [f for f in files if f.lower().endswith(".cbz") or f.lower().endswith(".zip")]
            sub_dirs = [f for f in files if os.path.isdir(os.path.join(target_path, f))]

            if cbz_files:
                for idx, cbz in enumerate(cbz_files, 1):
                    ch_id = f"local_ch_{encoded_name}__file__{urllib.parse.quote(cbz)}"
                    chapters.append({
                        "id": ch_id,
                        "type": "chapter",
                        "attributes": {
                            "volume": "1",
                            "chapter": str(idx),
                            "title": os.path.splitext(cbz)[0],
                            "translatedLanguage": "es",
                            "pages": 35
                        },
                        "relationships": []
                    })
            elif sub_dirs:
                for idx, sub in enumerate(sub_dirs, 1):
                    ch_id = f"local_ch_{encoded_name}__dir__{urllib.parse.quote(sub)}"
                    chapters.append({
                        "id": ch_id,
                        "type": "chapter",
                        "attributes": {
                            "volume": "1",
                            "chapter": str(idx),
                            "title": sub,
                            "translatedLanguage": "es",
                            "pages": 35
                        },
                        "relationships": []
                    })
            else:
                chapters.append({
                    "id": f"local_ch_{encoded_name}__root",
                    "type": "chapter",
                    "attributes": {
                        "volume": "1",
                        "chapter": "1",
                        "title": entry_name,
                        "translatedLanguage": "es",
                        "pages": len([f for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png'))])
                    },
                    "relationships": []
                })

        resp = {
            "result": "ok",
            "response": "collection",
            "data": chapters,
            "limit": len(chapters),
            "offset": 0,
            "total": len(chapters)
        }
        data = json.dumps(resp).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def serve_local_chapter_server(self, chapter_id):
        # chapter_id: local_ch_{encoded_name} o con __file__ / __dir__
        parts = chapter_id.split("__")
        main_entry = urllib.parse.unquote(parts[0].replace("local_ch_", ""))
        target_path = os.path.join(COMICS_DIR, main_entry)

        image_names = []
        if len(parts) >= 3 and parts[1] == "file":
            cbz_name = urllib.parse.unquote(parts[2])
            cbz_path = os.path.join(target_path, cbz_name)
            if os.path.exists(cbz_path):
                with zipfile.ZipFile(cbz_path, "r") as z:
                    image_names = sorted([n for n in z.namelist() if n.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))])
        elif target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
            if os.path.exists(target_path):
                with zipfile.ZipFile(target_path, "r") as z:
                    image_names = sorted([n for n in z.namelist() if n.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))])
        elif len(parts) >= 3 and parts[1] == "dir":
            sub_dir = urllib.parse.unquote(parts[2])
            dir_path = os.path.join(target_path, sub_dir)
            if os.path.exists(dir_path):
                image_names = sorted([n for n in os.listdir(dir_path) if n.lower().endswith(('.jpg', '.jpeg', '.png'))])
        elif os.path.isdir(target_path):
            image_names = sorted([n for n in os.listdir(target_path) if n.lower().endswith(('.jpg', '.jpeg', '.png'))])

        if not image_names:
            image_names = [f"{i:03d}.jpg" for i in range(1, 36)]

        resp = {
            "result": "ok",
            "baseUrl": f"http://{LOCAL_IP}:{PORT}/comic-page",
            "chapter": {
                "hash": chapter_id,
                "data": image_names,
                "dataSaver": image_names
            }
        }
        data = json.dumps(resp).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def serve_local_cover(self, manga_id):
        encoded_name = manga_id.replace("local_cbz_", "").replace("local_", "")
        entry_name = urllib.parse.unquote(encoded_name)
        target_path = os.path.join(COMICS_DIR, entry_name)

        img_bytes = None
        if os.path.isdir(target_path):
            cov_path = os.path.join(target_path, "cover.jpg")
            if os.path.exists(cov_path):
                with open(cov_path, "rb") as f:
                    img_bytes = f.read()
        elif target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
            if os.path.exists(target_path):
                with zipfile.ZipFile(target_path, "r") as z:
                    imgs = sorted([n for n in z.namelist() if n.lower().endswith(('.jpg', '.jpeg', '.png'))])
                    if imgs:
                        img_bytes = z.read(imgs[0])

        if img_bytes:
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(img_bytes)))
            self.end_headers()
            self.wfile.write(img_bytes)
        else:
            self.send_error(404, "Portada no disponible")

    def serve_ia_cover(self, identifier):
        cache_file = os.path.join(CACHE_DIR, f"cov_{identifier}.jpg")
        if os.path.exists(cache_file):
            try:
                with open(cache_file, "rb") as f:
                    data = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            except Exception:
                pass

        cover_url = f"https://archive.org/services/img/{identifier}"
        self.handle_image_proxy(cover_url, cache_path=cache_file)

    def serve_ia_feed(self, identifier):
        chapters = get_ia_chapters(identifier)
        resp = {
            "result": "ok",
            "response": "collection",
            "data": chapters,
            "limit": len(chapters),
            "offset": 0,
            "total": len(chapters)
        }
        data = json.dumps(resp).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def serve_ia_chapter_server(self, chapter_id):
        # Generar lista de paginas (35 paginas por capitulo por defecto)
        page_names = [f"n{p}.jpg" for p in range(35)]
        resp = {
            "result": "ok",
            "baseUrl": f"http://{LOCAL_IP}:{PORT}/comic-page",
            "chapter": {
                "hash": chapter_id,
                "data": page_names,
                "dataSaver": page_names
            }
        }
        data = json.dumps(resp).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def serve_local_page(self, chapter_hash, page_file):
        parts = chapter_hash.split("__")
        main_entry = urllib.parse.unquote(parts[0].replace("local_ch_", ""))
        target_path = os.path.join(COMICS_DIR, main_entry)

        img_bytes = None
        if len(parts) >= 3 and parts[1] == "file":
            cbz_name = urllib.parse.unquote(parts[2])
            cbz_path = os.path.join(target_path, cbz_name)
            if os.path.exists(cbz_path):
                with zipfile.ZipFile(cbz_path, "r") as z:
                    if page_file in z.namelist():
                        img_bytes = z.read(page_file)
        elif target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
            if os.path.exists(target_path):
                with zipfile.ZipFile(target_path, "r") as z:
                    if page_file in z.namelist():
                        img_bytes = z.read(page_file)
        elif len(parts) >= 3 and parts[1] == "dir":
            sub_dir = urllib.parse.unquote(parts[2])
            img_path = os.path.join(target_path, sub_dir, page_file)
            if os.path.exists(img_path):
                with open(img_path, "rb") as f:
                    img_bytes = f.read()
        elif os.path.isdir(target_path):
            img_path = os.path.join(target_path, page_file)
            if os.path.exists(img_path):
                with open(img_path, "rb") as f:
                    img_bytes = f.read()

        if img_bytes:
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(img_bytes)))
            self.send_header("Cache-Control", "public, max-age=86400")
            self.end_headers()
            self.wfile.write(img_bytes)
        else:
            self.send_error(404, f"Página local no encontrada: {page_file}")

    def serve_ia_page(self, chapter_hash, page_file):
        # chapter_hash formato: ia__{ident}__sub__{idx}__{pdf} o ia__{ident}__full
        parts = chapter_hash.split("__")
        if len(parts) < 2:
            self.send_error(404, "Comic no encontrado")
            return

        ident = parts[1]

        # Si hay sub-capitulo (ej: Watchmen 02), calcular offset de paginas
        page_num_match = re.search(r"n(\d+)", page_file)
        page_num = int(page_num_match.group(1)) if page_num_match else 0

        sub_idx = 0
        if len(parts) >= 4 and parts[2] == "sub":
            try:
                sub_idx = int(parts[3])
            except Exception:
                sub_idx = 0

        actual_page = (sub_idx * 35) + page_num
        target_url = f"https://archive.org/download/{ident}/page/n{actual_page}.jpg"
        self.handle_image_proxy(target_url)

    def handle_combined_search(self, title_query, raw_query):
        # 1. Buscar en Internet Archive
        western_results = search_internet_archive(title_query)

        # 2. Buscar en MangaDex
        mangadex_results = []
        try:
            target_url = f"https://api.mangadex.org/manga?{raw_query}"
            req = urllib.request.Request(target_url, headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/json"
            })
            with urllib.request.urlopen(req, timeout=6) as res:
                body = res.read()
                md_json = json.loads(body.decode("utf-8"))
                mangadex_results = md_json.get("data", [])
        except Exception as e:
            print(f"[MangaDex search failed] {e}")

        # 3. Combinar: Cómics occidentales primero si hubo búsqueda explícita de ellos
        combined_data = western_results + mangadex_results

        resp = {
            "result": "ok",
            "response": "collection",
            "data": combined_data,
            "limit": len(combined_data),
            "offset": 0,
            "total": len(combined_data)
        }
        data = json.dumps(resp).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_combined_frontpage(self, raw_query):
        # 1. Cargar comics locales descargados
        local_items = get_local_comics()

        # 2. Cargar comics occidentales populares online
        western_popular = [
            make_mangadex_manga_obj(c["id"], c["title"], c["desc"], c["ident"])
            for c in POPULAR_WESTERN
        ]

        # 3. Cargar lista de MangaDex
        mangadex_data = []
        try:
            target_url = f"https://api.mangadex.org/manga?{raw_query}"
            req = urllib.request.Request(target_url, headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/json"
            })
            with urllib.request.urlopen(req, timeout=6) as res:
                body = res.read()
                md_json = json.loads(body.decode("utf-8"))
                mangadex_data = md_json.get("data", [])
        except Exception as e:
            print(f"[MangaDex frontpage error] {e}")

        combined = local_items + western_popular + mangadex_data
        resp = {
            "result": "ok",
            "response": "collection",
            "data": combined,
            "limit": len(combined),
            "offset": 0,
            "total": len(combined)
        }
        data = json.dumps(resp).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

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
                    json_obj = json.loads(data.decode("utf-8"))
                    # Reescribir baseUrl de capitulos MangaDex para redirigir por HTTP
                    if "baseUrl" in json_obj and isinstance(json_obj["baseUrl"], str):
                        original_base = json_obj["baseUrl"]
                        json_obj["_originalBaseUrl"] = original_base
                        json_obj["baseUrl"] = f"http://{LOCAL_IP}:{PORT}/manga-page?base={urllib.parse.quote(original_base)}&sub="

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

    def handle_image_proxy(self, image_url, cache_path=None):
        if not cache_path:
            safe_name = urllib.parse.quote(image_url, safe="")[:120] + ".cache"
            cache_path = os.path.join(CACHE_DIR, safe_name)

        if os.path.exists(cache_path):
            try:
                with open(cache_path, "rb") as f:
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
                "Referer": "https://archive.org/"
            })
            with urllib.request.urlopen(req, timeout=20) as res:
                img_data = res.read()
                c_type = res.headers.get("Content-Type", "image/jpeg")

                try:
                    with open(cache_path, "wb") as f:
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

def start_listener(port):
    try:
        server = ThreadedHTTPServer(("0.0.0.0", port), ComicoProxyHandler)
        server.serve_forever()
    except Exception as e:
        pass

def main():
    import threading
    ip = LOCAL_IP

    # Iniciar escuchas en paralelo en puerto 80 y 8080
    t80 = threading.Thread(target=start_listener, args=(80,), daemon=True)
    t80.start()
    t8080 = threading.Thread(target=start_listener, args=(8080,), daemon=True)
    t8080.start()

    time.sleep(0.3)

    print("=" * 68)
    print("   🚀 SERVIDOR PROXY COMICO & COMICS OCCIDENTALES (iOS 9)")
    print("=" * 68)
    print(f"  Dirección en tu red Wi-Fi: 👉 http://{ip}")
    print(f"  Puerto alternativo:        👉 http://{ip}:8080")
    print(f"  Host local Bonjour:        👉 http://PCsitaDeLuisII.local")
    print()
    print("  ⭐ Comics occidentales integrados (Watchmen, Batman, Spiderman...)")
    print("  ⭐ MangaDex integrado (Manga japones y coreano sin errores SSL)")
    print("  ⭐ Cache en disco para evitar JetSam OOM en iPad con 512MB RAM")
    print()
    print("  [ACTIVO] Presiona Ctrl+C en cualquier momento para detener.")
    print("=" * 68)

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nServidor detenido.")

if __name__ == "__main__":
    main()
