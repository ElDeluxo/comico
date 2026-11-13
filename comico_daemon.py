#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Comico Daemon para iOS 9 (Universal Python 2.7 y Python 3)
Corre como LaunchDaemon local en el iPad en 127.0.0.1:8080
"""

import sys
import os
import re
import socket
import zipfile
import time

# Compatibilidad Python 2 / Python 3
if sys.version_info[0] >= 3:
    from http.server import HTTPServer, BaseHTTPRequestHandler
    from socketserver import ThreadingMixIn
    import urllib.request as urllib_request
    import urllib.parse as urllib_parse
    import json
    url_unquote = urllib_parse.unquote
    url_quote = urllib_parse.quote
    url_parse = urllib_parse.urlparse
    parse_qs = urllib_parse.parse_qs
else:
    from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
    from SocketServer import ThreadingMixIn
    import urllib2 as urllib_request
    import urllib as urllib_parse
    import urlparse
    import json
    url_unquote = urllib_parse.unquote
    url_quote = urllib_parse.quote
    url_parse = urlparse.urlparse
    parse_qs = urlparse.parse_qs

PORT = 8080

# Rutas en iOS
DOCS_DIR = "/var/mobile/Documents/Comics"
APP_COMICS_DIR = "/Applications/MangaBox.app/comics"
CACHE_DIR = "/var/mobile/Library/Caches/comico_cache"

# Si corre en PC para pruebas, usar carpetas locales
if not os.path.exists("/var/mobile"):
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    DOCS_DIR = os.path.join(BASE_DIR, "comics")
    APP_COMICS_DIR = os.path.join(BASE_DIR, "comics")
    CACHE_DIR = os.path.join(BASE_DIR, "image_cache")

for d in [DOCS_DIR, CACHE_DIR]:
    try:
        if not os.path.exists(d):
            os.makedirs(d)
    except Exception:
        pass

USER_AGENT = "ComicoNativeDaemon/2.0 (iPad; iOS 9.3; Standalone)"

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
                        "name": {"en": "Comic"},
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
                "id": "cov_" + str(comic_id),
                "type": "cover_art",
                "attributes": {
                    "fileName": str(cover_ident) + ".cover"
                }
            },
            {
                "id": "auth_western",
                "type": "author",
                "attributes": {
                    "name": "Local/Archive"
                }
            }
        ]
    }

def get_local_offline_comics():
    local_items = []
    folders_to_check = [DOCS_DIR, APP_COMICS_DIR]
    seen = set()

    for folder in folders_to_check:
        if not os.path.exists(folder):
            continue
        try:
            entries = os.listdir(folder)
        except Exception:
            continue

        for entry in entries:
            if entry in seen:
                continue
            seen.add(entry)
            entry_path = os.path.join(folder, entry)

            if os.path.isdir(entry_path):
                comic_id = "local_" + url_quote(entry)
                desc = "Comic instalado localmente en tu iPad (Lectura sin conexion)."
                local_items.append(make_mangadex_manga_obj(comic_id, u"[Offline] " + entry, desc, entry))
            elif entry.lower().endswith(".cbz") or entry.lower().endswith(".zip") or entry.lower().endswith(".cbr"):
                clean_name = os.path.splitext(entry)[0]
                comic_id = "local_cbz_" + url_quote(entry)
                desc = "Archivo CBZ instalado en la memoria del iPad."
                local_items.append(make_mangadex_manga_obj(comic_id, u"[Offline] " + clean_name, desc, entry))

    return local_items

def search_internet_archive(query):
    try:
        search_q = "title:(" + str(query) + ") AND mediatype:(texts) AND -collection:(inlibrary)"
        url = "https://archive.org/advancedsearch.php?q=" + url_quote(search_q) + "&fl[]=identifier,title,downloads,description&sort[]=downloads+desc&output=json&rows=15"
        req = urllib_request.Request(url, headers={"User-Agent": USER_AGENT})
        r = urllib_request.urlopen(req, timeout=6)
        content = r.read().decode("utf-8")
        docs = json.loads(content).get("response", {}).get("docs", [])
        results = []
        for d in docs:
            ident = d.get("identifier")
            title = d.get("title", ident)
            desc = d.get("description", "Comic Occidental alojado en Digital Archive")
            if isinstance(desc, list):
                desc = " ".join(desc)
            results.append(make_mangadex_manga_obj("ia_" + str(ident), title, desc, ident))
        return results
    except Exception as e:
        return []

def get_ia_chapters(identifier):
    url = "https://archive.org/metadata/" + str(identifier)
    req = urllib_request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        r = urllib_request.urlopen(req, timeout=6)
        data = json.loads(r.read().decode("utf-8"))
        files = data.get("files", [])
        chapters = []

        pdf_files = []
        for f in files:
            name = f.get("name", "")
            if name.endswith(".pdf") and not name.endswith("_text.pdf"):
                pdf_files.append(name)

        if len(pdf_files) > 1:
            pdf_files.sort()
            for idx, pdf in enumerate(pdf_files, 1):
                ch_title = pdf.replace(".pdf", "")
                chapters.append({
                    "id": "ia__" + str(identifier) + "__sub__" + str(idx-1) + "__" + url_quote(pdf),
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
            image_count = data.get("metadata", {}).get("imagecount", 35)
            try: image_count = int(image_count)
            except Exception: image_count = 35

            chapters.append({
                "id": "ia__" + str(identifier) + "__full",
                "type": "chapter",
                "attributes": {
                    "volume": "1",
                    "chapter": "1",
                    "title": data.get("metadata", {}).get("title", "Edicion Completa"),
                    "translatedLanguage": "en",
                    "pages": image_count
                },
                "relationships": []
            })
        return chapters
    except Exception as e:
        return [{
            "id": "ia__" + str(identifier) + "__default",
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

class ComicoDaemonHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass # Silencioso en iPad para ahorrar ciclos de CPU y batería

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def do_GET(self):
        parsed = url_parse(self.path)
        path = parsed.path
        query = parsed.query
        params = parse_qs(query)

        # 1. Ping / Health check
        if path in ("/", "/ping"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            payload = json.dumps({"status": "ok", "service": "Comico iPad Native Daemon"})
            self.wfile.write(payload.encode("utf-8"))
            return

        # 2. Portadas: /covers/{manga_id}/{filename}
        if path.startswith("/covers/"):
            parts = [p for p in path.split("/") if p]
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
                    clean_fn = filename.replace(".256.jpg", "").replace(".512.jpg", "")
                    target_url = "https://uploads.mangadex.org/covers/" + str(manga_id) + "/" + str(clean_fn)
                    self.handle_image_proxy(target_url)
                    return

        # 3. Paginas de comics: /comic-page/data/{hash}/{filename}
        if path.startswith("/comic-page/"):
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

        # 4. Proxy de paginas de MangaDex: /manga-page
        if path == "/manga-page":
            base = params.get("base", [None])[0]
            sub = params.get("sub", [""])[0]
            if base:
                self.handle_image_proxy(str(base) + str(sub))
                return

        # 5. Manifest de paginas de capitulo: /at-home/server/{chapterId}
        if path.startswith("/at-home/server/"):
            chapter_id = path.replace("/at-home/server/", "").strip("/")
            if chapter_id.startswith("local_"):
                self.serve_local_chapter_server(chapter_id)
                return
            elif chapter_id.startswith("ia_"):
                self.serve_ia_chapter_server(chapter_id)
                return
            else:
                target_api_url = "https://api.mangadex.org" + str(path)
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
                target_api_url = "https://api.mangadex.org" + str(path)
                if query:
                    target_api_url += "?" + str(query)
                self.handle_api_proxy(target_api_url)
                return

        # 7. Busqueda o Feed Principal: /manga
        if path == "/manga":
            title_query = params.get("title", [None])[0]
            if title_query:
                self.handle_combined_search(title_query, query)
                return
            else:
                self.handle_combined_frontpage(query)
                return

        # 8. Cualquier otro endpoint MangaDex
        target_api_url = "https://api.mangadex.org" + str(path)
        if query:
            target_api_url += "?" + str(query)
        self.handle_api_proxy(target_api_url)

    def serve_local_cover(self, manga_id):
        encoded_name = manga_id.replace("local_cbz_", "").replace("local_", "")
        entry_name = url_unquote(encoded_name)

        target_path = None
        for base in [DOCS_DIR, APP_COMICS_DIR]:
            p = os.path.join(base, entry_name)
            if os.path.exists(p):
                target_path = p
                break

        img_bytes = None
        if target_path:
            if os.path.isdir(target_path):
                cov_path = os.path.join(target_path, "cover.jpg")
                if os.path.exists(cov_path):
                    with open(cov_path, "rb") as f:
                        img_bytes = f.read()
            elif target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
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
            self.send_error(404, "Portada local no encontrada")

    def serve_local_feed(self, manga_id):
        is_single_cbz = manga_id.startswith("local_cbz_")
        encoded_name = manga_id.replace("local_cbz_", "").replace("local_", "")
        entry_name = url_unquote(encoded_name)

        target_path = None
        for base in [DOCS_DIR, APP_COMICS_DIR]:
            p = os.path.join(base, entry_name)
            if os.path.exists(p):
                target_path = p
                break

        chapters = []
        if target_path:
            if is_single_cbz or target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
                chapters.append({
                    "id": "local_ch_" + encoded_name,
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
                if cbz_files:
                    for idx, cbz in enumerate(cbz_files, 1):
                        ch_id = "local_ch_" + encoded_name + "__file__" + url_quote(cbz)
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
                else:
                    chapters.append({
                        "id": "local_ch_" + encoded_name + "__root",
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
        parts = chapter_id.split("__")
        main_entry = url_unquote(parts[0].replace("local_ch_", ""))

        target_path = None
        for base in [DOCS_DIR, APP_COMICS_DIR]:
            p = os.path.join(base, main_entry)
            if os.path.exists(p):
                target_path = p
                break

        image_names = []
        if target_path:
            if len(parts) >= 3 and parts[1] == "file":
                cbz_name = url_unquote(parts[2])
                cbz_path = os.path.join(target_path, cbz_name)
                if os.path.exists(cbz_path):
                    with zipfile.ZipFile(cbz_path, "r") as z:
                        image_names = sorted([n for n in z.namelist() if n.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))])
            elif target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
                with zipfile.ZipFile(target_path, "r") as z:
                    image_names = sorted([n for n in z.namelist() if n.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))])
            elif os.path.isdir(target_path):
                image_names = sorted([n for n in os.listdir(target_path) if n.lower().endswith(('.jpg', '.jpeg', '.png'))])

        if not image_names:
            image_names = [str(i).zfill(3) + ".jpg" for i in range(1, 36)]

        resp = {
            "result": "ok",
            "baseUrl": "http://127.0.0.1:8080/comic-page",
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

    def serve_local_page(self, chapter_hash, page_file):
        parts = chapter_hash.split("__")
        main_entry = url_unquote(parts[0].replace("local_ch_", ""))

        target_path = None
        for base in [DOCS_DIR, APP_COMICS_DIR]:
            p = os.path.join(base, main_entry)
            if os.path.exists(p):
                target_path = p
                break

        img_bytes = None
        if target_path:
            if len(parts) >= 3 and parts[1] == "file":
                cbz_name = url_unquote(parts[2])
                cbz_path = os.path.join(target_path, cbz_name)
                if os.path.exists(cbz_path):
                    with zipfile.ZipFile(cbz_path, "r") as z:
                        if page_file in z.namelist():
                            img_bytes = z.read(page_file)
            elif target_path.lower().endswith(".cbz") or target_path.lower().endswith(".zip"):
                with zipfile.ZipFile(target_path, "r") as z:
                    if page_file in z.namelist():
                        img_bytes = z.read(page_file)
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
            self.send_error(404, "Pagina local no encontrada")

    def serve_ia_cover(self, identifier):
        cache_file = os.path.join(CACHE_DIR, "cov_" + str(identifier) + ".jpg")
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
        cover_url = "https://archive.org/services/img/" + str(identifier)
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
        page_names = ["n" + str(p) + ".jpg" for p in range(35)]
        resp = {
            "result": "ok",
            "baseUrl": "http://127.0.0.1:8080/comic-page",
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

    def serve_ia_page(self, chapter_hash, page_file):
        parts = chapter_hash.split("__")
        if len(parts) < 2:
            self.send_error(404, "Comic no encontrado")
            return

        ident = parts[1]
        page_num_match = re.search(r"n(\d+)", page_file)
        page_num = int(page_num_match.group(1)) if page_num_match else 0

        sub_idx = 0
        if len(parts) >= 4 and parts[2] == "sub":
            try: sub_idx = int(parts[3])
            except Exception: sub_idx = 0

        actual_page = (sub_idx * 35) + page_num
        target_url = "https://archive.org/download/" + str(ident) + "/page/n" + str(actual_page) + ".jpg"
        self.handle_image_proxy(target_url)

    def handle_combined_search(self, title_query, raw_query):
        # 1. Comics locales
        local_results = []
        q_lower = title_query.lower()
        for c in get_local_offline_comics():
            title = c.get("attributes", {}).get("title", {}).get("en", "").lower()
            if q_lower in title:
                local_results.append(c)

        # 2. Internet Archive (Western)
        western_results = search_internet_archive(title_query)

        # 3. MangaDex
        mangadex_results = []
        try:
            target_url = "https://api.mangadex.org/manga?" + str(raw_query)
            req = urllib_request.Request(target_url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            res = urllib_request.urlopen(req, timeout=5)
            md_json = json.loads(res.read().decode("utf-8"))
            mangadex_results = md_json.get("data", [])
        except Exception:
            pass

        combined_data = local_results + western_results + mangadex_results
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
        # 1. Comics guardados en el iPad (Offline)
        local_items = get_local_offline_comics()

        # 2. Comics occidentales populares
        western_popular = [
            make_mangadex_manga_obj(c["id"], c["title"], c["desc"], c["ident"])
            for c in POPULAR_WESTERN
        ]

        # 3. MangaDex
        mangadex_data = []
        try:
            target_url = "https://api.mangadex.org/manga?" + str(raw_query)
            req = urllib_request.Request(target_url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            res = urllib_request.urlopen(req, timeout=5)
            md_json = json.loads(res.read().decode("utf-8"))
            mangadex_data = md_json.get("data", [])
        except Exception:
            pass

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
            req = urllib_request.Request(target_url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            res = urllib_request.urlopen(req, timeout=10)
            data = res.read()
            c_type = res.headers.get("Content-Type", "application/json")
            try:
                json_obj = json.loads(data.decode("utf-8"))
                if "baseUrl" in json_obj and isinstance(json_obj["baseUrl"], str):
                    orig = json_obj["baseUrl"]
                    json_obj["baseUrl"] = "http://127.0.0.1:8080/manga-page?base=" + url_quote(orig) + "&sub="
                data = json.dumps(json_obj).encode("utf-8")
            except Exception:
                pass
            self.send_response(200)
            self.send_header("Content-Type", c_type)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))

    def handle_image_proxy(self, image_url, cache_path=None):
        if not cache_path:
            safe_name = url_quote(image_url, safe="")[:120] + ".cache"
            cache_path = os.path.join(CACHE_DIR, safe_name)

        if os.path.exists(cache_path):
            try:
                with open(cache_path, "rb") as f:
                    data = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                self.wfile.write(data)
                return
            except Exception:
                pass

        try:
            req = urllib_request.Request(image_url, headers={"User-Agent": USER_AGENT, "Referer": "https://archive.org/"})
            res = urllib_request.urlopen(req, timeout=15)
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
            self.send_error(502, "Error descargando imagen: " + str(e))

def main():
    server = ThreadedHTTPServer(("127.0.0.1", PORT), ComicoDaemonHandler)
    server.serve_forever()

if __name__ == "__main__":
    main()

