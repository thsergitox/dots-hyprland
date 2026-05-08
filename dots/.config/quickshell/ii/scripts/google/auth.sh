#!/usr/bin/env bash
# OAuth 2.0 Authorization Code flow (Desktop app) — manual paste variant.
# No netcat needed: el browser muestra "Site can't be reached" tras autorizar,
# pero la URL completa (con ?code=...) está en la barra. El user la pega acá.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/google"
CREDS="$STATE_DIR/credentials.json"
TOKEN_FILE="$STATE_DIR/token.json"
SCOPE="https://www.googleapis.com/auth/tasks"
REDIRECT="http://127.0.0.1:8765"

if [[ ! -f "$CREDS" ]]; then
    echo "No existe $CREDS" >&2
    echo "Corré primero: bash ${BASH_SOURCE%/*}/setup.sh" >&2
    exit 1
fi

CLIENT_ID=$(jq -r '.installed.client_id // .web.client_id // empty' "$CREDS")
CLIENT_SECRET=$(jq -r '.installed.client_secret // .web.client_secret // empty' "$CREDS")

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
    echo "credentials.json no contiene client_id/client_secret. ¿Es del tipo Desktop app?" >&2
    exit 1
fi

AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth"
AUTH_URL+="?response_type=code"
AUTH_URL+="&client_id=$CLIENT_ID"
AUTH_URL+="&redirect_uri=$(jq -rn --arg v "$REDIRECT" '$v|@uri')"
AUTH_URL+="&scope=$(jq -rn --arg v "$SCOPE" '$v|@uri')"
AUTH_URL+="&access_type=offline"
AUTH_URL+="&prompt=consent"

echo
echo "Voy a abrir el browser para autorizar acceso a Google Tasks (read-only)."
echo "Tras autorizar verás una página 'Site can't be reached' — es esperado."
echo "Copiá la URL COMPLETA de la barra de direcciones y pegala acá abajo."
echo
echo "Si el browser no abre, abrí esta URL manualmente:"
echo "  $AUTH_URL"
echo

xdg-open "$AUTH_URL" >/dev/null 2>&1 || true

read -rp "URL de redirect (incluye ?code=...): " REDIRECT_URL

CODE=$(echo "$REDIRECT_URL" | grep -oE 'code=[^&[:space:]]+' | head -1 | cut -d= -f2- || true)
if [[ -z "$CODE" ]]; then
    echo "No pude extraer ?code= de la URL pegada" >&2
    exit 1
fi

# URL-decode (Google generalmente devuelve el code sin escapar, pero por las dudas)
CODE=$(printf '%b' "${CODE//%/\\x}")

NOW=$(date +%s)
RESP=$(curl -sS https://oauth2.googleapis.com/token \
    -d "code=$CODE" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "redirect_uri=$REDIRECT" \
    -d "grant_type=authorization_code")

if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
    echo "Error de Google:" >&2
    echo "$RESP" | jq . >&2
    exit 1
fi

EXPIRES_IN=$(echo "$RESP" | jq -r '.expires_in // 3600')
EXPIRES_AT=$(( NOW + EXPIRES_IN ))

echo "$RESP" | jq --arg e "$EXPIRES_AT" '. + {expires_at: ($e|tonumber)}' > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo
echo "OK. Token guardado en $TOKEN_FILE"
echo "Probá: bash ${BASH_SOURCE%/*}/tasks.sh list"
