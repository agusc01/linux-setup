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

# Completar únicamente config.h ausente. Nunca modificar uno ya existente.
# En algunos forks config.h se genera con make desde config.def.h, por lo
# que preservar las fuentes antes de compilar deja el archivo sin crear.
linux_setup_source_ensure_config() (
    set -eu
    name=$1
    case "$name" in dwm|st) ;; *) return 0 ;; esac
    directory="$(linux_setup_source_root)/$name"
    target="$directory/config.h"
    template="$directory/config.def.h"
    [ ! -L "$directory" ] && [ -d "$directory" ] || {
        echo "Error: carpeta de fuente inválida: $directory" >&2; exit 1
    }
    if [ -L "$target" ]; then
        echo "Error: config.h enlazado; no se modifica: $target" >&2; exit 1
    fi
    if [ -e "$target" ]; then
        [ -f "$target" ] || { echo "Error: config.h no es archivo regular: $target" >&2; exit 1; }
        echo "Configuración existente conservada: $target"
        exit 0
    fi
    [ -f "$template" ] && [ ! -L "$template" ] || {
        echo "Error: falta config.def.h regular para crear $target; no se modifica nada." >&2
        exit 1
    }
    # Crear desde una copia temporal y publicar sólo si sigue ausente:
    # ln falla si otra operación creó config.h mientras tanto.
    temporary=$(mktemp "$directory/.config.h.XXXXXXXX")
    trap 'rm -f "$temporary"' EXIT HUP INT TERM
    cp "$template" "$temporary"
    chmod 644 "$temporary"
    if ln "$temporary" "$target" 2>/dev/null; then
        echo "config.h editable creado desde config.def.h: $target"
    else
        echo "Aviso: config.h apareció durante la operación; se conserva sin sobrescribir." >&2
        [ -f "$target" ] && [ ! -L "$target" ] || exit 1
    fi
)
