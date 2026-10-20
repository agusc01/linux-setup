#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Compilación reproducible y no destructiva de los forks suckless.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/dshortcuts-deps.sh"
PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"
export PATH

modules=''
dry_run=0
assume_yes=0
reinstall=0
build_only=0
source_dir=''
release=/etc/os-release

usage() {
    echo 'Uso: sh lib/suckless-setup.sh --modules dwm,st,slock [--dry-run] [--yes] [--reinstall] [--build-only] [--source RUTA]'
    echo '--source admite un único módulo y nunca altera ese directorio.'
    echo 'Por seguridad, slock solo se instala si se selecciona expresamente.'
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --modules) [ "$#" -ge 2 ] || exit 2; modules=$2; shift 2 ;;
        --source) [ "$#" -ge 2 ] || exit 2; source_dir=$2; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        --yes) assume_yes=1; shift ;;
        --reinstall) reinstall=1; shift ;;
        --build-only) build_only=1; reinstall=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; exit 2 ;;
    esac
done
[ -n "$modules" ] || { usage >&2; exit 2; }
selected=''
remaining=$modules
count=0
while [ -n "$remaining" ]; do
    case "$remaining" in *,*) item=${remaining%%,*}; remaining=${remaining#*,} ;; *) item=$remaining; remaining='' ;; esac
    case "$item" in dwm|st|slock) ;; *) echo "Módulo desconocido: $item" >&2; exit 2 ;; esac
    case ",$selected," in *",$item,"*) echo "Módulo duplicado: $item" >&2; exit 2 ;; esac
    if [ -z "$selected" ]; then selected=$item; else selected="$selected,$item"; fi
    count=$((count + 1))
done
[ -z "$source_dir" ] || [ "$count" -eq 1 ] || {
    echo 'Error: --source requiere seleccionar un único módulo.' >&2; exit 2
}
if [ "$dry_run" -eq 1 ] && [ -n "${LINUX_SETUP_OS_RELEASE:-}" ]; then
    release=$LINUX_SETUP_OS_RELEASE
fi
[ -r "$release" ] || { echo 'No se encontró /etc/os-release.' >&2; exit 1; }
. "$release"
case "$ID" in alpine|debian|ubuntu) ;; *) echo "Sistema no soportado: $ID" >&2; exit 1 ;; esac

revision() {
    case "$1" in
        dwm) echo f5521a41823b78d44af4f2675bda5432aa0d6542 ;;
        st) echo 0dd918c6499f5eacebf25699b8ebd4739b93138a ;;
        slock) echo 9871c305378699f482f8148b4d7e478021477365 ;;
    esac
}
packages_for() {
    case "$ID:$1" in
        alpine:dwm) echo 'git build-base pkgconf libx11-dev libxft-dev libxinerama-dev libxrender-dev libxcomposite-dev libxext-dev fontconfig-dev freetype-dev xorg-server xinit' ;;
        alpine:st) echo 'git build-base pkgconf libx11-dev libxft-dev fontconfig-dev freetype-dev ncurses' ;;
        alpine:slock) echo 'git build-base libx11-dev libxext-dev libxrandr-dev' ;;
        debian:dwm|ubuntu:dwm) echo 'git build-essential pkg-config libx11-dev libxft-dev libxinerama-dev libxrender-dev libxcomposite-dev libxext-dev libimlib2-dev libfontconfig1-dev libfreetype-dev xserver-xorg xinit' ;;
        debian:st|ubuntu:st) echo 'git build-essential pkg-config libx11-dev libxft-dev libfontconfig1-dev libfreetype-dev ncurses-bin' ;;
        debian:slock|ubuntu:slock) echo 'git build-essential libx11-dev libxext-dev libxrandr-dev' ;;
    esac
}
all_packages=''
for name in $(printf '%s' "$selected" | tr ',' ' '); do
    for pkg in $(packages_for "$name"); do
        case " $all_packages " in *" $pkg "*) ;; *) all_packages="$all_packages $pkg" ;; esac
    done
done
all_packages=${all_packages# }
target_prefix=/usr/local/bin

echo "Suckless: $selected"
echo "Paquetes necesarios ($ID): $all_packages"
if [ "$ID" = alpine ]; then
    case ",$selected," in *,dwm,*)
        echo 'Alpine: imlib2-dev se instala desde community temporal, sin cambiar /etc/apk/repositories.' ;;
    esac
fi
echo 'Fuentes oficiales: forks agusc01 fijados por commit; no se modifica el repositorio original.'
if [ -n "$source_dir" ]; then echo "Fuente local (solo lectura): $source_dir"; fi
if [ "$build_only" -eq 1 ]; then
    echo 'Modo compilación: no se reemplazarán ejecutables ni se modificará terminfo.'
elif [ "$reinstall" -eq 0 ]; then
    echo 'Los ejecutables ya instalados NO se reemplazarán (usar --reinstall expresamente).'
else
    echo 'Se respaldará cada ejecutable existente antes de reemplazarlo.'
fi
case ",$selected," in *,slock,*) echo 'ATENCIÓN: slock usa setuid-root (4755). Probalo solo cuando sepas tu contraseña local.' ;; esac
if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: no se instalaron paquetes, compilaron programas ni reemplazaron archivos.'
    exit 0
fi
[ "$(id -u)" -ne 0 ] || { echo 'Ejecutá como usuario normal, no como root.' >&2; exit 1; }
if [ -n "$source_dir" ]; then
    [ -d "$source_dir" ] && [ -f "$source_dir/Makefile" ] || {
        echo "Directorio de fuentes inválido: $source_dir" >&2; exit 1
    }
