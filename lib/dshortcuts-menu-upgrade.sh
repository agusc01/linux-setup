#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Migrar solo el menú original (items.h) con respaldo; NUNCA config.h.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/source-preserve.sh"
dry_run=0
if [ "$#" -gt 0 ]; then
    [ "$#" -eq 1 ] && [ "$1" = --dry-run ] || {
        echo 'Uso: sh lib/dshortcuts-menu-upgrade.sh [--dry-run]' >&2; exit 2
    }
    dry_run=1
fi
[ "$(id -u)" -ne 0 ] || { echo 'Ejecutá la migración de dshortcuts como usuario normal.' >&2; exit 1; }
source_tree=$(linux_setup_source_existing dshortcuts) || exit 1
[ -n "$source_tree" ] || {
    echo 'Error: faltan fuentes persistentes de dshortcuts; usá --save-sources.' >&2; exit 1
}
current="$source_tree/items.h"
old="$root/profiles/dshortcuts/items-v1.h"
new="$root/profiles/dshortcuts/items.h"
for file in "$current" "$old" "$new"; do
    [ -f "$file" ] && [ ! -L "$file" ] || {
        echo "Error: items.h ausente, enlazado o inesperado: $file" >&2; exit 1
    }
done
if cmp -s "$current" "$new"; then
    echo "El menú de dshortcuts ya está actualizado: $current"
    exit 0
fi
if ! cmp -s "$current" "$old"; then
    echo "Se conserva el items.h personalizado: $current" >&2
    echo 'La migración automática solo admite la plantilla anterior sin editar.' >&2
    echo 'Compará manualmente items-v1.h y el nuevo items.h del repositorio.' >&2
    exit 1
fi
if [ "$dry_run" -eq 1 ]; then
    echo "Simulación: se respaldaría $current y se migraría exclusivamente items.h."
    echo 'No se modificarían config.h, ejecutables ni fuentes editadas.'
    exit 0
fi
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
backup_base="$state_root/linux-setup/backups/dshortcuts"
for directory in "$state_root" "$state_root/linux-setup" "$state_root/linux-setup/backups" "$backup_base"; do
    if [ -L "$directory" ] || { [ -e "$directory" ] && [ ! -d "$directory" ]; }; then
        echo "Error: directorio de respaldo inseguro: $directory" >&2
        exit 1
    fi
done
mkdir -p "$backup_base"
backup_dir=$(mktemp -d "$backup_base/menu.XXXXXXXX")
# Backup completo y recuperable incluso si la sustitución falla.
cp -p "$current" "$backup_dir/items.h"
cmp -s "$backup_dir/items.h" "$old" || {
    echo 'Error: el menú cambió antes de crear el respaldo; se conserva.' >&2; exit 1
}
temporary=$(mktemp "$source_tree/.items.h.XXXXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
cp "$new" "$temporary"
chmod 644 "$temporary"
# Revalidación justo antes de publicar el nuevo fichero.
[ ! -L "$current" ] && cmp -s "$current" "$old" || {
    echo 'Error: items.h cambió durante la preparación. No se reemplaza.' >&2; exit 1
}
mv "$temporary" "$current"
echo "Menú dshortcuts actualizado: $current"
echo "Backup recuperable: $backup_dir/items.h"
echo 'config.h y ejecutable actual conservados. Recompilá expresamente cuando quieras usar el menú.'
