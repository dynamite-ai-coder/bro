#!/bin/bash
set -e

export PORT="${PORT:-8080}"
export RESOLUTION="${RESOLUTION:-1280x800}"
export VNC_PASSWORD="${VNC_PASSWORD:-}"
export INTERNAL_PORT="${INTERNAL_PORT:-5000}"

if [[ "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
    export RESOLUTION="${RESOLUTION}x24"
fi

echo "Starting remote desktop environment..."
echo "  Port:       ${PORT}"
echo "  Resolution: ${RESOLUTION}"
echo "  VNC port:   5900"
echo "  WebSocket:  6080 (internal)"

mkdir -p /home/desktopuser/.vnc /home/desktopuser/.config

if [ -n "${VNC_PASSWORD}" ]; then
    x11vnc -storepasswd "${VNC_PASSWORD}" /home/desktopuser/.vnc/passwd >/dev/null
    echo "  VNC auth:   enabled"
else
    rm -f /home/desktopuser/.vnc/passwd
    echo "  VNC auth:   disabled"
fi
chown -R desktopuser:desktopuser /home/desktopuser/.vnc

echo "  nginx:      listening on port ${PORT}"
sed "s/__PORT__/${PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

(
    sleep 30
    echo "=== DIAG stopping x11vnc to capture probe ==="
    /usr/bin/supervisorctl stop x11vnc >/dev/null 2>&1
    sleep 1
    python3 - << 'PY'
import socket
import time

sock = socket.socket()
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('127.0.0.1', 5900))
sock.listen(5)
sock.settimeout(0.5)
deadline = time.time() + 15
while time.time() < deadline:
    try:
        conn, addr = sock.accept()
    except socket.timeout:
        continue
    conn.settimeout(1.0)
    data = b''
    try:
        data = conn.recv(1024)
    except Exception:
        pass
    print(f'=== DIAG probe from {addr} data={data!r}', flush=True)
    conn.close()
sock.close()
print('=== DIAG tarp done ===', flush=True)
PY
    /usr/bin/supervisorctl start x11vnc >/dev/null 2>&1
    echo "=== DIAG done ==="
) &

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
