#!/bin/sh
# Actualizaciones conscientes del inventario, sin elevar privilegios.
set -eu
mode=$1
filter=$2
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
state="${XDG_STATE_HOME:-$HOME/.local/state}/linux-setup/installed-modules"
tools_dir=${LINUX_SETUP_TOOLS_DIR:-"$HOME/.local/share/linux-setup/linux-tools"}
: "${LINUX_SETUP_ASSUME_YES:=0}"
known='fish rotate audio brightness wifi bluetooth rofi dshortcuts dwm st slock doctor'
if [ "$mode" = update ] && [ "$(id -u)" -eq 0 ]; then
    echo 'Ejecutá actualizaciones como usuario normal.' >&2; exit 1
fi
installed=''
if [ -f "$state" ] && [ ! -L "$state" ]; then
    while IFS= read -r name || [ -n "$name" ]; do
        case "$name" in '# linux-setup modules v1'|'') continue ;; esac
        case " $known " in *" $name "*) ;; *) echo "Registro inválido: $name" >&2; exit 1 ;; esac
        case " $installed " in *" $name "*) ;; *) installed="$installed $name" ;; esac
    done < "$state"
fi
if [ -n "$filter" ]; then
    selected=''
    case "$filter" in
        ,*|*,|*,,*) echo 'Lista de módulos vacía o mal formada.' >&2; exit 2 ;;
    esac
    for name in $(printf '%s' "$filter" | tr ',' ' '); do
        case " $known " in *" $name "*) ;; *) echo "Módulo desconocido: $name" >&2; exit 2 ;; esac
        case " $installed " in *" $name "*) ;; *)
            { [ "$name" = doctor ] && [ "$mode" != check ]; } || { echo "No registrado: $name" >&2; exit 2; } ;;
        esac
        selected="$selected $name"
    done
else
    selected=$installed
fi
[ -n "$selected" ] || { echo 'Sin inventario de módulos instalados.' >&2; exit 2; }
modules=''
doctor=0
pinned=''
for name in $selected; do
    case "$name" in
        doctor) doctor=1 ;;
        dwm|st|slock|dshortcuts) pinned="$pinned $name" ;;
        *) if [ -n "$modules" ]; then modules="$modules,$name"; else modules=$name; fi ;;
    esac
done
# Una consulta de componentes fijados no necesita git ni red.
if { [ -n "$modules" ] || [ "$doctor" -eq 1 ]; } && [ "$mode" != dry-run ]; then
    command -v git >/dev/null 2>&1 || { echo 'Falta git para consultar actualizaciones.' >&2; exit 1; }
fi
echo 'LINUX-SETUP | ACTUALIZACIONES'
echo '============================'
if [ -n "$pinned" ]; then
    echo "[FIJADOS]$pinned"
    echo 'Los forks se mantienen en las revisiones validadas, sin reemplazarlos.'
