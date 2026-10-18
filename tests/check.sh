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
grep -q 'Sistema: Alpine' "$tmp/result"
grep -q 'Módulos: fish,rotate,audio' "$tmp/result"
grep -q 'xrandr xinput' "$tmp/result"
if grep -q 'brightness' "$tmp/result"; then
    # puede figurar en el texto general de help, no en selección efectiva
    grep -q '^Módulos: fish,rotate,audio$' "$tmp/result"
fi
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules wifi,bluetooth --dry-run > "$tmp/result"
grep -q '^Módulos: fish,wifi,bluetooth
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules brightness --dry-run > "$tmp/result"
grep -q 'Sistema: Debian/Ubuntu' "$tmp/result"
grep -q 'Paquetes base: fish git x11-xserver-utils' "$tmp/result"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules wifi,bluetooth --dry-run > "$tmp/result"
grep -q '^Módulos: fish,wifi,bluetooth
if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules noexiste --dry-run >/dev/null 2>&1; then
    echo 'FALLO: aceptó módulo desconocido.' >&2; exit 1
fi
echo 'OK: bootstrap Alpine/Debian, Fish obligatorio, módulos y dry-run.'
 "$tmp/result"
printf 'ID=debian\nVERSION_ID=13\n' > "$tmp/os-release"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules brightness --dry-run > "$tmp/result"
grep -q 'Sistema: Debian/Ubuntu' "$tmp/result"
grep -q 'Paquetes base: fish git x11-xserver-utils' "$tmp/result"
if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules noexiste --dry-run >/dev/null 2>&1; then
    echo 'FALLO: aceptó módulo desconocido.' >&2; exit 1
fi
echo 'OK: bootstrap Alpine/Debian, Fish obligatorio, módulos y dry-run.'
 "$tmp/result"
if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules noexiste --dry-run >/dev/null 2>&1; then
    echo 'FALLO: aceptó módulo desconocido.' >&2; exit 1
fi
echo 'OK: bootstrap Alpine/Debian, Fish obligatorio, módulos y dry-run.'
 "$tmp/result"
printf 'ID=debian\nVERSION_ID=13\n' > "$tmp/os-release"
LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules brightness --dry-run > "$tmp/result"
grep -q 'Sistema: Debian/Ubuntu' "$tmp/result"
grep -q 'Paquetes base: fish git x11-xserver-utils' "$tmp/result"
if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" --modules noexiste --dry-run >/dev/null 2>&1; then
    echo 'FALLO: aceptó módulo desconocido.' >&2; exit 1
fi
echo 'OK: bootstrap Alpine/Debian, Fish obligatorio, módulos y dry-run.'
