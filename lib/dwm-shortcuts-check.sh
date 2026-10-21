#!/bin/sh
# Auditoría de comandos de atajos de dwm. No ejecuta atajos ni modifica fuentes.
set -eu
mode=${1---report}
case "$mode" in --report|--quiet) ;; *) echo 'Uso: sh lib/dwm-shortcuts-check.sh [--report|--quiet]' >&2; exit 2 ;; esac
source_dir="${LINUX_SETUP_SOURCE_DIR:-$HOME/.local/src}/dwm"
if [ -L "$source_dir" ] || [ -L "$source_dir/keys.h" ] || [ -L "$source_dir/launchers.h" ]; then
    echo "Error: la fuente de dwm contiene enlaces simbólicos inesperados." >&2
    exit 2
fi
[ -f "$source_dir/keys.h" ] || {
    echo "No se encontró $source_dir/keys.h; recuperá las fuentes con --save-sources." >&2
    exit 2
}
[ -f "$source_dir/launchers.h" ] || {
    echo "No se encontró $source_dir/launchers.h; falta la configuración de launchers." >&2
    exit 2
}
# Se extrae solo el primer ejecutable de SHCMD("...") y de los launchers
# conocidos en tu fork. Las líneas comentadas no se interpretan.
# No se usa eval, source ni fish -c con texto no validado.
commands=$(
    sed -n '/^[[:space:]]*\/\//d; s/.*SHCMD("\([^"]*\)").*/\1/p' "$source_dir/keys.h"
    sed -n '/^[[:space:]]*\/\//d; s/.*"\(rofi_[a-z_]*\)".*/\1/p' "$source_dir/launchers.h"
)
missing=0
checked=''
[ "$mode" = --quiet ] || printf '\n%s\n' 'DWM | AUDITORÍA DE ATAJOS (SOLO LECTURA)'
while IFS= read -r args || [ -n "$args" ]; do
    [ -n "$args" ] || continue
    cmd=${args%% *}
    # Sin metacaracteres ni rutas arbitrarias; solo nombres de comandos.
    case "$cmd" in ''|*[!a-zA-Z0-9_-]*) continue ;; esac
    case " $checked " in *" $cmd "*) continue ;; esac
    checked="$checked $cmd"
    if command -v fish >/dev/null 2>&1 &&
       fish -c "functions -q -- $cmd; or command -sq -- $cmd" >/dev/null 2>&1; then
        state=OK
    elif command -v "$cmd" >/dev/null 2>&1; then
        state=OK
    else
        state=FALTA
        missing=$((missing + 1))
    fi
    [ "$mode" = --quiet ] || printf '  [%-5s] %s\n' "$state" "$cmd"
    if [ "$mode" != --quiet ] && [ "$state" = FALTA ]; then
        case "$cmd" in
            rofi_menu) echo '          Alternativa disponible: lt-rofi menu' ;;
            rofi_launcher) echo '          Alternativa disponible: lt-rofi apps' ;;
            rofi_internet) echo '          Alternativa disponible: lt-rofi wifi' ;;
            rofi_power) echo '          Revisar el menú de energía; no sustituir por comandos peligrosos automáticamente' ;;
            s0|s1|stogglemute) echo '          Alternativas disponibles: lt-volume down|up|toggle --notify' ;;
            b0|b1) echo '          Alternativas disponibles: lt-brightness down|up --notify' ;;
            *) echo '          Dependencia del atajo no instalada o función Fish no definida' ;;
        esac
    fi
done <<EOF
$commands
EOF
[ "$mode" = --quiet ] || printf 'Comandos distintos: %s | faltantes: %s\n' "$(printf '%s\n' "$checked" | wc -w | tr -d ' ')" "$missing"
[ "$missing" -eq 0 ]
