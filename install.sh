#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Bootstrap portable. Fish es obligatorio, pero no hace falta para arrancar.
set -eu
dry_run=0
assume_yes=0
modules=''
tools_dir=${LINUX_SETUP_TOOLS_DIR:-"$HOME/.local/share/linux-setup/linux-tools"}
release=/etc/os-release

usage() {
    printf '%s\n' \
        'Uso: sh install.sh [--modules fish,rotate,audio,brightness,wifi,bluetooth,rofi,dshortcuts] [--dry-run] [--yes] [--tools-dir RUTA]' \
        'Fish es obligatorio; los módulos opcionales se delegan a linux-tools.' \
        'No instala ni configura doas. Acepta doas/sudo/su ya disponibles.'
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --modules)
            [ "$#" -ge 2 ] || { echo 'Error: falta lista de módulos.' >&2; exit 2; }
            modules=$2; shift 2 ;;
        --tools-dir)
            [ "$#" -ge 2 ] || { echo 'Error: falta ruta de linux-tools.' >&2; exit 2; }
            tools_dir=$2; shift 2 ;;
        --yes) assume_yes=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        *) echo "Error: opción desconocida $1" >&2; exit 2 ;;
    esac
done

if [ "$dry_run" -eq 1 ] && [ -n "${LINUX_SETUP_OS_RELEASE:-}" ]; then
    release=$LINUX_SETUP_OS_RELEASE
fi
[ -r "$release" ] || { echo 'Error: no hay /etc/os-release.' >&2; exit 1; }
. "$release"
case "$ID" in
    alpine)
        distro=Alpine
        pkg=/sbin/apk
        if [ ! -x "$pkg" ] && [ "$dry_run" -eq 0 ]; then
            echo 'Error: no se encontró /sbin/apk.' >&2; exit 1
        fi
        ;;
    debian|ubuntu)
        distro=Debian/Ubuntu
        pkg=/usr/bin/apt-get
        if [ ! -x "$pkg" ] && [ "$dry_run" -eq 0 ]; then
            echo 'Error: no se encontró apt-get.' >&2; exit 1
        fi
        ;;
    *) echo "Distribución no soportada: $ID" >&2; exit 1 ;;
esac

if [ -z "$modules" ]; then
    modules=fish,rotate,audio,brightness
    if [ -t 0 ] && [ "$assume_yes" -eq 0 ] && [ "$dry_run" -eq 0 ]; then
        echo 'Seleccioná los módulos (separados por coma):'
        echo 'fish [obligatorio], rotate [pantalla táctil X11], audio, brightness [X11], wifi, bluetooth, rofi, dshortcuts'
        printf 'Módulos [fish,rotate,audio,brightness]: '
        IFS= read -r reply || reply=''
        if [ -n "$reply" ]; then modules=$reply; fi
    fi
fi
requested=$modules
want_rotate=0
want_audio=0
want_brightness=0
want_wifi=0
want_bluetooth=0
want_rofi=0
want_dshortcuts=0
while [ -n "$requested" ]; do
    case "$requested" in
        *,*) item=${requested%%,*}; requested=${requested#*,} ;;
        *) item=$requested; requested='' ;;
    esac
    case "$item" in
        fish) : ;;
        rotate) want_rotate=1 ;;
        audio) want_audio=1 ;;
        brightness) want_brightness=1 ;;
        wifi) want_wifi=1 ;;
        bluetooth) want_bluetooth=1 ;;
        rofi) want_rofi=1 ;;
        dshortcuts) want_dshortcuts=1 ;;
        *) echo "Módulo no disponible: $item" >&2; exit 2 ;;
    esac
done

# Un menú completo necesita los comandos de sus submenús.
# No se copia ni parchea el fork original en GitHub.
if [ "$want_dshortcuts" -eq 1 ]; then
    want_rotate=1
    want_audio=1
    want_brightness=1
    want_wifi=1
    want_bluetooth=1
    want_rofi=1
fi
selected=fish
[ "$want_rotate" -eq 0 ] || selected="$selected,rotate"
[ "$want_audio" -eq 0 ] || selected="$selected,audio"
[ "$want_brightness" -eq 0 ] || selected="$selected,brightness"
[ "$want_wifi" -eq 0 ] || selected="$selected,wifi"
[ "$want_bluetooth" -eq 0 ] || selected="$selected,bluetooth"
[ "$want_rofi" -eq 0 ] || selected="$selected,rofi"
if [ "$want_dshortcuts" -eq 1 ]; then
    selected="$selected,shortcuts"
