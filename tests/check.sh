#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
printf "\n%s\n%s\n" "LINUX-SETUP | PRUEBAS AUTOMÁTICAS" "===================================="
echo "Estas pruebas son simulaciones: no requieren ingresar números ni instalan paquetes."
echo
stage="Sintaxis POSIX"
echo "[1/5] Validando sintaxis de scripts..." 
sh -n "$root/install.sh"
sh -n "$root/bootstrap.sh"
sh -n "$root/lib/doas-persist-setup.sh"
sh -n "$root/lib/dshortcuts-setup.sh"
sh -n "$root/lib/dshortcuts-deps.sh"
sh -n "$root/lib/dwm-rofi-setup.sh"
sh -n "$root/lib/suckless-setup.sh"
sh -n "$root/lib/xorg-setup.sh"
grep -Fq 'adduser "$username" wheel' "$root/bootstrap.sh"
grep -Fq 'apk add doas git' "$root/bootstrap.sh"
grep -Fq 'apt-get install -y sudo git' "$root/bootstrap.sh"
grep -Fq "test_command='doas id -u'" "$root/bootstrap.sh"
grep -Fq 'for group in input video audio' "$root/lib/xorg-setup.sh"
grep -Fq 'dshortcuts_as_root adduser "$current_user" "$group"' "$root/lib/xorg-setup.sh"
sh -n "$root/lib/module-selector.sh"
sh -n "$root/lib/linux-doctor-setup.sh"
sh -n "$root/tests/module-selector.sh"
sh -n "$root/lib/installation-state.sh"
sh -n "$root/lib/module-updates.sh"
sh -n "$root/tests/installation-state.sh"
echo "      [OK] Sintaxis POSIX de instaladores y pruebas."
echo
stage="Selector de módulos"
printf "%s\n" "[2/5] Probando selectores (entradas simuladas)..." 
sh "$root/tests/module-selector.sh"
sh "$root/tests/installation-state.sh"
echo
stage="Integraciones y dependencias"
printf "%s\n" "[3/5] Revisando integraciones y dependencias..." 
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
# --verify no debe iniciar el selector ni exigir paquetes instalados.
if sh "$root/install.sh" --verify --modules dwm >/dev/null 2>&1; then
    echo 'FALLO: --verify aceptó opciones incompatibles.' >&2; exit 1
fi
sh -n "$root/tests/check.sh"
tmp=$(mktemp -d)
# Si cualquier test falla, indicar la etapa y conservar el código de error.
finish() {
    code=$?
    rm -rf "$tmp"
    if [ "$code" -ne 0 ]; then
        printf '\n[ERROR] Falló la etapa: %s (código %s).\n' "$stage" "$code" >&2
    fi
}
trap finish EXIT
trap 'exit 130' HUP INT TERM

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

echo '      [OK] Parches, plantillas y dependencias de dshortcuts.'
echo
stage='Instalación Alpine'
printf '%s\n' '[4/5] Simulando instalación en Alpine...' 
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
grep -Fq 'Xorg (Alpine): setup-xorg-base' "$tmp/result"
# Evitar regresión: preparar consola gráfica implica gestor de sesiones,
# no solo instalar xorg-server y añadir grupos.
grep -Fq '/sbin/apk add --no-cache dbus elogind' "$root/lib/xorg-setup.sh"
grep -Fq 'rc-update add "$service" default' "$root/lib/xorg-setup.sh"
grep -Fq 'rc-service "$service" start' "$root/lib/xorg-setup.sh"
grep -Fq 'rc-service "$service" status' "$root/lib/xorg-setup.sh"
grep -Fq 'seatd ya está habilitado' "$root/lib/xorg-setup.sh"

grep -Fq 'AVISO: setup-xorg-base puede habilitar community' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/lib/xorg-setup.sh" --dry-run > "$tmp/xorg-result"
grep -Fq 'no se modificaron paquetes, repositorios ni servicios' "$tmp/xorg-result"
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
# Sólo módulos fijados: consulta sin red y sin modificar el inventario.
mkdir -p "$tmp/update-state/linux-setup"
printf '%s\\n' '# linux-setup modules v1' 'dwm' 'st' > "$tmp/update-state/linux-setup/installed-modules"
XDG_STATE_HOME="$tmp/update-state" sh "$root/install.sh" --check-updates > "$tmp/check-updates"
grep -Fq '[FIJADOS] dwm st' "$tmp/check-updates"
grep -Fq 'ningún archivo modificado' "$tmp/check-updates"
XDG_STATE_HOME="$tmp/update-state" sh "$root/install.sh" --update --dry-run > "$tmp/update-dry-run"
grep -Fq 'ningún archivo modificado' "$tmp/update-dry-run"
if XDG_STATE_HOME="$tmp/update-state" sh "$root/install.sh" --modules doctor --check-updates > /dev/null 2>&1; then
    echo 'FALLO: el consultor aceptó un módulo no inventariado.' >&2; exit 1
fi
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules doctor --update --dry-run > "$tmp/result"
grep -Fq 'Simulación: actualizar linux-doctor' "$tmp/result"
if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules dwm,doctor --update --dry-run >/dev/null 2>&1; then
    echo 'FALLO: --update permitió modificar otros módulos.' >&2; exit 1
fi

echo '      [OK] Alpine: módulos, fuentes, whereis y linux-doctor.'
echo
stage='Instalación Debian'
printf '%s\n' '[5/5] Simulando instalación en Debian...' 
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
grep -Fq 'Xorg (Debian/Ubuntu)' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/lib/xorg-setup.sh" --dry-run > "$tmp/xorg-result"
grep -Fq 'no se modificaron paquetes ni servicios' "$tmp/xorg-result"
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
grep -Fq 'fish_add_path -g /sbin /usr/sbin /usr/local/sbin' "$root/install.sh"
grep -Fq "assume_yes=1" "$root/install.sh"
grep -Fq 'doas /bin/sh' "$root/install.sh"
grep -Fq "permit persist :wheel" "$root/lib/doas-persist-setup.sh"
grep -Fq "permit persist :wheel" "$root/bootstrap.sh"
grep -Fq 'fish -c' "$root/install.sh"
grep -Fq 'linux-setup-path.fish' "$root/install.sh"
test -f "$root/docs/primeros-pasos.md"
grep -Fq 'doas id -u' "$root/docs/primeros-pasos.md"
grep -Fq 'apt-get install -y sudo git' "$root/docs/primeros-pasos.md"
grep -Fq 'sudo id -u' "$root/docs/primeros-pasos.md"
if grep -Fq 'apt install doas' "$root/docs/primeros-pasos.md"; then
    echo 'FALLO: no se debe recomendar doas en Debian.' >&2
    exit 1
fi
echo '      [OK] Debian: módulos, fuentes, whereis y linux-doctor.'
printf '\n%s\n%s\n' '====================================' 'RESULTADO: TODAS LAS PRUEBAS SUPERADAS'
