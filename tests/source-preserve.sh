#!/bin/sh
# No borrar jamás una copia editable ni reemplazar sus configuraciones.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM
HOME="$temp/home"
LINUX_SETUP_SOURCE_DIR="$HOME/.local/src"
export HOME LINUX_SETUP_SOURCE_DIR
mkdir -p "$temp/build" "$HOME"
printf 'all:\n\t@true\n' > "$temp/build/Makefile"
printf 'primera\n' > "$temp/build/config.h"
. "$root/lib/source-preserve.sh"
linux_setup_source_save dwm "$temp/build" > "$temp/log"
test -f "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
grep -Fxq primera "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
printf 'mi-configuracion\n' > "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
printf 'segunda\n' > "$temp/build/config.h"
linux_setup_source_save dwm "$temp/build" >> "$temp/log"
grep -Fxq mi-configuracion "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
test "$(linux_setup_source_existing dwm)" = "$LINUX_SETUP_SOURCE_DIR/dwm"
ln -s "$LINUX_SETUP_SOURCE_DIR/dwm" "$LINUX_SETUP_SOURCE_DIR/st"
if linux_setup_source_existing st > "$temp/log" 2>&1; then
    echo 'FALLO: siguió un symlink de fuentes.' >&2; exit 1
fi
if linux_setup_source_save st "$temp/build" > "$temp/log" 2>&1; then
    echo 'FALLO: reemplazó symlink de fuentes.' >&2; exit 1
fi
test -L "$LINUX_SETUP_SOURCE_DIR/st"
# Las copias recuperadas pueden tener sólo config.def.h (make no se ejecutó).
# Crear config.h desde esa plantilla y conservar luego las modificaciones.
printf 'predeterminado\n' > "$LINUX_SETUP_SOURCE_DIR/dwm/config.def.h"
rm "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
linux_setup_source_ensure_config dwm > "$temp/log"
grep -Fxq predeterminado "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
printf 'personalizado\n' > "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
linux_setup_source_ensure_config dwm > "$temp/log"
grep -Fxq personalizado "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
rm "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
rm "$LINUX_SETUP_SOURCE_DIR/dwm/config.def.h"
if linux_setup_source_ensure_config dwm > "$temp/log" 2>&1; then
    echo 'FALLO: creó config.h sin plantilla.' >&2; exit 1
fi
test ! -e "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
printf 'plantilla\n' > "$LINUX_SETUP_SOURCE_DIR/dwm/config.def.h"
ln -s config.def.h "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
if linux_setup_source_ensure_config dwm > "$temp/log" 2>&1; then
    echo 'FALLO: aceptó config.h enlazado.' >&2; exit 1
fi
test -L "$LINUX_SETUP_SOURCE_DIR/dwm/config.h"
printf '%s\n' '[OK] Fuentes persistentes: edición conservada, no sobrescritura y symlinks protegidos.'
