#!/bin/bash
set -e

detect_cpu_count() {
    local quota period
    if [ -r /sys/fs/cgroup/cpu.max ]; then
        read -r quota period < /sys/fs/cgroup/cpu.max
        if [ "${quota}" != "max" ] && [ "${period:-0}" -gt 0 ] 2>/dev/null; then
            echo $(( (quota + period - 1) / period ))
            return
        fi
    fi
    if [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
        quota="$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)"
        period="$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)"
        if [ "${quota:-0}" -gt 0 ] 2>/dev/null && [ "${period:-0}" -gt 0 ] 2>/dev/null; then
            echo $(( (quota + period - 1) / period ))
            return
        fi
    fi
    nproc 2>/dev/null || echo 1
}

detect_memory_mb() {
    local limit
    if [ -r /sys/fs/cgroup/memory.max ]; then
        limit="$(cat /sys/fs/cgroup/memory.max)"
    elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)"
    fi
    if [ -n "${limit:-}" ] && [ "${limit}" != "max" ] && [ "${limit}" -gt 0 ] 2>/dev/null; then
        echo $(( limit / 1048576 ))
        return
    fi
    awk '/MemTotal/ {printf "%d\n", $2 / 1024}' /proc/meminfo
}

CPU_COUNT="$(detect_cpu_count)"
[[ "${CPU_COUNT}" =~ ^[0-9]+$ ]] || CPU_COUNT=1
[ "${CPU_COUNT}" -ge 1 ] || CPU_COUNT=1
MEMORY_MB="$(detect_memory_mb)"
[[ "${MEMORY_MB}" =~ ^[0-9]+$ ]] || MEMORY_MB=512
export CPU_COUNT MEMORY_MB
export NGINX_WORKERS="${CPU_COUNT}"

WEB_THREADS=$(( CPU_COUNT * 4 ))
if [ "${WEB_THREADS}" -lt 8 ]; then WEB_THREADS=8; fi
if [ "${WEB_THREADS}" -gt 256 ]; then WEB_THREADS=256; fi
export WEB_THREADS

export OMP_NUM_THREADS="${CPU_COUNT}"
export OPENBLAS_NUM_THREADS="${CPU_COUNT}"
export NUMEXPR_NUM_THREADS="${CPU_COUNT}"
export MKL_NUM_THREADS="${CPU_COUNT}"
export VECLIB_MAXIMUM_THREADS="${CPU_COUNT}"

NOFILE_LIMIT="$(ulimit -Hn 2>/dev/null || true)"
case "${NOFILE_LIMIT}" in
    ''|unlimited) NOFILE_LIMIT=1048576 ;;
esac
[[ "${NOFILE_LIMIT}" =~ ^[0-9]+$ ]] || NOFILE_LIMIT=65535
ulimit -n "${NOFILE_LIMIT}" 2>/dev/null || true
WORKER_CONNECTIONS=$(( NOFILE_LIMIT / 2 ))
if [ "${WORKER_CONNECTIONS}" -gt 8192 ]; then WORKER_CONNECTIONS=8192; fi
if [ "${WORKER_CONNECTIONS}" -lt 1024 ]; then WORKER_CONNECTIONS=1024; fi
export NOFILE_LIMIT WORKER_CONNECTIONS

export PORT="${PORT:-8080}"
export RESOLUTION="${RESOLUTION:-1280x800}"
export VNC_PASSWORD="${VNC_PASSWORD:-}"
export INTERNAL_PORT="${INTERNAL_PORT:-5000}"
export NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN:-}"
export RDP_TUNNEL_PORT="${RDP_TUNNEL_PORT:-0}"
export BORE_SECRET="${BORE_SECRET:-}"
export RDP_WS_PATH="${RDP_WS_PATH:-rdpws}"

RDP_WS_PATH="$(printf '%s' "${RDP_WS_PATH}" | tr -cd 'A-Za-z0-9_-')"
export RDP_WS_PATH="${RDP_WS_PATH:-rdpws}"

if [[ "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
    export RESOLUTION="${RESOLUTION}x24"
fi

echo "Starting remote desktop environment..."
echo "  Port:       ${PORT}"
echo "  Resolution: ${RESOLUTION}"
echo "  CPUs:       ${CPU_COUNT} (cgroup-aware)"
echo "  RAM:        ${MEMORY_MB} MiB available to this service"
echo "  nginx:      ${NGINX_WORKERS} workers, ${WORKER_CONNECTIONS} connections/worker, nofile ${NOFILE_LIMIT}"
echo "  web:        waitress ${WEB_THREADS} threads"
echo "  VNC port:   5900 (internal, shared XFCE desktop)"
echo "  RDP port:   3389 (xrdp -> x11vnc 5900 -> XFCE desktop)"
echo "  RDP WS:     wss://<service-host>/${RDP_WS_PATH} (stable, native RDP via a websocket bridge)"
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
sed -e "s/__PORT__/${PORT}/g" \
    -e "s/__RDP_WS_PATH__/${RDP_WS_PATH}/g" \
    -e "s/__NGINX_WORKERS__/${NGINX_WORKERS}/g" \
    -e "s/__RLIMIT_NOFILE__/${NOFILE_LIMIT}/g" \
    -e "s/__WORKER_CONNECTIONS__/${WORKER_CONNECTIONS}/g" \
    /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
