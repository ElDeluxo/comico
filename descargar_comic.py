#!/usr/bin/env python3
"""
Descargador e Instalador de Cómics y Mangas para Lectura Offline (iOS 9 / iPad)
- Permite buscar y descargar cómics completos (Watchmen, Batman, etc.) y Mangas.
- Empaqueta automáticamente los cómics en formato .CBZ (Comic Book Archive)
  y en carpetas de imágenes optimizadas para iPad.
- Los cómics descargados quedan disponibles en la carpeta 'comics/' para lectura
  sin conexión o transferencia directa al iPad por Filza / iTunes / iBooks.
"""

import os
import sys
import re
import json
import time
import zipfile
import urllib.request
import urllib.parse

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
COMICS_DIR = os.path.join(BASE_DIR, "comics")
CACHE_DIR = os.path.join(BASE_DIR, "image_cache")
os.makedirs(COMICS_DIR, exist_ok=True)
os.makedirs(CACHE_DIR, exist_ok=True)

USER_AGENT = "ComicoDownloader/2.0 (iPad; iOS 9; OfflineManager)"

def print_banner():
    print("=" * 68)
    print("   📥 DESCARGADOR DE CÓMICS Y MANGAS OFFLINE (iPad iOS 9)")
    print("=" * 68)
    print("  Descarga cómics completos para leer cuando no tengas internet.")
    print("  Formato de salida: .CBZ estándar y carpetas de capítulos.")
    print("=" * 68)

def search_comics(query):
    print(f"\n🔍 Buscando cómics occidentales y mangas para: '{query}'...")
    results = []

    # 1. Buscar en Internet Archive (Comics occidentales)
    try:
        search_q = f"title:({query}) AND mediatype:(texts) AND -collection:(inlibrary)"
        url = f"https://archive.org/advancedsearch.php?q={urllib.parse.quote(search_q)}&fl[]=identifier,title,downloads,description&sort[]=downloads+desc&output=json&rows=10"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=8) as r:
            docs = json.loads(r.read().decode("utf-8")).get("response", {}).get("docs", [])
            for d in docs:
                results.append({
                    "source": "Internet Archive (Cómic Occidental)",
                    "id": d.get("identifier"),
                    "title": d.get("title", d.get("identifier")),
                    "type": "ia"
                })
    except Exception as e:
        print(f"  [Aviso] Error en búsqueda de archivo: {e}")

    # 2. Buscar en MangaDex (Manga)
    try:
        url = f"https://api.mangadex.org/manga?title={urllib.parse.quote(query)}&limit=10"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=8) as r:
            mangas = json.loads(r.read().decode("utf-8")).get("data", [])
            for m in mangas:
                title_dict = m.get("attributes", {}).get("title", {})
                title = title_dict.get("en") or title_dict.get("es") or list(title_dict.values())[0]
                results.append({
                    "source": "MangaDex (Manga)",
                    "id": m.get("id"),
                    "title": title,
                    "type": "mangadex"
                })
    except Exception as e:
        print(f"  [Aviso] Error en búsqueda de MangaDex: {e}")

    return results