fi

. "$(CDPATH= cd "$(dirname "$0")" && pwd)/lib/dshortcuts-deps.sh"
packages='fish git'
if [ "$ID" = alpine ]; then
    if [ "$want_rotate" -eq 1 ]; then packages="$packages xrandr xinput"
    elif [ "$want_brightness" -eq 1 ]; then packages="$packages xrandr"; fi
else
    if [ "$want_rotate" -eq 1 ]; then packages="$packages x11-xserver-utils xinput"
    elif [ "$want_brightness" -eq 1 ]; then packages="$packages x11-xserver-utils"; fi
fi
if [ "$want_dshortcuts" -eq 1 ]; then
    packages="$packages $(dshortcuts_packages "$ID")"
fi
echo "Sistema: $distro"
echo "Módulos: $selected"
echo "Paquetes base: $packages"
echo "Código de herramientas: $tools_dir"
echo 'Audio, Wi-Fi, Bluetooth y Rofi se delegan a linux-tools; no se sustituyen redes activas.'
if [ "$want_dshortcuts" -eq 1 ]; then
    echo 'dshortcuts: se compilará una copia temporal del fork, no se modificarán sus fuentes originales.'
    sh "$(CDPATH= cd "$(dirname "$0")" && pwd)/lib/dshortcuts-setup.sh" --dry-run
fi

if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: no se instalaron paquetes, no se clonó nada y no se modificaron archivos.'
    exit 0
fi
[ "$(id -u)" -ne 0 ] || { echo 'Error: ejecutá como usuario normal (doas/su solo para paquetes).' >&2; exit 1; }
case "$tools_dir" in
    /*) : ;;
    *) echo 'Error: --tools-dir debe ser una ruta absoluta.' >&2; exit 2 ;;
esac
if [ "$assume_yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Error: se requiere confirmación interactiva o --yes.' >&2; exit 2; }
    printf '¿Instalar paquetes y ejecutar linux-tools? [s/N]: '
    IFS= read -r reply || reply=''
    case "$reply" in s|S|si|Si|SI) : ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi

admin() {
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif command -v doas >/dev/null 2>&1; then doas "$@"
    elif command -v sudo >/dev/null 2>&1; then sudo "$@"
    elif command -v su >/dev/null 2>&1; then
        # Comandos y paquetes son una lista fija, no entradas arbitrarias.
        su -c "$*"
    else
        echo 'Error: necesitás doas, sudo o su para instalar paquetes.' >&2
        return 1
    fi
}
if [ "$ID" = alpine ]; then
    admin "$pkg" add --no-cache $packages
else
    admin "$pkg" install -y $packages
fi

if [ -e "$tools_dir" ]; then
    [ -d "$tools_dir/.git" ] || {
        echo "Error: $tools_dir ya existe pero no es un repositorio git válido." >&2; exit 1
    }
    [ "$(git -C "$tools_dir" branch --show-current)" = main ] || {
        echo 'Error: linux-tools tiene una rama distinta de main. Actualizalo manualmente.' >&2; exit 1
    }
    git -C "$tools_dir" pull --ff-only origin main
else
    mkdir -p "$(dirname "$tools_dir")"
    git clone --single-branch --branch main https://github.com/agusc01/linux-tools.git "$tools_dir"
fi
[ -f "$tools_dir/install.sh" ] || { echo 'Error: linux-tools no contiene install.sh.' >&2; exit 1; }

echo 'Delegando módulos a linux-tools...'
if [ "$assume_yes" -eq 1 ]; then
    sh "$tools_dir/install.sh" --modules "$selected" --yes
else
    sh "$tools_dir/install.sh" --modules "$selected"
fi
if [ "$want_dshortcuts" -eq 1 ]; then
    setup_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
    if [ "$assume_yes" -eq 1 ]; then
        sh "$setup_root/lib/dshortcuts-setup.sh" --yes
    else
        sh "$setup_root/lib/dshortcuts-setup.sh"
    fi
fi
echo 'Instalación finalizada. Si acabás de instalar sof-firmware, reiniciá y probá aplay -l.'
