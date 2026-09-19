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

# XMRig HTTP API settings.
# The worker listens only on localhost; nginx exposes it securely through /xmrig/.
export XMRIG_API_PORT="${XMRIG_API_PORT:-18088}"
export XMRIG_API_TOKEN="${XMRIG_API_TOKEN:-}"
export XMRIG_WORKER_ID="${XMRIG_WORKER_ID:-${RENDER_SERVICE_NAME:-worker}}"

RDP_WS_PATH="$(printf '%s' "${RDP_WS_PATH}" | tr -cd 'A-Za-z0-9_-')"
export RDP_WS_PATH="${RDP_WS_PATH:-rdpws}"

if [[ "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
    export RESOLUTION="${RESOLUTION}x24"
fi

if [ -z "${XMRIG_API_TOKEN}" ]; then
    echo "ERROR: XMRIG_API_TOKEN is not set." >&2
    echo "Set XMRIG_API_TOKEN in the Render Environment variables." >&2
    exit 1
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
echo "  XMRig API:  127.0.0.1:${XMRIG_API_PORT}"
echo "  XMRig ID:   ${XMRIG_WORKER_ID}"

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
    ln -sfn /