def download_ia_comic(identifier, comic_title):
    print(f"\nObteniendo información de entrega para: {comic_title}...")
    url = f"https://archive.org/metadata/{identifier}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            meta = json.loads(r.read().decode("utf-8"))
    except Exception as e:
        print(f"Error obteniendo metadatos: {e}")
        return

    files = meta.get("files", [])
    pdf_files = [f.get("name", "") for f in files if f.get("name", "").endswith(".pdf") and not f.get("name", "").endswith("_text.pdf")]
    pdf_files.sort()

    clean_title = re.sub(r'[\\/*?:"<>|]', "", comic_title).strip()
    comic_folder = os.path.join(COMICS_DIR, clean_title)
    os.makedirs(comic_folder, exist_ok=True)

    # Descargar portada
    cover_path = os.path.join(comic_folder, "cover.jpg")
    try:
        cov_url = f"https://archive.org/services/img/{identifier}"
        with urllib.request.urlopen(urllib.request.Request(cov_url, headers={"User-Agent": USER_AGENT}), timeout=10) as r:
            with open(cover_path, "wb") as f:
                f.write(r.read())
        print(f"  Portada guardada en: {cover_path}")
    except Exception:
        pass

    if len(pdf_files) > 1:
        print(f"\nEste título contiene {len(pdf_files)} entregas/capítulos:")
        for idx, pdf in enumerate(pdf_files, 1):
            print(f"  [{idx}] {pdf.replace('.pdf', '')}")

        print("\n¿Qué deseas descargar?")
        print("  [T] Todos los capítulos")
        print("  [1-{}] Un capítulo específico".format(len(pdf_files)))
        choice = input("Selecciona una opción (por defecto T): ").strip().upper()
        if not choice:
            choice = "T"

        if choice == "T":
            selected_indices = list(range(len(pdf_files)))
        else:
            try:
                num = int(choice)
                if 1 <= num <= len(pdf_files):
                    selected_indices = [num - 1]
                else:
                    selected_indices = list(range(len(pdf_files)))
            except ValueError:
                selected_indices = list(range(len(pdf_files)))

        for idx in selected_indices:
            pdf_name = pdf_files[idx]
            issue_title = pdf_name.replace(".pdf", "")
            download_ia_issue(identifier, idx, issue_title, comic_folder)
    else:
        # Tomo único
        download_ia_issue(identifier, 0, clean_title, comic_folder)

    print("\n" + "=" * 68)
    print(f"  🎉 ¡Descarga completada con éxito!")
    print(f"  Carpeta de cómics: 👉 {comic_folder}")
    print("=" * 68)

