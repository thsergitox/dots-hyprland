# Google Tasks integration

Lee tareas pendientes de tu **Google Tasks** y las muestra en la 3ra pestaña del Todo widget del sidebar derecho y en el popup del reloj.

- **Lectura + marcar como completada**: el botón check completa la tarea en Google. Crear/eliminar/editar contenido NO está soportado (lo hacés desde la app de Google Tasks).
- **Scope OAuth**: `https://www.googleapis.com/auth/tasks` (full). Si venís de la versión read-only, tenés que reautenticarte: `bash ~/.config/quickshell/ii/scripts/google/tasks.sh auth`.
- **Refresh**: cada 5 min, automático.
- **Stack**: bash + curl + jq. Cero runtimes extra. ~0 RAM en estado normal.

## Setup (one-time)

### 1. Crear OAuth client en Google Cloud Console

https://console.cloud.google.com

1. **Create Project** (o elegí uno existente).
2. **APIs & Services → Library** → buscá "Tasks API" → **Enable**.
3. **APIs & Services → OAuth consent screen** → si no lo tenés configurado, completá lo mínimo (External, tu email, scopes vacíos por ahora).
4. **APIs & Services → Credentials** → **Create Credentials** → **OAuth client ID** → tipo **Desktop app** → cualquier nombre → **Create**.
5. Botón **Download JSON** del cliente recién creado.

### 2. Conectar tu cuenta

```fish
bash ~/.config/quickshell/ii/scripts/google/setup.sh
mv ~/Downloads/client_secret_*.json ~/.local/state/quickshell/google/credentials.json
chmod 600 ~/.local/state/quickshell/google/credentials.json
bash ~/.config/quickshell/ii/scripts/google/tasks.sh auth
```

El último comando:
- Abre tu browser con la pantalla de consentimiento de Google.
- Después de autorizar, vas a ver una página **"Site can't be reached"** — es esperado, no hay servidor escuchando.
- **Copiá la URL completa de la barra de direcciones** (incluye `?code=XXX&...`) y pegala en la terminal cuando te lo pida.
- Listo: `token.json` queda guardado.

### 3. Reiniciar quickshell

```fish
qs -c ii kill; qs -c ii &
```

Abrí el sidebar derecho → pestaña **Google** (icono nube) → tus tareas.

## Test manual

```fish
bash ~/.config/quickshell/ii/scripts/google/tasks.sh list | jq
```

Output esperado:
```json
{
  "ok": true,
  "fetchedAt": "2026-05-07T19:48:00Z",
  "tasks": [
    {"id": "...", "title": "Comprar pan", "due": "2026-05-08T00:00:00.000Z", "notes": "", "status": "needsAction"}
  ]
}
```

En errores recuperables (sin red, token expirado y refresh falló, etc.) sale `{"ok":false,"error":"..."}` con exit 0.

## Códigos de error comunes

| `error`                   | Significado                                                       |
|--------------------------|-------------------------------------------------------------------|
| `missing_credentials`    | No existe `credentials.json`. Volvé al paso 1.                    |
| `not_authenticated`      | No corriste `tasks.sh auth` todavía.                              |
| `refresh_failed_invalid_grant` | El refresh token fue revocado. Volvé a autorizar.            |
| `refresh_failed_network` | No hay red o timeout (15s).                                       |
| `fetch_failed: ...`      | API de Google devolvió error. Mensaje en la cadena.               |

## Archivos

| Path                                                      | Qué hace                              |
|-----------------------------------------------------------|----------------------------------------|
| `setup.sh`                                                | Crea dirs, verifica deps              |
| `auth.sh`                                                 | OAuth one-time (copy-paste flow)      |
| `tasks.sh`                                                | `list` (refresh + fetch) y `auth`     |
| `~/.local/state/quickshell/google/credentials.json`       | OAuth client (de Google Cloud)        |
| `~/.local/state/quickshell/google/token.json`             | Access + refresh tokens (chmod 600)   |

## Limitaciones actuales

- Solo la lista **`@default`**. Si tenés varias listas y querés todas, hay que iterar `tasklists.list` (cambio chico en `tasks.sh`).
- Read-only. Para crear/marcar desde el sidebar habría que: (a) cambiar scope a `tasks` (full), (b) implementar `POST/PATCH/DELETE` en `tasks.sh`, (c) wirear acciones en `TodoWidget.qml`.
- Token en disco (`chmod 600`). Mejora futura: mover a libsecret vía el `KeyringStorage` ya existente del repo.

## Revocar acceso

Para desconectar:
```fish
rm -f ~/.local/state/quickshell/google/token.json
```

Y opcionalmente revocar el grant en https://myaccount.google.com/permissions.
