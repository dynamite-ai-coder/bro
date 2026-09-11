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
    for diag_port in 5900 6080 5000 10000; do
        echo "=== DIAG tcpdump port ${diag_port} ==="
        timeout 8 tcpdump -i lo -n -A -s 0 "tcp port ${diag_port} and tcp[13] & 8 != 0" 2>&1 \
            | grep -vE '^tcpdump:|reading from file|listening on' | head -60
    done
    echo "=== DIAG done ==="
) &

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
