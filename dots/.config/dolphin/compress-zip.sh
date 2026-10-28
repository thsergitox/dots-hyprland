#!/usr/bin/env bash

choose_destination() {
  local destination
  destination=$(kdialog --title 'Comprimir en ZIP' --getsavefilename "$1" '*.zip|Archivo ZIP') || return
  [[ -n "$destination" ]] || return 1
  [[ "${destination,,}" == *.zip ]] || destination+=.zip
  destination=$(realpath -m -s -- "$destination") || return
  if [[ -e "$destination" || -L "$destination" ]]; then
    kdialog --title 'Reemplazar ZIP' --warningcontinuecancel "Ya existe: $destination. ¿Quieres reemplazarlo?" || return
  fi
  printf '%s\n' "$destination"
}

common_directory() {
  local directory item
  directory=$(dirname -- "$1")
  for item in "$@"; do
    while [[ "$item" != "${directory%/}/"* ]]; do
      directory=$(dirname -- "$directory")
    done
  done
  printf '%s\n' "$directory"
}

create_archive() (
  local destination=$1 directory=$2 temporary item
  local -a entries=()
  shift 2
  for item in "$@"; do
    [[ "$item" != "$destination" ]] || { printf 'El destino coincide con un archivo seleccionado.\n' >&2; return 1; }
    entries+=("${item#"${directory%/}/"}")
  done
  temporary=$(mktemp --tmpdir="$(dirname -- "$destination")" '.dolphin-zip.XXXXXX.zip') || return
  trap 'rm -f -- "$temporary"' EXIT
  cd -- "$directory" || return
  # Stream to a fresh archive: replacing a ZIP must not retain its old entries.
  zip -q -r -y -nw - -x "${destination#"${directory%/}/"}" "${temporary#"${directory%/}/"}" -- "${entries[@]}" > "$temporary" || return
  mv -f -- "$temporary" "$destination"
)

main() {
  local item directory suggested destination details
  local -a selection=()
  (( $# > 0 )) || return 1
  for item in "$@"; do
    item=$(realpath -s -e -- "$item") || return
    selection+=("$item")
  done
  directory=$(common_directory "${selection[@]}")
  suggested="${selection[0]}.zip"
  (( $# == 1 )) || suggested="${directory%/}/Archivos.zip"
  destination=$(choose_destination "$suggested") || return 0
  if details=$(create_archive "$destination" "$directory" "${selection[@]}" 2>&1); then
    kdialog --title 'Comprimir en ZIP' --passivepopup "ZIP guardado en: $destination" 4
  else
    kdialog --title 'Comprimir en ZIP' --detailederror 'No se pudo crear el archivo ZIP.' "$details"
    return 1
  fi
}

main "$@"
