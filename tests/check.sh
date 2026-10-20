#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/install.sh"
sh -n "$root/lib/dshortcuts-setup.sh"
sh -n "$root/lib/dshortcuts-deps.sh"
sh -n "$root/lib/dwm-rofi-setup.sh"
sh -n "$root/lib/suckless-setup.sh"
sh -n "$root/lib/module-selector.sh"
sh -n "$root/lib/linux-doctor-setup.sh"
sh -n "$root/tests/module-selector.sh"
sh "$root/tests/module-selector.sh"
grep -Fq 'master->next = NULL' "$root/profiles/dshortcuts/safe.patch"
grep -Fq 'c = MAX(1, c)' "$root/profiles/dshortcuts/safe.patch"
grep -Fq 'view(&a)' "$root/profiles/dwm/rofi-window-focus.patch"
grep -Fq 'focus(c)' "$root/profiles/dwm/rofi-window-focus.patch"

"$root/lib/dshortcuts-setup.sh" --dry-run | grep -q 'fork agusc01/dshortcuts'
"$root/lib/dshortcuts-setup.sh" --dry-run | grep -q 'Paquetes gestionados automáticamente'
test -f "$root/profiles/dshortcuts/config.h"
test -f "$root/profiles/dshortcuts/items.h"
if grep -Fq '.bash_scripts/' "$root/profiles/dshortcuts/items.h"; then
    echo 'FALLO: menú nuevo depende de Bash.' >&2; exit 1
fi
sh -n "$root/tests/check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# Una ejecución directa de lib/dshortcuts-setup.sh instala el paquete que falte,
# sin pedirle al usuario que lo instale por separado.
. "$root/lib/dshortcuts-deps.sh"
test "$(dshortcuts_packages alpine)" = 'build-base patch libx11-dev libxft-dev libxinerama-dev libxext-dev fontconfig-dev freetype-dev'
test "$(dshortcuts_packages debian)" = 'build-essential patch libx11-dev libxft-dev libxinerama-dev libxext-dev libfontconfig1-dev libfreetype-dev'
(
    dshortcuts_package_installed() {
        [ "$2" != patch ] || [ -f "$tmp/patch-installed" ]
    }
    dshortcuts_install_packages() {
        [ "$1" = alpine ] && [ "$2" = patch ] && [ "$#" -eq 2 ] || return 1
        : > "$tmp/patch-installed"
    }
    dshortcuts_ensure_dependencies alpine
) > "$tmp/deps-result"
test -f "$tmp/patch-installed"
grep -Fq 'Instalando dependencias faltantes de dshortcuts: patch' "$tmp/deps-result"
(
    dshortcuts_package_installed() { return 0; }
    dshortcuts_install_packages() { echo 'FALLO: instaló paquetes innecesarios.' >&2; return 1; }
    dshortcuts_ensure_dependencies alpine
) | grep -Fq 'Dependencias de dshortcuts: ya instaladas.'

printf 'ID=alpine\nVERSION_ID=3.24.2\n' > "$tmp/os-release"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules audio,rotate --dry-run > "$tmp/result"
grep -Fq 'Sistema: Alpine' "$tmp/result"
grep -Fxq 'Módulos: fish,rotate,audio' "$tmp/result"
grep -Fq 'Paquetes base: fish git util-linux-misc' "$tmp/result"
grep -Fq 'xrandr xinput' "$tmp/result"

LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules wifi,bluetooth --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,wifi,bluetooth' "$tmp/result"
grep -Fq 'Paquetes base: fish git' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules rofi --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rofi' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules dshortcuts --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rotate,audio,brightness,wifi,bluetooth,rofi,shortcuts' "$tmp/result"
grep -q 'build-base patch libx11-dev' "$tmp/result"

LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules dwm,st,slock --dry-run > "$tmp/result"
grep -Fxq 'Suckless: dwm,st,slock' "$tmp/result"
grep -Fq 'imlib2-dev se instala desde community temporal' "$tmp/result"
grep -Fq 'font-dejavu' "$tmp/result"
grep -Fq 'DejaVu Sans Mono' "$root/lib/suckless-setup.sh"
grep -Fq 'Ubuntu:size=' "$root/lib/suckless-setup.sh"
grep -Fq 'Liberation Mono:' "$root/lib/suckless-setup.sh"
grep -Fq 'ATENCIÓN: slock usa setuid-root' "$tmp/result"
grep -Fq 'Simulación: no se instalaron paquetes' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/lib/suckless-setup.sh" --modules st --build-only --dry-run > "$tmp/result"
grep -Fq 'Modo compilación:' "$tmp/result"

LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules doctor --dry-run > "$tmp/result"
grep -Fq 'Módulo adicional: linux-doctor' "$tmp/result"
grep -Fq 'Doctor: simulación' "$tmp/result"
sh "$root/lib/linux-doctor-setup.sh" --dry-run | grep -Fq 'sin cambios ni reparaciones'

printf 'ID=debian\nVERSION_ID=13\n' > "$tmp/os-release"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules doctor --dry-run > "$tmp/result"
grep -Fq 'Módulo adicional: linux-doctor' "$tmp/result"
grep -Fq 'Doctor: simulación' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules brightness --dry-run > "$tmp/result"
grep -Fq 'Sistema: Debian/Ubuntu' "$tmp/result"
grep -Fq 'Paquetes base: fish git util-linux x11-xserver-utils' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules wifi,bluetooth --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,wifi,bluetooth' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules rofi --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rofi' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules dshortcuts --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rotate,audio,brightness,wifi,bluetooth,rofi,shortcuts' "$tmp/result"
grep -q 'build-essential patch libx11-dev' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules dwm,st,slock --dry-run > "$tmp/result"
grep -Fq 'libimlib2-dev' "$tmp/result"
grep -Fq 'ncurses-bin' "$tmp/result"
grep -Fq 'fonts-dejavu-core' "$tmp/result"
grep -Fq 'libxrandr-dev' "$tmp/result"

if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules noexiste --dry-run >/dev/null 2>&1; then
    echo 'FALLO: se aceptó un módulo desconocido.' >&2
    exit 1
fi
if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/lib/suckless-setup.sh" --modules st,st --dry-run >/dev/null 2>&1; then
    echo 'FALLO: suckless aceptó un módulo repetido.' >&2
    exit 1
fi
if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/lib/suckless-setup.sh" --modules dwm,st --source /tmp --dry-run >/dev/null 2>&1; then
    echo 'FALLO: suckless permitió usar un solo --source para múltiples módulos.' >&2
    exit 1
fi
grep -Fq 'fish_add_path /sbin /usr/sbin' "$root/install.sh"
grep -Fq 'linux-setup-path.fish' "$root/install.sh"
test -f "$root/docs/primeros-pasos.md"
grep -Fq 'permit :wheel' "$root/docs/primeros-pasos.md"
grep -Fq 'apt install sudo git' "$root/docs/primeros-pasos.md"
grep -Fq 'sudo apt update' "$root/docs/primeros-pasos.md"
if grep -Fq 'apt install doas' "$root/docs/primeros-pasos.md"; then
    echo 'FALLO: no se debe recomendar doas en Debian.' >&2
    exit 1
fi
echo 'OK: Alpine/Debian, Fish obligatorio, dependencias automáticas y módulos dwm/st/slock seguros.'
