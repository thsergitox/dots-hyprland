#!/usr/bin/env bash

extract_archive() {
  local archive destination
  archive=$(realpath -e -- "$1") || return
  destination=$(dirname -- "$archive")

  case "${archive,,}" in
    *.zip) unzip "$archive" -d "$destination" ;;
    *.rar) unrar x "$archive" "$destination/" ;;
    *) printf 'Formato no compatible: %s\n' "$archive" >&2; return 1 ;;
  esac
}

main() {
  local archive status=0
  if (( $# == 0 )); then
    printf 'Uso: %s archivo.zip [archivo.rar ...]\n' "$0" >&2
    return 1
  fi

  for archive in "$@"; do
    if ! extract_archive "$archive"; then
      printf '\nNo se pudo completar la extracción de: %s\n' "$archive" >&2
      status=1
    fi
  done

  # Keep errors visible when Dolphin launches the terminal.
  if (( status != 0 )) && [[ -t 0 ]]; then
    read -r -p 'Pulsa Enter para cerrar… ' || true
  fi
  return "$status"
}

main "$@"
