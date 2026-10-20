#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Dependencias compartidas: bootstrap general y compilador de dshortcuts.
# Esta biblioteca se carga con "."; no debe ejecutarse por separado.

dshortcuts_packages() {
    case "$1" in
        alpine)
            printf '%s\n' 'build-base patch libx11-dev libxft-dev libxinerama-dev libxext-dev fontconfig-dev freetype-dev'
            ;;
        debian|ubuntu)
            printf '%s\n' 'build-essential patch libx11-dev libxft-dev libxinerama-dev libxext-dev libfontconfig1-dev libfreetype-dev'
            ;;
        *)
            echo "Distribución no soportada para dshortcuts: $1" >&2
            return 1
            ;;
    esac
}

dshortcuts_package_installed() {
    case "$1" in
        alpine) /sbin/apk info -e "$2" >/dev/null 2>&1 ;;
        debian|ubuntu)
            dpkg-query -W -f='${Status}' "$2" 2>/dev/null | grep -Fxq 'install ok installed'
            ;;
        *) return 1 ;;
    esac
}

dshortcuts_missing_packages() (
    distro=$1
    required="git $(dshortcuts_packages "$distro")" || exit 1
    for package in $required; do
        if ! dshortcuts_package_installed "$distro" "$package"; then
            printf '%s\n' "$package"
        fi
    done
)

dshortcuts_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v su >/dev/null 2>&1; then
        # Solo se reciben rutas y paquetes de una lista fija, nunca entrada libre.
        su -c "$*"
    else
        echo 'Error: se necesita doas, sudo o su para instalar dependencias.' >&2
        return 1
    fi
}

dshortcuts_install_packages() {
    distro=$1
    shift
    case "$distro" in
        alpine) dshortcuts_as_root /sbin/apk add --no-cache "$@" ;;
        debian|ubuntu) dshortcuts_as_root /usr/bin/apt-get install -y "$@" ;;
        *) return 1 ;;
    esac
}

dshortcuts_ensure_dependencies() (
    distro=$1
    missing=$(dshortcuts_missing_packages "$distro") || exit 1
    if [ -z "$missing" ]; then
        echo 'Dependencias de dshortcuts: ya instaladas.'
        exit 0
    fi

    # Paquetes provienen exclusivamente de dshortcuts_packages; dividir por espacios es intencional.
    set -- $missing
    printf 'Instalando dependencias faltantes de dshortcuts: %s\n' "$*"
    dshortcuts_install_packages "$distro" "$@" || exit 1
    missing=$(dshortcuts_missing_packages "$distro") || exit 1
    if [ -n "$missing" ]; then
        printf 'Error: siguen faltando paquetes: %s\n' "$missing" >&2
        exit 1
    fi
    echo 'Dependencias de dshortcuts: OK.'
)
