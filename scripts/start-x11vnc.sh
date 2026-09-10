#!/bin/bash
set -e

PASSWD_FILE="/home/desktopuser/.vnc/passwd"

if [ -s "$PASSWD_FILE" ]; then
    echo "Starting x11vnc with password authentication"
    exec x11vnc -display :0 -rfbport 5900 -rfbauth "$PASSWD_FILE" \
        -shared -forever -xkb
fi

echo "Starting x11vnc without authentication"
exec x11vnc -display :0 -rfbport 5900 -nopw -shared -forever -xkb
