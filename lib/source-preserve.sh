#!/bin/sh
# Biblioteca POSIX: fuentes persistentes editables, sin sobrescribir carpetas existentes.
# Este archivo se carga desde instaladores; no debe ejecutarse directamente.
linux_setup_source_root() {
    printf '%s\n' "${LINUX_SETUP_SOURCE_DIR:-$HOME/.local/src}"
}
linux_setup_source_existing() {
    name=$1
    directory="$(linux_setup_source_root)/$name"
    if [ -L "$directory" ]; then
        echo "Error: fuente enlazada, se conserva sin seguir: $directory" >&2
        return 1
    fi
    if [ -e "$directory" ]; then
        [ -d "$directory" ] && [ -f "$directory/Makefile" ] && [ ! -L "$directory/Makefile" ] || {
            echo "Error: fuente existente inesperada, no se sobrescribe: $directory" >&2
            return 1
        }
        printf '%s\n' "$directory"
    fi
}
linux_setup_source_save() (
    set -eu
    name=$1
    from=$2
    directory="$(linux_setup_source_root)"
    dest="$directory/$name"
    if [ -L "$dest" ]; then
        echo "Error: fuente enlazada, no se modifica: $dest" >&2
        exit 1
    fi
    if [ -e "$dest" ]; then
        echo "Fuente existente conservada: $dest"
        exit 0
    fi
    [ ! -L "$directory" ] && { [ ! -e "$directory" ] || [ -d "$directory" ]; } || {
        echo "Error: directorio de fuentes inseguro, se conserva sin cambios: $directory" >&2
        exit 1
    }
    mkdir -p "$directory"
    tmp=$(mktemp -d "$directory/.$name.XXXXXXXX")
    trap 'rm -rf "$tmp"' EXIT HUP INT TERM
    cp -R "$from/." "$tmp/"
    [ -f "$tmp/Makefile" ] || { echo "Error: Makefile ausente al preservar $name" >&2; exit 1; }
    if [ -L "$dest" ]; then
        echo "Error: fuente enlazada concurrentemente: $dest" >&2
        exit 1
    fi
    if [ -e "$dest" ]; then
        echo "Fuente creada por otro proceso conservada: $dest"
        exit 0
    fi
    mv "$tmp" "$dest"
    echo "Fuentes conservadas: $dest"
)
