#!/bin/bash
set -e

PASSWD_FILE="/home/desktopuser/.vnc/passwd"
LOG_FILE="/var/log/x11vnc.log"

COMMON_ARGS=(-display :0 -rfbport 5900 -shared -forever -xkb -localhost -o "$LOG_FILE" \
    -threads -wait 1 -defer 1)

if [ -s "$PASSWD_FILE" ]; then
    echo "Starting x11vnc with password authentication (log: $LOG_FILE)"
    exec x11vnc "${COMMON_ARGS[@]}" -rfbauth "$PASSWD_FILE"
fi

echo "Starting x11vnc without authentication (log: $LOG_FILE)"
exec x11vnc "${COMMON_ARGS[@]}" -nopw
