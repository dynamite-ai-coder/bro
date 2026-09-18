#!/bin/bash
set -e

exec /opt/venv/bin/waitress-serve --listen="127.0.0.1:${INTERNAL_PORT:-5000}" --threads=16 app:app
