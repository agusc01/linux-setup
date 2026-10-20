#!/bin/sh
# Prepara Xorg al seleccionar dwm, sin pasos administrativos manuales.
# En Alpine utiliza la herramienta oficial que también configura eudev.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/dshortcuts-deps.sh"
PATH="$PATH:/sbin:/usr/sbin"
export PATH
mode=install
case "${1-}" in
    --dry-run) mode=dry-run ;;
    '') ;;
    *) echo 'Uso: sh lib/xorg-setup.sh [--dry-run]' >&2; exit 2 ;;
esac
release=/etc/os-release
if [ "$mode" = dry-run ] && [ -n "${LINUX_SETUP_OS_RELEASE:-}" ]; then
    release=$LINUX_SETUP_OS_RELEASE
fi
[ -r "$release" ] || { echo 'Error: falta os-release.' >&2; exit 1; }
. "$release"
case "$ID" in
    alpine)
        echo 'Xorg (Alpine): setup-xorg-base instala servidor, libinput, xinit, Mesa y configura eudev.'
        echo 'AVISO: setup-xorg-base puede habilitar community y sustituir mdev por eudev.'
        if [ "$mode" = dry-run ]; then
            echo 'Xorg: simulación; no se modificaron paquetes, repositorios ni servicios.'
            exit 0
        fi
        missing=0
        for pkg in xorg-server xf86-input-libinput xinit eudev mesa-dri-gallium; do
            if ! /sbin/apk info -e "$pkg" >/dev/null 2>&1; then missing=1; fi
        done
        # El servidor puede estar instalado sin que eudev esté registrado en OpenRC.
        if command -v rc-update >/dev/null 2>&1; then
            if ! rc-update show sysinit 2>/dev/null | grep -Eq '(^|[[:space:]])udev([[:space:]]|$)'; then
                missing=1
            fi
        fi
        if [ "$missing" -eq 0 ]; then
            echo 'Xorg: paquetes y configuración OpenRC ya presentes.'
        else
        command -v setup-xorg-base >/dev/null 2>&1 || {
            echo 'Error: Alpine no incluye setup-xorg-base (paquete alpine-conf).' >&2; exit 1
        }
        echo 'Xorg: preparando componentes y dispositivos con setup-xorg-base...'
        dshortcuts_as_root setup-xorg-base
        for pkg in xorg-server xf86-input-libinput xinit eudev mesa-dri-gallium; do
            /sbin/apk info -e "$pkg" >/dev/null 2>&1 || {
                echo "Error: Xorg no terminó de instalar $pkg." >&2; exit 1
            }
        done
        fi
        ;;
    debian|ubuntu)
        echo 'Xorg (Debian/Ubuntu): paquetes Xorg, xinit y libinput; acceso a dispositivos gestionado por la sesión.'
        if [ "$mode" = dry-run ]; then
            echo 'Xorg: simulación; no se modificaron paquetes ni servicios.'
            exit 0
        fi
        dshortcuts_as_root /usr/bin/apt-get install -y xserver-xorg xserver-xorg-input-libinput xinit
        ;;
    *) echo "Sistema no soportado: $ID" >&2; exit 1 ;;
esac
# Xorg iniciado desde una TTY necesita una sesión con acceso a VT/DRM.
# setup-xorg-base prepara eudev, pero no garantiza un gestor de sesiones.
if [ "$ID" = alpine ]; then
    if command -v rc-service >/dev/null 2>&1 && \
       { rc-service seatd status >/dev/null 2>&1 || \
         rc-update show default 2>/dev/null | grep -Eq '(^|[[:space:]])seatd([[:space:]]|$)'; }; then
        echo 'Xorg: seatd ya está habilitado; no se instala elogind en paralelo.' >&2
        echo 'Xorg: verificá el acceso a la TTY y el gestor de sesiones existente.' >&2
    else
        echo 'Xorg: preparando D-Bus y elogind para sesiones gráficas sin root...'
        dshortcuts_as_root /sbin/apk add --no-cache dbus elogind
        for service in dbus elogind; do
            if ! rc-update show default 2>/dev/null | grep -Eq "(^|[[:space:]])$service([[:space:]]|$)"; then
                dshortcuts_as_root rc-update add "$service" default
            fi
            if ! rc-service "$service" status >/dev/null 2>&1; then
                dshortcuts_as_root rc-service "$service" start
            fi
            rc-service "$service" status >/dev/null 2>&1 || {
                echo "Error: el servicio $service no está activo." >&2; exit 1
            }
        done
        echo 'Xorg: D-Bus y elogind habilitados y activos.'
        echo 'Xorg: reiniciá Alpine y abrí una nueva TTY antes de startx.'
    fi
fi
# Los permisos de dispositivos se aplican únicamente al usuario que pidió dwm,
# tras aceptar la instalación. Sin cambios en Debian: logind maneja ACL de sesión.
if [ "$ID" = alpine ]; then
    current_user=$(id -un)
    case "$current_user" in
        ''|root) echo 'Error: no se permite modificar grupos de root.' >&2; exit 1 ;;
    esac
    # Comprobar que la cuenta existe antes de elevar permisos.
    id "$current_user" >/dev/null 2>&1 || { echo 'Error: usuario no válido.' >&2; exit 1; }
    for group in input video audio; do
        if ! grep -q "^$group:" /etc/group; then
            echo "Xorg: no existe el grupo $group; se omite." >&2
            continue
        fi
        if id -nG "$current_user" | tr ' ' '\n' | grep -Fxq "$group"; then
            echo "Xorg: $current_user ya pertenece a $group."
        else
            echo "Xorg: agregando $current_user al grupo $group."
            dshortcuts_as_root adduser "$current_user" "$group"
            id -nG "$current_user" | tr ' ' '\n' | grep -Fxq "$group" || {
                echo "Error: falló la asignación de grupo $group." >&2; exit 1
            }
            echo "Xorg: cerrá la sesión y volvé a ingresar para aplicar $group."
        fi
    done
fi
echo 'Xorg: preparación completada.'
