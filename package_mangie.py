import os
import sys
import zipfile
import tarfile
import io
import time

base_dir = os.path.dirname(os.path.abspath(__file__))
app_dir = os.path.join(base_dir, "mangabox_app", "Applications", "MangaBox.app")
control_dir = os.path.join(base_dir, "mangabox_app")

# 1. Package IPA: Mangie_iPad_iOS9.ipa
ipa_path = os.path.join(base_dir, "Mangie_iPad_iOS9.ipa")
print(f"Creating IPA at: {ipa_path}")
with zipfile.ZipFile(ipa_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(app_dir):
        for f in files:
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, os.path.dirname(app_dir))
            arcname = os.path.join("Payload", rel_path).replace("\\", "/")
            z.write(full_path, arcname)

print("IPA created successfully. Size:", os.path.getsize(ipa_path), "bytes")

# 2. Package DEB: Mangie_iPad_iOS9.deb
def make_tar_gz(source_entries):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for src_path, arc_name, mode in source_entries:
            if src_path is None or os.path.isdir(src_path):
                t_info = tarfile.TarInfo(name=arc_name)
                t_info.type = tarfile.DIRTYPE
                t_info.mode = mode
                t_info.mtime = int(time.time())
                t_info.uname = "root"
                t_info.gname = "wheel"
                tar.addfile(t_info)
            else:
                with open(src_path, "rb") as f:
                    data = f.read()
                t_info = tarfile.TarInfo(name=arc_name)
                t_info.size = len(data)
                t_info.mode = mode
                t_info.mtime = int(time.time())
                t_info.uname = "root"
                t_info.gname = "wheel"
                tar.addfile(t_info, io.BytesIO(data))
    return buf.getvalue()

# control.tar.gz
control_files = [
    (os.path.join(control_dir, "control"), "./control", 0o644),
    (os.path.join(control_dir, "postinst"), "./postinst", 0o755),
    (os.path.join(control_dir, "postrm"), "./postrm", 0o755),
]
control_gz = make_tar_gz(control_files)

# data.tar.gz
data_entries = [
    (None, "./Applications", 0o755),
    (None, "./Applications/MangaBox.app", 0o755),
    (None, "./Library", 0o755),
    (None, "./Library/LaunchDaemons", 0o755),
    (None, "./var", 0o755),
    (None, "./var/mobile", 0o755),
    (None, "./var/mobile/Documents", 0o755),
    (None, "./var/mobile/Documents/Comics", 0o777),
]

# Add MangaBox.app files
for root, dirs, files in os.walk(app_dir):
    for d in dirs:
        p = os.path.join(root, d)
        rel = os.path.relpath(p, os.path.join(base_dir, "mangabox_app")).replace("\\", "/")
        data_entries.append((p, f"./{rel}", 0o755))
    for f in files:
        p = os.path.join(root, f)
        rel = os.path.relpath(p, os.path.join(base_dir, "mangabox_app")).replace("\\", "/")
        mode = 0o755 if f in ("MangaBox", "start_daemon.sh", "comico_daemon.py") else 0o644
        data_entries.append((p, f"./{rel}", mode))

# Add LaunchDaemon plist
plist_src = os.path.join(base_dir, "mangabox_app", "Library", "LaunchDaemons", "com.comico.daemon.plist")
if os.path.exists(plist_src):
    data_entries.append((plist_src, "./Library/LaunchDaemons/com.comico.daemon.plist", 0o644))

data_gz = make_tar_gz(data_entries)

# Build AR archive for .deb
deb_path = os.path.join(base_dir, "Mangie_iPad_iOS9.deb")
debian_binary = b"2.0\n"

def ar_header(name, size):
    mtime = str(int(time.time())).encode('ascii')
    name_bytes = name.encode('ascii')
    return (
        name_bytes.ljust(16) +
        mtime.ljust(12) +
        b"0".ljust(6) +
        b"0".ljust(6) +
        b"100644".ljust(8) +
        str(size).encode('ascii').ljust(10) +
        b"`\n"
    )

with open(deb_path, "wb") as deb:
    deb.write(b"!<arch>\n")
    
    # 1. debian-binary
    deb.write(ar_header("debian-binary", len(debian_binary)))
    deb.write(debian_binary)
    if len(debian_binary) % 2 != 0: deb.write(b"\n")
    
    # 2. control.tar.gz
    deb.write(ar_header("control.tar.gz", len(control_gz)))
    deb.write(control_gz)
    if len(control_gz) % 2 != 0: deb.write(b"\n")
    
    # 3. data.tar.gz
    deb.write(ar_header("data.tar.gz", len(data_gz)))
    deb.write(data_gz)
    if len(data_gz) % 2 != 0: deb.write(b"\n")

print(f"DEB created successfully: {deb_path}. Size:", os.path.getsize(deb_path), "bytes")
