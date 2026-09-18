#!/bin/bash
set -e

export PORT="${PORT:-8080}"
export RESOLUTION="${RESOLUTION:-1280x800}"
export VNC_PASSWORD="${VNC_PASSWORD:-}"
export INTERNAL_PORT="${INTERNAL_PORT:-5000}"
export NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN:-}"
export RDP_TUNNEL_PORT="${RDP_TUNNEL_PORT:-0}"
export BORE_SECRET="${BORE_SECRET:-}"

if [[ "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
    export RESOLUTION="${RESOLUTION}x24"
fi

echo "Starting remote desktop environment..."
echo "  Port:       ${PORT}"
echo "  Resolution: ${RESOLUTION}"
echo "  VNC port:   5900 (internal, shared XFCE desktop)"
echo "  RDP port:   3389 (xrdp -> x11vnc 5900 -> XFCE desktop)"
echo "  WebSocket:  6080 (internal, noVNC bridge)"

mkdir -p /home/desktopuser/.vnc /home/desktopuser/.config
rm -f /run/rdp-tunnel.txt

if [ -d /data ]; then
    echo "  Disk:       /data attached, user files persist across deploys"
    mkdir -p /data/Desktop /data/Documents /data/Downloads /data/chrome
    cp -f /usr/share/applications/tor-browser.desktop /data/Desktop/
    cp -f /home/desktopuser/.config/autostart/google-chrome.desktop /data/Desktop/
    chmod +x /data/Desktop/*.desktop 2>/dev/null || true
    rm -rf /home/desktopuser/Desktop /home/desktopuser/Documents \
        /home/desktopuser/Downloads /home/desktopuser/.config/google-chrome
    ln -sfn /data/Desktop /home/desktopuser/Desktop
    ln -sfn /data/Documents /home/desktopuser/Documents
    ln -sfn /data/Downloads /home/desktopuser/Downloads
    ln -sfn /data/chrome /home/desktopuser/.config/google-chrome
    chown -R desktopuser:desktopuser /data
else
    echo "  Disk:       no /data volume, user files are ephemeral"
fi

if [ -z "${VNC_PASSWORD}" ]; then
    echo "ERROR: VNC_PASSWORD is not set." >&2
    echo "Set it in the Render dashboard (Environment) or pass -e VNC_PASSWORD=... locally." >&2
    exit 1
fi

RDP_PASSWORD="${VNC_PASSWORD}"
for account in admin desktopuser; do
    if id "${account}" >/dev/null 2>&1; then
        echo "${account}:${RDP_PASSWORD}" | chpasswd
    fi
done
x11vnc -storepasswd "${RDP_PASSWORD}" /home/desktopuser/.vnc/passwd >/dev/null
chown -R desktopuser:desktopuser /home/desktopuser/.vnc
echo "  RDP auth:   user 'admin', password from VNC_PASSWORD (Render env var)"
if [ "${#RDP_PASSWORD}" -gt 8 ]; then
    echo "  Note:       RDP/VNC passwords are truncated to the first 8 characters by the RFB protocol"
fi

echo "  nginx:      listening on port ${PORT}"
sed "s/__PORT__/${PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