fi
to_install=''
for name in $(printf '%s' "$selected" | tr ',' ' '); do
    target="$target_prefix/$name"
    [ ! -L "$target" ] && { [ ! -e "$target" ] || [ -f "$target" ]; } || {
        echo "Conflicto: $target no es un archivo regular." >&2; exit 1
    }
    if [ -f "$target" ] && [ "$reinstall" -eq 0 ]; then
        echo "Sin cambios: $target ya existe."
    else
        to_install="$to_install $name"
    fi
done
to_install=${to_install# }
[ -n "$to_install" ] || { echo 'Todos los módulos solicitados están instalados. No se cambió nada.'; exit 0; }

if [ "$assume_yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Necesitás una terminal interactiva o --yes.' >&2; exit 2; }
    printf '¿Instalar los componentes faltantes y sus dependencias? [s/N]: '
    IFS= read -r answer || answer=''
    case "$answer" in s|S|si|SI|Si) ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi

# Los paquetes son una lista fija por distro/módulo; elevación limitada a apk/apt-get.
needed=''
for name in $to_install; do
    for pkg in $(packages_for "$name"); do
        if ! dshortcuts_package_installed "$ID" "$pkg"; then
            case " $needed " in *" $pkg "*) ;; *) needed="$needed $pkg" ;; esac
        fi
    done
done
needed=${needed# }
if [ -n "$needed" ]; then
    echo "Instalando dependencias faltantes: $needed"
    if [ "$ID" = alpine ]; then
        # Word splitting deliberado: lista cerrada de paquetes por módulo.
        dshortcuts_as_root /sbin/apk add --no-cache $needed
    else
        dshortcuts_as_root /usr/bin/apt-get install -y $needed
    fi
fi
case " $to_install " in
    *" dwm "*|"dwm "*|*" dwm"|"dwm")
        if [ "$ID" = alpine ] && ! dshortcuts_package_installed alpine imlib2-dev; then
            stable=${VERSION_ID%.*}
            case "$stable" in *[!0-9.]*|'') echo 'Versión Alpine no válida.' >&2; exit 1 ;; esac
            community="https://dl-cdn.alpinelinux.org/alpine/v$stable/community"
            echo "Instalando imlib2-dev desde community temporal: $community"
            dshortcuts_as_root /sbin/apk add --no-cache --repository "$community" imlib2-dev
        fi ;;
esac

command -v git >/dev/null 2>&1 && command -v make >/dev/null 2>&1 && command -v cc >/dev/null 2>&1 || {
    echo 'Error: faltan git, make o cc después de preparar dependencias.' >&2; exit 1
}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

for name in $to_install; do
    echo "Compilando $name..."
    mkdir "$work/$name"
    if [ -n "$source_dir" ]; then
        cp -R "$source_dir/." "$work/$name/"
    else
        git -C "$work/$name" init -q
        git -C "$work/$name" remote add origin "https://github.com/agusc01/$name.git"
        git -C "$work/$name" fetch -q --depth 1 origin "$(revision "$name")"
        git -C "$work/$name" checkout -q --detach FETCH_HEAD
        [ "$(git -C "$work/$name" rev-parse HEAD)" = "$(revision "$name")" ] || {
            echo "Error: el commit de $name no coincide con la versión fijada." >&2; exit 1
        }
    fi
    if [ "$name" = dwm ]; then
        if ! grep -Fq 'linux-setup: rofi-window-focus' "$work/dwm/dwm.c"; then
            command -v patch >/dev/null 2>&1 || {
                echo 'Error: falta patch para aplicar integración Rofi-dwm.' >&2; exit 1
            }
            patch -s -d "$work/dwm" -p1 < "$root/profiles/dwm/rofi-window-focus.patch" || {
                echo 'No se pudo aplicar el parche Rofi al dwm suministrado; el binario instalado está intacto.' >&2
                exit 1
            }
        fi
    fi
    make -C "$work/$name" clean all
    [ -x "$work/$name/$name" ] || { echo "Falta el ejecutable compilado $name." >&2; exit 1; }
done

# Preparar terminfo antes de reemplazar st, para evitar dejar un st sin descripción de terminal.
case " $to_install " in *" st "*|"st "*|*" st"|"st")
    command -v tic >/dev/null 2>&1 || { echo 'Falta tic para st (ncurses).' >&2; exit 1; }
    [ -f "$work/st/st.info" ] || { echo 'Falta st.info.' >&2; exit 1; }
    mkdir -p "$HOME/.terminfo"
    tic -sx -o "$HOME/.terminfo" "$work/st/st.info"
    ;;
esac

if [ "$build_only" -eq 1 ]; then
    echo 'OK: todos los módulos seleccionados compilaron; no se modificaron ejecutables.'
    exit 0
fi

backup_base="$HOME/.local/state/linux-setup/backups"
for name in $to_install; do
    target="$target_prefix/$name"
    if [ -f "$target" ]; then
        mkdir -p "$backup_base"
        backup=$(mktemp -d "$backup_base/$name.XXXXXXXX")
        cp -p "$target" "$backup/$name"
        echo "Backup: $backup/$name"
    fi
    install_exe=$(command -v install) || { echo 'Falta install.' >&2; exit 1; }
    if [ "$name" = slock ]; then
        # Propietario root y setuid son necesarios para leer el hash local.
        dshortcuts_as_root "$install_exe" -o root -g root -m 4755 "$work/slock/slock" "$target"
        dshortcuts_as_root chmod 4755 "$target"
        echo 'slock instalado con permiso 4755; NO se iniciará automáticamente.'
    else
        dshortcuts_as_root "$install_exe" -o root -g root -m 0755 "$work/$name/$name" "$target"
    fi
    echo "Instalado: $target"
done
echo 'Instalación finalizada. No se cerró la sesión X11 ni se cambió ~/.xinitrc.'
