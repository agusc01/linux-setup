#!/bin/sh
# Política temporalmente persistente (no nopass) para evitar repetir
# autenticaciones durante una instalación larga. Solo archivo propio.
set -eu
[ "$(id -u)" -eq 0 ] || { echo 'Error: ejecutar como root mediante doas.' >&2; exit 1; }
conf=/etc/doas.d/linux-setup.conf
[ -d /etc/doas.d ] || { echo 'Error: falta /etc/doas.d.' >&2; exit 1; }
[ ! -L "$conf" ] || { echo 'Error: regla doas enlazada, no se modifica.' >&2; exit 1; }
if [ -e "$conf" ]; then
    [ -f "$conf" ] || { echo 'Error: la regla doas no es un archivo regular.' >&2; exit 1; }
    old=$(cat "$conf")
    case "$old" in
        'permit :wheel'|'permit persist :wheel') ;;
        *) echo 'Error: hay una regla doas propia modificada; no se sobrescribe.' >&2; exit 1 ;;
    esac
fi
# No tocar políticas de terceros ni deshabilitar autenticación.
if [ ! -e "$conf" ] || [ "$(cat "$conf")" != 'permit persist :wheel' ]; then
    tmp=$(mktemp /etc/doas.d/.linux-setup.XXXXXXXX)
    trap 'rm -f "$tmp"' EXIT HUP INT TERM
    printf '%s\n' 'permit persist :wheel' > "$tmp"
    chmod 0400 "$tmp"
    mv -f "$tmp" "$conf"
fi
echo 'Autenticación doas: persist habilitado; nunca se configura nopass.'
