#!/bin/sh
# Inventario gestionado y verificación de módulos instalados (sin root).
set -eu
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/linux-setup"
state="$state_dir/installed-modules"
known='fish rotate audio brightness wifi bluetooth rofi dshortcuts dwm st slock doctor'
usage() { echo 'Uso: sh lib/installation-state.sh --record MODULOS | --verify' >&2; }
valid() {
    case " $known " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}
record() {
    [ "$(id -u)" -ne 0 ] || { echo 'No registrar estado como root.' >&2; exit 1; }
    [ ! -L "$state_dir" ] && { [ ! -e "$state_dir" ] || [ -d "$state_dir" ]; } || {
        echo 'Directorio de estado no válido.' >&2; exit 1
    }
    [ ! -L "$state" ] && { [ ! -e "$state" ] || [ -f "$state" ]; } || {
        echo 'Archivo de estado no válido.' >&2; exit 1
    }
    # Validar por completo antes de escribir, incluida la versión anterior.
    old=''
    if [ -f "$state" ]; then
        while IFS= read -r name || [ -n "$name" ]; do
            case "$name" in '# linux-setup modules v1'|'') continue ;; esac
            valid "$name" || { echo "Módulo desconocido en registro: $name" >&2; exit 1; }
            case " $old " in *" $name "*) ;; *) old="$old $name" ;; esac
        done < "$state"
    fi
    new=''
    remaining=$1
    [ -n "$remaining" ] || { echo 'No hay módulos para registrar.' >&2; exit 2; }
    while [ -n "$remaining" ]; do
        case "$remaining" in
            *,*) name=${remaining%%,*}; remaining=${remaining#*,} ;;
            *) name=$remaining; remaining='' ;;
        esac
        valid "$name" || { echo "Módulo inválido: $name" >&2; exit 2; }
        case " $new " in *" $name "*) ;; *) new="$new $name" ;; esac
    done
    ( umask 077; mkdir -p "$state_dir" )
    tmp=$(mktemp "$state_dir/.installed-modules.XXXXXXXX")
    trap 'rm -f "$tmp"' EXIT HUP INT TERM
    printf '%s\n' '# linux-setup modules v1' > "$tmp"
    for name in $known; do
        case " $old $new " in *" $name "*) printf '%s\n' "$name" >> "$tmp" ;; esac
    done
    chmod 600 "$tmp"
    mv -f "$tmp" "$state"
    echo "Registro actualizado: $state"
}
ok=0 warn=0 fail=0
result() {
    level=$1; name=$2; message=$3
    printf '  [%-4s] %-13s %s\n' "$level" "$name" "$message"
    case "$level" in
        OK) ok=$((ok + 1)) ;;
        WARN) warn=$((warn + 1)) ;;
        FAIL) fail=$((fail + 1)) ;;
    esac
}
has() { command -v "$1" >/dev/null 2>&1; }
# Los forks se instalan en /usr/local/bin, ruta que puede no figurar en
# el PATH de una shell ash de Alpine o de la terminal que ejecuta --verify.
suckless_bin_dir=${LINUX_SETUP_SUCKLESS_BIN_DIR:-/usr/local/bin}
suckless_installed() {
    has "$1" || { [ -f "$suckless_bin_dir/$1" ] && [ -x "$suckless_bin_dir/$1" ]; }
}
verify_one() {
    name=$1
    case "$name" in
        fish)
            if ! has fish; then result FAIL fish 'Fish no se encuentra'; return; fi
            if fish -c 'contains -- /sbin $PATH; and contains -- /usr/sbin $PATH' >/dev/null 2>&1; then
                result OK fish 'Fish y rutas administrativas disponibles'
            else result WARN fish 'Fish funciona, pero faltan rutas administrativas'; fi ;;
        rotate)
            if has fish && fish -c 'functions -q r90' >/dev/null 2>&1 && has xrandr && has xinput; then
                result OK rotate 'Función Fish y herramientas X11 disponibles'
            else result FAIL rotate 'Falta una función o dependencia de rotación'; fi ;;
        audio)
            if [ -x "$HOME/.local/bin/lt-volume" ]; then
                result OK audio 'Herramientas instaladas; dispositivo no comprobado'
            else result FAIL audio 'Falta lt-volume'; fi ;;
        brightness)
            if [ -x "$HOME/.local/bin/lt-brightness" ]; then result OK brightness 'Herramienta disponible'
            else result FAIL brightness 'Falta lt-brightness'; fi ;;
        wifi)
            if [ -x "$HOME/.local/bin/lt-wifi" ]; then result OK wifi 'Herramienta disponible; conexión no comprobada'
            else result FAIL wifi 'Falta lt-wifi'; fi ;;
        bluetooth)
            if [ -x "$HOME/.local/bin/lt-bluetooth" ]; then result OK bluetooth 'Herramienta disponible; adaptador no comprobado'
            else result FAIL bluetooth 'Falta lt-bluetooth'; fi ;;
        rofi)
            if has rofi; then result OK rofi 'Lanzador disponible'
            else result FAIL rofi 'No se encontró rofi'; fi ;;
        dshortcuts)
            if has dshortcuts; then result OK dshortcuts 'Lanzador disponible'
            else result FAIL dshortcuts 'No se encontró dshortcuts'; fi ;;
        dwm)
            if ! suckless_installed dwm; then
                result FAIL dwm 'No se encontró dwm en PATH ni en /usr/local/bin'
            elif ! has startx; then
                result FAIL dwm 'Falta startx (xinit)'
            elif [ ! -f "$HOME/.xinitrc" ]; then
                result FAIL dwm 'Falta ~/.xinitrc'
            else
                result OK dwm 'dwm, startx y .xinitrc presentes; inicio no probado'
            fi ;;
        st|slock)
            if suckless_installed "$name"; then
                result OK "$name" 'Ejecutable disponible'
            else
                result FAIL "$name" 'Ejecutable no encontrado en PATH ni en /usr/local/bin'
            fi ;;
        doctor)
            if [ -x "$HOME/.local/bin/linux-doctor" ]; then
                result OK doctor 'Ejecutable disponible'
            else result FAIL doctor 'No se encuentra linux-doctor'; fi ;;
    esac
}
verify() {
    printf '\n%s\n' 'LINUX-SETUP | VERIFICACIÓN DEL SISTEMA'
    printf '%s\n' '====================================='
    if [ ! -f "$state" ] || [ -L "$state" ]; then
        echo 'Sin registro de módulos; no se asume qué componentes se instalaron.'
        echo 'Ejecutá sh install.sh con los módulos deseados para crear el registro.'
        return 2
    fi
    selected=''
    while IFS= read -r name || [ -n "$name" ]; do
        case "$name" in '# linux-setup modules v1'|'') continue ;; esac
        if ! valid "$name"; then
            result FAIL inventario "Módulo desconocido en registro: $name"
            continue
        fi
        case " $selected " in *" $name "*) continue ;; esac
        selected="$selected $name"
        verify_one "$name"
    done < "$state"
    [ -n "$selected" ] || result WARN inventario 'El registro está vacío'
    if [ -x "$HOME/.local/bin/linux-doctor" ] && [ -f "$state" ]; then
        # Los FAIL de linux-doctor no duplican los del inventario: diagnóstico
        # complementario, separado de la integridad de módulos seleccionados.
        diagnostic=$("$HOME/.local/bin/linux-doctor" --verbose 2>&1) || :
        summary=$(printf '%s\n' "$diagnostic" | grep '^Resumen:' | tail -n 1 || :)
        if [ -n "$summary" ]; then
            printf '\nDiagnóstico complementario: %s\n' "$summary"
        else
            result WARN doctor-diagnostico 'No se pudo obtener resumen de linux-doctor'
        fi
    fi
    printf '\nResumen: %s OK | %s advertencias | %s errores\n' "$ok" "$warn" "$fail"
    [ "$fail" -eq 0 ]
}
case "${1-}" in
    --record) [ "$#" -eq 2 ] || { usage; exit 2; }; record "$2" ;;
    --verify) [ "$#" -eq 1 ] || { usage; exit 2; }; verify ;;
    *) usage; exit 2 ;;
esac
