#!/bin/sh
PYTHON_BIN=""
for p in /usr/bin/python /usr/bin/python3 /usr/bin/python2.7 /usr/local/bin/python /usr/local/bin/python3 /usr/bin/python2; do
    if [ -x "$p" ]; then
        PYTHON_BIN="$p"
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo "Python no encontrado en el sistema" > /var/log/comico_daemon.err
    exit 1
fi

exec "$PYTHON_BIN" /Applications/MangaBox.app/comico_daemon.py

