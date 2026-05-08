#!/usr/bin/env bash
# tasks.sh - Google Tasks helper for quickshell.
# Subcomandos:
#   tasks.sh auth                 -> delega a auth.sh (OAuth one-time)
#   tasks.sh list                 -> emite JSON con tareas pendientes
#   tasks.sh complete <task_id>   -> marca tarea como completada
#   tasks.sh uncomplete <task_id> -> revierte una tarea a pendiente
#
# Todos los subcomandos retornan JSON con shape {ok:true, ...} o
# {ok:false, error:"..."} y exit code 0 (para parseo uniforme desde QML).
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/google"
CREDS="$STATE_DIR/credentials.json"
TOKEN_FILE="$STATE_DIR/token.json"
HERE="${BASH_SOURCE%/*}"

# Variables setadas por ensure_token()
ACCESS_TOKEN=""

emit_error() {
    jq -nc --arg e "$1" '{ok:false, error:$e}'
    exit 0
}

ensure_token() {
    [[ -f "$CREDS" ]] || emit_error "missing_credentials"
    [[ -f "$TOKEN_FILE" ]] || emit_error "not_authenticated"

    local CLIENT_ID CLIENT_SECRET REFRESH_TOKEN EXPIRES_AT NOW
    CLIENT_ID=$(jq -r '.installed.client_id // .web.client_id // empty' "$CREDS")
    CLIENT_SECRET=$(jq -r '.installed.client_secret // .web.client_secret // empty' "$CREDS")
    ACCESS_TOKEN=$(jq -r '.access_token // empty' "$TOKEN_FILE")
    REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$TOKEN_FILE")
    EXPIRES_AT=$(jq -r '.expires_at // 0' "$TOKEN_FILE")
    NOW=$(date +%s)

    if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" || -z "$REFRESH_TOKEN" ]]; then
        emit_error "invalid_credentials"
    fi

    if (( NOW + 60 >= EXPIRES_AT )); then
        local refresh_resp new_access new_expires_in
        refresh_resp=$(curl -sS --max-time 15 https://oauth2.googleapis.com/token \
            -d "client_id=$CLIENT_ID" \
            -d "client_secret=$CLIENT_SECRET" \
            -d "refresh_token=$REFRESH_TOKEN" \
            -d "grant_type=refresh_token" 2>/dev/null) || emit_error "refresh_failed_network"

        if echo "$refresh_resp" | jq -e '.error' >/dev/null 2>&1; then
            local err
            err=$(echo "$refresh_resp" | jq -r '.error')
            emit_error "refresh_failed_$err"
        fi

        new_access=$(echo "$refresh_resp" | jq -r '.access_token // empty')
        new_expires_in=$(echo "$refresh_resp" | jq -r '.expires_in // 3600')
        [[ -n "$new_access" ]] || emit_error "refresh_failed_no_token"

        local new_expires_at=$(( NOW + new_expires_in ))
        local tmp
        tmp=$(mktemp "$STATE_DIR/.token.XXXXXX")
        jq --arg t "$new_access" --arg e "$new_expires_at" \
           '.access_token=$t | .expires_at=($e|tonumber)' "$TOKEN_FILE" > "$tmp"
        chmod 600 "$tmp"
        mv "$tmp" "$TOKEN_FILE"
        ACCESS_TOKEN=$new_access
    fi
}

cmd_list() {
    ensure_token

    local resp
    resp=$(curl -sS --max-time 15 \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks?showCompleted=false&maxResults=100" \
        2>/dev/null) || emit_error "fetch_failed_network"

    if echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
        local err
        err=$(echo "$resp" | jq -r '.error.message // "unknown"')
        emit_error "fetch_failed: $err"
    fi

    echo "$resp" | jq -c '{
        ok: true,
        fetchedAt: (now | todate),
        tasks: [(.items // [])[] | {
            id: .id,
            title: (.title // ""),
            due: (.due // null),
            notes: (.notes // ""),
            status: (.status // "needsAction"),
            parent: (.parent // null),
            position: (.position // "")
        }]
    }'
}

# Actualiza el status de una tarea ("completed" | "needsAction").
# Uso: cmd_set_status <task_id> <status>
cmd_set_status() {
    local task_id="$1"
    local new_status="$2"
    [[ -n "$task_id" ]] || emit_error "missing_task_id"
    [[ "$new_status" == "completed" || "$new_status" == "needsAction" ]] || emit_error "invalid_status"

    ensure_token

    local body
    if [[ "$new_status" == "completed" ]]; then
        body='{"status":"completed"}'
    else
        # Al pasar a needsAction hay que limpiar el campo completed (la API lo exige).
        body='{"status":"needsAction","completed":null}'
    fi

    local resp
    resp=$(curl -sS --max-time 15 -X PATCH \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$body" \
        "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/$task_id" \
        2>/dev/null) || emit_error "patch_failed_network"

    if echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
        local err
        err=$(echo "$resp" | jq -r '.error.message // "unknown"')
        emit_error "patch_failed: $err"
    fi

    jq -nc --arg s "$new_status" '{ok:true, status:$s}'
}

case "${1:-}" in
    auth)
        exec bash "$HERE/auth.sh"
        ;;
    list)
        cmd_list
        ;;
    complete)
        cmd_set_status "${2:-}" "completed"
        ;;
    uncomplete)
        cmd_set_status "${2:-}" "needsAction"
        ;;
    *)
        echo "uso: $0 {auth|list|complete <id>|uncomplete <id>}" >&2
        exit 2
        ;;
esac
