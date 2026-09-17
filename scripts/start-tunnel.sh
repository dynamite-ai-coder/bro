#!/bin/bash
set -u

TUNNEL_FILE="${TUNNEL_FILE:-/run/rdp-tunnel.txt}"
RDP_PORT="${RDP_PORT:-3389}"
ESC="$(printf '\033')"

write_address() {
    printf '%s\n' "$1" > "${TUNNEL_FILE}.tmp"
    mv "${TUNNEL_FILE}.tmp" "$TUNNEL_FILE"
}

stop_pid() {
    local pid="$1"
    kill "$pid" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 1
    done
    kill -9 "$pid" 2>/dev/null || true
}

start_ngrok() {
    local token="$1" pid i address
    echo "Starting ngrok TCP tunnel to 127.0.0.1:${RDP_PORT}..."
    ngrok tcp --authtoken "$token" --log stdout --log-format logfmt "$RDP_PORT" &
    pid=$!
    for i in $(seq 1 20); do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "ngrok exited before establishing a tunnel" >&2
            wait "$pid" 2>/dev/null || true
            return 1
        fi
        address="$(curl -fsS http://127.0.0.1:4040/api/tunnels 2>/dev/null \
            | sed -n 's/.*"public_url":"tcp:\/\/\([^"]*\)".*/\1/p' | head -n 1)"
        if [ -n "$address" ]; then
            write_address "$address"
            echo "RDP tunnel is up (ngrok): ${address}"
            wait "$pid"
            return $?
        fi
        sleep 1
    done
    echo "ngrok did not report a tunnel within 20s; stopping it" >&2
    stop_pid "$pid"
    return 1
}

start_pinggy() {
    local log="/run/pinggy-tunnel.log" pid i address
    echo "Starting pinggy TCP tunnel to 127.0.0.1:${RDP_PORT}..."
    : > "$log"
    ssh -T -p 443 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ServerAliveInterval=15 \
        -o ExitOnForwardFailure=yes \
        -o BatchMode=yes \
        -R0:127.0.0.1:${RDP_PORT} tcp@a.pinggy.io > "$log" 2>&1 &
    pid=$!
    for i in $(seq 1 30); do
        if ! kill -0 "$pid" 2>/dev/null; then
            cat "$log"
            wait "$pid" 2>/dev/null || true
            return 1
        fi
        address="$(sed -n 's/.*tcp:\/\/\([^ ]*\).*/\1/p' "$log" | head -n 1)"
        if [ -n "$address" ]; then
            write_address "$address"
            echo "RDP tunnel is up (pinggy): ${address}"
            cat "$log"
            wait "$pid"
            return $?
        fi
        sleep 1
    done
    echo "pinggy did not report a tunnel within 30s; stopping it" >&2
    cat "$log"
    stop_pid "$pid"
    return 1
}

start_bore() {
    local args=() log="/run/bore-tunnel.log" pid i port target
    target="$(getent ahostsv4 bore.pub 2>/dev/null | awk 'NR==1{print $1}')"
    [ -n "$target" ] || target="bore.pub"
    if timeout 5 bash -c "exec 3<>/dev/tcp/${target}/7835" 2>/dev/null; then
        echo "bore.pub (${target}:7835) is reachable"
    else
        echo "warning: bore.pub (${target}:7835) is not reachable from this host" >&2
    fi
    args=(local "$RDP_PORT" --to "$target" --port "${RDP_TUNNEL_PORT:-0}")
    if [ -n "${BORE_SECRET:-}" ]; then
        args+=(--secret "$BORE_SECRET")
    fi
    echo "Starting bore tunnel to 127.0.0.1:${RDP_PORT} via bore.pub..."
    : > "$log"
    bore "${args[@]}" > "$log" 2>&1 &
    pid=$!
    for i in $(seq 1 30); do
        if ! kill -0 "$pid" 2>/dev/null; then
            sed "s/${ESC}\[[0-9;]*m//g" "$log"
            wait "$pid" 2>/dev/null || true
            return 1
        fi
        port="$(sed "s/${ESC}\[[0-9;]*m//g" "$log" | sed -n 's/.*listening at [^:]*:\([0-9]\{1,\}\).*/\1/p' | head -n 1)"
        if [ -n "$port" ]; then
            write_address "bore.pub:${port}"
            echo "RDP tunnel is up (bore): bore.pub:${port}"
            sed "s/${ESC}\[[0-9;]*m//g" "$log"
            wait "$pid"
            return $?
        fi
        sleep 1
    done
    echo "bore did not report a tunnel within 30s; stopping it" >&2
    sed "s/${ESC}\[[0-9;]*m//g" "$log"
    stop_pid "$pid"
    return 1
}

rm -f "$TUNNEL_FILE"

if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
    if start_ngrok "$NGROK_AUTHTOKEN"; then
        exit 0
    fi
    echo "ngrok failed; falling back to pinggy" >&2
else
    echo "NGROK_AUTHTOKEN is not set; trying pinggy" >&2
fi

if start_pinggy; then
    exit 0
fi

echo "pinggy failed; falling back to the public bore.pub relay" >&2
start_bore
exit $?
