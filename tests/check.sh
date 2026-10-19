#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/install.sh"
sh -n "$root/lib/dshortcuts-setup.sh"
"$root/lib/dshortcuts-setup.sh" --dry-run | grep -q 'fork agusc01/dshortcuts'
test -f "$root/profiles/dshortcuts/config.h"
test -f "$root/profiles/dshortcuts/items.h"
if grep -Fq '.bash_scripts/' "$root/profiles/dshortcuts/items.h"; then
    echo 'FALLO: menú nuevo depende de Bash.' >&2; exit 1
fi
sh -n "$root/tests/check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

printf 'ID=alpine\nVERSION_ID=3.24.2\n' > "$tmp/os-release"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules audio,rotate --dry-run > "$tmp/result"
grep -Fq 'Sistema: Alpine' "$tmp/result"
grep -Fxq 'Módulos: fish,rotate,audio' "$tmp/result"
grep -Fq 'xrandr xinput' "$tmp/result"

LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules wifi,bluetooth --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,wifi,bluetooth' "$tmp/result"
grep -Fq 'Paquetes base: fish git' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules rofi --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rofi' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules dshortcuts --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rotate,audio,brightness,wifi,bluetooth,rofi,shortcuts' "$tmp/result"
grep -q 'build-base patch libx11-dev' "$tmp/result"

printf 'ID=debian\nVERSION_ID=13\n' > "$tmp/os-release"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules brightness --dry-run > "$tmp/result"
grep -Fq 'Sistema: Debian/Ubuntu' "$tmp/result"
grep -Fq 'Paquetes base: fish git x11-xserver-utils' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules wifi,bluetooth --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,wifi,bluetooth' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules rofi --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rofi' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules dshortcuts --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,rotate,audio,brightness,wifi,bluetooth,rofi,shortcuts' "$tmp/result"
grep -q 'build-essential patch libx11-dev' "$tmp/result"

if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules noexiste --dry-run >/dev/null 2>&1; then
    echo 'FALLO: se aceptó un módulo desconocido.' >&2
    exit 1
fi
echo 'OK: Alpine/Debian, Fish obligatorio, Wi-Fi/Bluetooth/Rofi/dshortcuts opcionales, dry-run sin efectos.'
