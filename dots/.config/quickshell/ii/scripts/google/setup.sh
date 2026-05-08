#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/google"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

missing=()
for cmd in curl jq xdg-open; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if (( ${#missing[@]} > 0 )); then
    echo "Faltan dependencias: ${missing[*]}" >&2
    echo "Instalá con: sudo pacman -S ${missing[*]}" >&2
    exit 1
fi

cat <<EOF
Setup OK. Estado: $STATE_DIR

Próximos pasos:
  1. Crear OAuth client en https://console.cloud.google.com:
       - Habilitar "Google Tasks API"
       - Credentials -> Create -> OAuth client ID -> Desktop app
       - Download JSON
  2. Mover el JSON descargado:
       mv ~/Downloads/client_secret_*.json $STATE_DIR/credentials.json
       chmod 600 $STATE_DIR/credentials.json
  3. Autorizar:
       bash ${BASH_SOURCE%/*}/tasks.sh auth
EOF
