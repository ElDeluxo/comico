#!/usr/bin/env python3
"""
Patcher para Mangie (MangaBox) iPad Edition
Reemplaza los endpoints oficiales de MangaDex por el servidor proxy local Comico.
"""

import os
import sys
import shutil
import socket

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "192.168.0.147"

def patch_binary(target_base_url):
    base_dir = os.path.dirname(os.path.abspath(__file__))
    app_bin = os.path.join(base_dir, "mangabox_app", "Applications", "MangaBox.app", "MangaBox")
    orig_bin = app_bin + ".original"

    if not os.path.exists(orig_bin):
        print(f"Creando respaldo del binario original en {orig_bin}...")
        shutil.copy2(app_bin, orig_bin)

    with open(orig_bin, "rb") as f:
        data = bytearray(f.read())

    # Las 6 URLs y sus offsets conocidos
    targets = [
        # (offset, original_str, new_str)
        (0x6bdd8,
         b"https://api.mangadex.org/manga?order%5BfollowedCount%5D=desc&limit=25&includes%5B%5D=cover_art&includes%5B%5D=author&hasAvailableChapters=true",
         f"{target_base_url}/manga?order%5BfollowedCount%5D=desc&limit=25&includes%5B%5D=cover_art&includes%5B%5D=author&hasAvailableChapters=true".encode()),

        (0x6be67,
         b"https://api.mangadex.org/manga?title=%@&limit=25&includes%%5B%%5D=cover_art&includes%%5B%%5D=author",
         f"{target_base_url}/manga?title=%@&limit=25&includes%%5B%%5D=cover_art&includes%%5B%%5D=author".encode()),

        (0x6bfa6,
         b"https://uploads.mangadex.org/covers/%@/%@.256.jpg",
         f"{target_base_url}/covers/%@/%@.256.jpg".encode()),

        (0x6bfe4,
         b"https://api.mangadex.org/manga/%@/feed?translatedLanguage%%5B%%5D=en&order%%5Bchapter%%5D=asc&limit=60&includeEmptyPages=0",
         f"{target_base_url}/manga/%@/feed?translatedLanguage%%5B%%5D=en&order%%5Bchapter%%5D=asc&limit=60&includeEmptyPages=0".encode()),

        (0x6c05f,
         b"https://api.mangadex.org/manga/%@/feed?order%%5Bchapter%%5D=asc&limit=60&includeEmptyPages=0",
         f"{target_base_url}/manga/%@/feed?order%%5Bchapter%%5D=asc&limit=60&includeEmptyPages=0".encode()),

        (0x6c0fb,
         b"https://api.mangadex.org/at-home/server/%@",
         f"{target_base_url}/at-home/server/%@".encode()),
    ]

    for offset, orig_bytes, new_bytes in targets:
        orig_slot_len = len(orig_bytes)
        if len(new_bytes) > orig_slot_len:
            raise ValueError(f"La nueva URL '{new_bytes.decode()}' excede el tamano original ({len(new_bytes)} > {orig_slot_len})")
        
        # Verificar que el binario contiene la cadena esperada en ese offset
        actual_in_bin = data[offset:offset+orig_slot_len]
        if actual_in_bin != orig_bytes:
            raise ValueError(f"Mismatch en offset 0x{offset:x}: esperado {orig_bytes[:20]}, encontrado {actual_in_bin[:20]}")

        # Rellenar con nulls
        padded_new = new_bytes + (b"\x00" * (orig_slot_len - len(new_bytes)))
        data[offset:offset+orig_slot_len] = padded_new
        print(f"  [OK] Offset 0x{offset:x}: {new_bytes.decode()[:40]}... (rellenado con {orig_slot_len - len(new_bytes)} nulos)")

    with open(app_bin, "wb") as f:
        f.write(data)

    print(f"\nBinario MangaBox parcheado exitosamente para apuntar a: {target_base_url}")

if __name__ == "__main__":
    ip = sys.argv[1] if len(sys.argv) > 1 else get_local_ip()
    target_url = ip if ip.startswith("http") else f"http://{ip}"
    print(f"Parcheando MangaBox con servidor base: {target_url}")
    patch_binary(target_url)

