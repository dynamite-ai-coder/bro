#!/bin/bash
set -e

mkdir -p /run/xrdp
chown xrdp:xrdp /run/xrdp
chmod 755 /run/xrdp

echo "Starting xrdp: RDP on 3389 -> x11vnc 127.0.0.1:5900 (shared XFCE desktop)"
exec /usr/sbin/xrdp --nodaemon
