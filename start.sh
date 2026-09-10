#!/bin/bash
set -e

PORT=${PORT:-8080}
RESOLUTION=${RESOLUTION:-1280x800}
VNC_PASSWORD=${VNC_PASSWORD:-""}
USER=${USER:-desktopuser}

echo "Starting remote desktop environment..."
echo "Resolution: $RESOLUTION"
echo "Port: $PORT"

cleanup() {
    echo "Shutting down..."
    kill $(jobs -p) 2>/dev/null || true
    pkill -f Xvfb 2>/dev/null || true
    pkill -f x11vnc 2>/dev/null || true
    pkill -f websockify 2>/dev/null || true
    pkill -f supervisord 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

Xvfb :0 -screen 0 $RESOLUTION -ac +extension GLX +render -noreset &

sleep 2

export DISPLAY=:0

if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /home/$USER/.vnc
    x11vnc -storepasswd "$VNC_PASSWORD" /home/$USER/.vnc/passwd
    chown -R $USER:$USER /home/$USER/.vnc
    x11vnc -display :0 -rfbport 5900 -rfbauth /home/$USER/.vnc/passwd -shared -forever -nopw -xkb &
else
    x11vnc -display :0 -rfbport 5900 -shared -forever -nopw -xkb &
fi

sleep 1

su - $USER -c "DISPLAY=:0 xfce4-session &" &

sleep 3

websockify --web /usr/share/novnc/ $PORT localhost:5900 &

sleep 1

python3 /app.py &

wait