fi
changed=0
if [ -n "$modules" ]; then
    [ -d "$tools_dir/.git" ] && [ ! -L "$tools_dir" ] || {
        echo 'linux-tools: falta un checkout válido.' >&2; exit 1
    }
    origin=$(git -C "$tools_dir" remote get-url origin)
    case "$origin" in
        https://github.com/agusc01/linux-tools|https://github.com/agusc01/linux-tools.git) ;;
        *) echo 'linux-tools: origen inesperado.' >&2; exit 1 ;;
    esac
    [ "$(git -C "$tools_dir" branch --show-current)" = main ] || {
        echo 'linux-tools: no está en main.' >&2; exit 1
    }
    [ -z "$(git -C "$tools_dir" status --porcelain)" ] || {
        echo 'linux-tools: hay modificaciones locales; no se reemplazan.' >&2; exit 1
    }
    old=$(git -C "$tools_dir" rev-parse HEAD)
    remote=$(git ls-remote https://github.com/agusc01/linux-tools.git refs/heads/main | awk '{print $1}')
    [ -n "$remote" ] || { echo 'Sin respuesta de GitHub para linux-tools.' >&2; exit 1; }
    if [ "$old" = "$remote" ]; then
        echo '[OK] linux-tools actualizado'
    else
        changed=1
        echo "[DISPONIBLE] linux-tools $old -> $remote"
    fi
fi
doctor_changed=0
if [ "$doctor" -eq 1 ]; then
    app="$HOME/.local/share/linux-doctor"
    if [ -d "$app" ] && [ ! -L "$app" ]; then
        if [ "$mode" = dry-run ]; then
            echo '[REVISAR] linux-doctor: simulación sin descarga ni cambios.'
        else
            work=$(mktemp -d)
            trap 'rm -rf "$work"' EXIT HUP INT TERM
            git clone --quiet --depth 1 --single-branch --branch main https://github.com/agusc01/linux-doctor.git "$work/doctor"
            doctor_changed=0
            for file in doctor.sh lib/core.sh lib/services.sh; do
                if ! cmp -s "$app/$file" "$work/doctor/$file"; then doctor_changed=1; fi
            done
            if [ "$doctor_changed" -eq 0 ]; then
                echo '[OK] linux-doctor actualizado.'
            else
                echo '[DISPONIBLE] linux-doctor tiene archivos nuevos.'
            fi
        fi
    else
        if [ "$mode" = update ]; then
            echo 'linux-doctor: no hay instalación segura; no se reemplaza.' >&2; exit 1
        fi
        echo '[PENDIENTE] linux-doctor no tiene una instalación verificable.'
    fi
fi
if [ "$mode" = check ] || [ "$mode" = dry-run ]; then
    echo 'Simulación: actualizar linux-doctor o linux-tools según selección; ningún archivo modificado.'
    exit 0
fi
if [ "$LINUX_SETUP_ASSUME_YES" != 1 ]; then
    [ -t 0 ] || { echo 'Se requiere terminal o --yes.' >&2; exit 2; }
    printf '¿Actualizar los componentes compatibles? [s/N]: '
    IFS= read -r answer || answer=''
    case "$answer" in s|S|si|SI|Si) ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi
if [ "$changed" -eq 1 ]; then
    base="$HOME/.local/state/linux-setup/backups"
    mkdir -p "$base"
    backup=$(mktemp -d "$base/tools.XXXXXXXX")
    for dir in "$HOME/.config/fish" "$HOME/.local/bin" "$HOME/.local/share/linux-tools"; do
        [ -d "$dir" ] || continue
        find "$dir" -type f | while IFS= read -r path; do
            if grep -Flq '# linux-tools-managed: agusc01/linux-tools' "$path" 2>/dev/null; then
                relative=$(printf '%s' "$path" | sed "s|^$HOME/||")
                mkdir -p "$backup/$(dirname "$relative")"
                cp -p "$path" "$backup/$relative"
                printf '%s\n' "$relative" >> "$backup/manifest"
            fi
        done
    done
    git -C "$tools_dir" fetch origin main
    git -C "$tools_dir" merge-base --is-ancestor "$old" FETCH_HEAD || {
        echo 'linux-tools: no es fast-forward; no se actualiza.' >&2; exit 1
    }
    [ "$(git -C "$tools_dir" rev-parse FETCH_HEAD)" = "$remote" ] || {
        echo 'La revisión remota cambió; ejecutá el comando nuevamente.' >&2; exit 1
    }
    git -C "$tools_dir" merge --ff-only FETCH_HEAD
    if sh "$tools_dir/install.sh" --modules "$modules" --no-deps --yes; then
        echo "[OK] linux-tools actualizado. Backup: $backup"
    else
        git -C "$tools_dir" reset --hard "$old"
        if [ -f "$backup/manifest" ]; then
            while IFS= read -r relative; do
                cp -p "$backup/$relative" "$HOME/$relative"
            done < "$backup/manifest"
        fi
        echo 'Falló la actualización: se restauraron los archivos conocidos.' >&2
        exit 1
    fi
fi
if [ "$doctor_changed" -eq 1 ]; then
    sh "$root/lib/linux-doctor-setup.sh" --update
fi
echo 'Actualización terminada. Ejecutá sh install.sh --verify.'