def download_ia_issue(identifier, sub_idx, issue_title, parent_folder):
    clean_issue = re.sub(r'[\\/*?:"<>|]', "", issue_title).strip()
    cbz_path = os.path.join(parent_folder, f"{clean_issue}.cbz")
    issue_folder = os.path.join(parent_folder, clean_issue)
    os.makedirs(issue_folder, exist_ok=True)

    print(f"\n📥 Descargando páginas de: {issue_title}...")
    page_start = sub_idx * 35
    max_pages = 35

    downloaded_pages = []
    consecutive_errors = 0

    for p in range(max_pages):
        page_num = page_start + p
        page_file = f"n{page_num}.jpg"
        save_file = f"{p+1:03d}.jpg"
        local_path = os.path.join(issue_folder, save_file)

        if os.path.exists(local_path) and os.path.getsize(local_path) > 1000:
            print(f"  Página {p+1}/{max_pages} [Caché local]")
            with open(local_path, "rb") as f:
                downloaded_pages.append((save_file, f.read()))
            continue

        url = f"https://archive.org/download/{identifier}/page/{page_file}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=12) as r:
                data = r.read()
                if len(data) < 1000:
                    consecutive_errors += 1
                    if consecutive_errors >= 2:
                        break
                    continue
                consecutive_errors = 0
                with open(local_path, "wb") as f:
                    f.write(data)
                downloaded_pages.append((save_file, data))
                sys.stdout.write(f"\r  Descargando página {p+1}/{max_pages} ({len(data)//1024} KB)...")
                sys.stdout.flush()
        except Exception as e:
            consecutive_errors += 1
            if consecutive_errors >= 2:
                # Fin de páginas del tomo
                break

    print(f"\n  Empaquetando {len(downloaded_pages)} páginas en {clean_issue}.cbz...")
    with zipfile.ZipFile(cbz_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for name, data in downloaded_pages:
            z.writestr(name, data)

    print(f"  [OK] Archivo CBZ listo: {cbz_path} ({os.path.getsize(cbz_path)//1024} KB)")

def main():
    print_banner()

    query = ""
    if len(sys.argv) > 1:
        query = " ".join(sys.argv[1:])
    else:
        print("Sugerencias populares:")
        print("  1. Watchmen")
        print("  2. Batman The Killing Joke")
        print("  3. Batman The Dark Knight Returns")
        print("  4. V for Vendetta")
        print("  5. Amazing Spider-Man")
        print()
        query = input("Escribe el nombre del cómic o manga a descargar (o número 1-5): ").strip()

    preset_map = {
        "1": "Watchmen",
        "2": "Batman The Killing Joke",
        "3": "Batman The Dark Knight Returns",
        "4": "V for Vendetta",
        "5": "Amazing Spider-Man"
    }
    if query in preset_map:
        query = preset_map[query]

    if not query:
        print("Búsqueda vacía. Cancelando.")
        return

    results = search_comics(query)
    if not results:
        print("No se encontraron resultados para la búsqueda.")
        return

    print("\nResultados encontrados:")
    for idx, r in enumerate(results, 1):
        print(f"  [{idx}] {r['title']}  ({r['source']})")

    choice = input(f"\nSelecciona el cómic a descargar [1-{len(results)}] (por defecto 1): ").strip()
    idx = 0
    if choice.isdigit() and 1 <= int(choice) <= len(results):
        idx = int(choice) - 1

    selected = results[idx]
    if selected["type"] == "ia":
        download_ia_comic(selected["id"], selected["title"])
    else:
        print(f"Descargando manga desde MangaDex: {selected['title']}...")
        # Descarga desde MangaDex
        download_mangadex_manga(selected["id"], selected["title"])

def download_mangadex_manga(manga_id, title):
    clean_title = re.sub(r'[\\/*?:"<>|]', "", title).strip()
    manga_folder = os.path.join(COMICS_DIR, clean_title)
    os.makedirs(manga_folder, exist_ok=True)

    print(f"\nObteniendo lista de capítulos en español / inglés para {title}...")
    url = f"https://api.mangadex.org/manga/{manga_id}/feed?order[chapter]=asc&limit=100"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            chapters = json.loads(r.read().decode("utf-8")).get("data", [])
    except Exception as e:
        print(f"Error obteniendo capítulos: {e}")
        return

    if not chapters:
        print("No se encontraron capítulos disponibles.")
        return

    print(f"Se encontraron {len(chapters)} capítulos disponibles.")
    print("Descargando los primeros 5 capítulos...")

    for c in chapters[:5]:
        ch_attr = c.get("attributes", {})
        ch_num = ch_attr.get("chapter", "1")
        ch_id = c.get("id")
        ch_title = f"Capitulo_{ch_num}"
        download_mangadex_chapter(ch_id, ch_title, manga_folder)

    print("\n" + "=" * 68)
    print(f"  🎉 ¡Descarga completada con éxito!")
    print(f"  Carpeta: 👉 {manga_folder}")
    print("=" * 68)

def download_mangadex_chapter(chapter_id, chapter_title, parent_folder):
    cbz_path = os.path.join(parent_folder, f"{chapter_title}.cbz")
    if os.path.exists(cbz_path):
        print(f"  {chapter_title} ya descargado anteriormente.")
        return

    url = f"https://api.mangadex.org/at-home/server/{chapter_id}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))
            base_url = data.get("baseUrl")
            ch_data = data.get("chapter", {})
            ch_hash = ch_data.get("hash")
            pages = ch_data.get("dataSaver") or ch_data.get("data", [])
    except Exception as e:
        print(f"Error al obtener páginas de {chapter_title}: {e}")
        return

    print(f"  Descargando {len(pages)} páginas de {chapter_title}...")
    downloaded = []
    for idx, p in enumerate(pages, 1):
        img_url = f"{base_url}/data-saver/{ch_hash}/{p}"
        try:
            with urllib.request.urlopen(urllib.request.Request(img_url, headers={"User-Agent": USER_AGENT}), timeout=15) as r:
                downloaded.append((f"{idx:03d}.jpg", r.read()))
        except Exception:
            pass

    if downloaded:
        with zipfile.ZipFile(cbz_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
            for name, img_data in downloaded:
                z.writestr(name, img_data)
        print(f"  [OK] Guardado: {cbz_path}")

if __name__ == "__main__":
    main()
