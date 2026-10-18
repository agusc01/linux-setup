#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/install.sh"
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

printf 'ID=debian\nVERSION_ID=13\n' > "$tmp/os-release"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules brightness --dry-run > "$tmp/result"
grep -Fq 'Sistema: Debian/Ubuntu' "$tmp/result"
grep -Fq 'Paquetes base: fish git x11-xserver-utils' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules wifi,bluetooth --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,wifi,bluetooth' "$tmp/result"

if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules noexiste --dry-run >/dev/null 2>&1; then
    echo 'FALLO: se aceptó un módulo desconocido.' >&2
    exit 1
fi
echo 'OK: Alpine/Debian, Fish obligatorio, Wi-Fi/Bluetooth opcionales, dry-run sin efectos.'
