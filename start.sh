#!/bin/bash
set -e

export PORT="${PORT:-8080}"
export RESOLUTION="${RESOLUTION:-1280x800}"
export VNC_PASSWORD="${VNC_PASSWORD:-}"

if [[ "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
    export RESOLUTION="${RESOLUTION}x24"
fi

echo "Starting remote desktop environment..."
echo "  Port:       ${PORT}"
echo "  Resolution: ${RESOLUTION}"
echo "  RDP port:   3389 (xrdp -> x11vnc 5900 -> XFCE desktop)"

mkdir -p /home/desktopuser/.vnc /home/desktopuser/.config

RDP_PASSWORD="${VNC_PASSWORD:-Dupa1234@}"
if id admin >/dev/null 2>&1; then
    echo "admin:${RDP_PASSWORD}" | chpasswd
fi
x11vnc -storepasswd "${RDP_PASSWORD}" /home/desktopuser/.vnc/passwd >/dev/null
chown -R desktopuser:desktopuser /home/desktopuser/.vnc
echo "  RDP auth:   user 'admin', password from VNC_PASSWORD"
if [ "${#RDP_PASSWORD}" -gt 8 ]; then
    echo "  Note:       RDP/VNC passwords are truncated to the first 8 characters by the RFB protocol"
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
