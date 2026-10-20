#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Integración opt-in: recompilar dwm con activación Rofi entre tags.
# Nunca altera el checkout original ni los archivos config.h/keys.h.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/dshortcuts-deps.sh"
PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"
export PATH
source_dir=${DWM_SOURCE_DIR:-/usr/src/suckless/dwm}
target=/usr/local/bin/dwm
dry_run=0
yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --source)
            [ "$#" -ge 2 ] || { echo 'Error: falta ruta para --source.' >&2; exit 2; }
            source_dir=$2
            shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        --yes) yes=1; shift ;;
        -h|--help)
            echo 'Uso: sh lib/dwm-rofi-setup.sh [--source /ruta/a/dwm] [--dry-run] [--yes]'
            exit 0 ;;
        *) echo "Error: opción no reconocida: $1" >&2; exit 2 ;;
    esac
done

[ "$(id -u)" -ne 0 ] || { echo 'Ejecutá como usuario normal; solo la instalación del binario requiere root.' >&2; exit 1; }
[ -f "$source_dir/dwm.c" ] && [ -f "$source_dir/Makefile" ] && [ -f "$source_dir/config.mk" ] || {
    echo "Error: no se encontró el código fuente de dwm en $source_dir." >&2
    echo 'Indicá su ubicación con --source /ruta/a/dwm. No se tocará el dwm instalado.' >&2
    exit 1
}
[ ! -L "$target" ] && { [ ! -e "$target" ] || [ -f "$target" ]; } || {
    echo "Error: $target no es un ejecutable regular; no se reemplazará." >&2
    exit 1
}
echo "Código fuente (solo lectura): $source_dir"
echo "Destino: $target"
echo 'Se recompilará una COPIA temporal conservando config.h, keys.h y demás personalizaciones.'
echo 'El ejecutable anterior se guardará en ~/.local/state/linux-setup/backups/.'
if [ "$dry_run" -eq 1 ]; then
    if command -v patch >/dev/null 2>&1; then
        if grep -Fq 'linux-setup: rofi-window-focus' "$source_dir/dwm.c"; then
            echo 'Parche: ya presente en este código fuente.'
        elif patch --dry-run -s -d "$source_dir" -p1 < "$root/profiles/dwm/rofi-window-focus.patch"; then
            echo 'Parche: compatible con este dwm.'
        else
            echo 'Error: el parche no es compatible con este dwm; no se hará ningún cambio.' >&2
            exit 1
        fi
    else
        echo 'Aviso: patch falta; el instalador instalará las dependencias con autorización.'
    fi
    echo 'Simulación: no se modificó ni instaló nada.'
    exit 0
fi

if [ "$yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Error: confirmá interactivamente o utilizá --yes.' >&2; exit 2; }
    printf '¿Recompilar dwm e instalarlo con respaldo del binario anterior? [s/N]: '
    IFS= read -r reply || reply=''
    case "$reply" in s|S|si|Si|SI) : ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi

[ -r /etc/os-release ] || { echo 'Error: falta /etc/os-release.' >&2; exit 1; }
. /etc/os-release
dshortcuts_ensure_dependencies "$ID"
for cmd in make cc patch; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: falta $cmd tras preparar dependencias." >&2; exit 1; }
done
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir "$work/source"
cp -R "$source_dir/." "$work/source/"
if grep -Fq 'linux-setup: rofi-window-focus' "$work/source/dwm.c"; then
    echo 'Parche: ya incorporado al código fuente.'
else
    patch -s -d "$work/source" -p1 < "$root/profiles/dwm/rofi-window-focus.patch" || {
        echo 'Error: el parche no se aplica a este dwm. El binario instalado sigue intacto.' >&2
        exit 1
    }
fi

make -C "$work/source" clean all || {
    echo 'Error: dwm no compila con esta configuración. El binario instalado sigue intacto.' >&2
    exit 1
}
[ -x "$work/source/dwm" ] || { echo 'Error: la compilación no produjo dwm.' >&2; exit 1; }

if [ -f "$target" ]; then
    backup_base="$HOME/.local/state/linux-setup/backups"
    mkdir -p "$backup_base"
    backup=$(mktemp -d "$backup_base/dwm-rofi.XXXXXXXX")
    cp -p "$target" "$backup/dwm" || { echo 'Error: no se pudo crear el respaldo.' >&2; exit 1; }
    echo "Backup del dwm anterior: $backup/dwm"
fi
install_exe=$(command -v install) || { echo 'Error: falta install.' >&2; exit 1; }
dshortcuts_as_root "$install_exe" -m 0755 "$work/source/dwm" "$target"
echo "OK: dwm actualizado en $target."
echo 'Cerrá dwm normalmente y volvé a iniciar startx para cargarlo. No se reinició tu sesión.'
