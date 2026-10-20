#!/bin/sh
# linux-doctor opcional, sin permisos de root ni modificaciones del checkout existente.
set -eu
doctor_dir="$HOME/.local/share/linux-setup/linux-doctor"
case "$#" in
    0) dry_run=0 ;;
    1) [ "$1" = --dry-run ] || exit 2; dry_run=1 ;;
    *) exit 2 ;;
esac
echo 'Doctor: fuente https://github.com/agusc01/linux-doctor.git'
echo "Doctor: destino $doctor_dir"
if [ "$dry_run" -eq 1 ]; then
    echo 'Doctor: simulación, sin cambios ni reparaciones.'
    exit 0
fi
[ "$(id -u)" -ne 0 ] || { echo 'Doctor: ejecutar como usuario normal.' >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo 'Doctor: falta git.' >&2; exit 1; }
if [ -L "$doctor_dir" ]; then
    echo 'Doctor: no se modifican directorios enlazados.' >&2; exit 1
fi
if [ -e "$doctor_dir" ]; then
    [ -d "$doctor_dir/.git" ] && [ ! -L "$doctor_dir/.git" ] || {
        echo 'Doctor: destino ocupado por otros archivos.' >&2; exit 1
    }
    origin=$(git -C "$doctor_dir" remote get-url origin)
    [ "$origin" = 'https://github.com/agusc01/linux-doctor.git' ] || {
        echo 'Doctor: origen inesperado; se conserva sin cambios.' >&2; exit 1
    }
    echo 'Doctor: checkout existente, sin pull automático.'
else
    mkdir -p "$(dirname "$doctor_dir")"
    git clone --single-branch --branch main https://github.com/agusc01/linux-doctor.git "$doctor_dir"
fi
[ -f "$doctor_dir/install.sh" ] && [ -f "$doctor_dir/doctor.sh" ] || {
    echo 'Doctor: faltan archivos requeridos.' >&2; exit 1
}
launcher="$HOME/.local/bin/linux-doctor"
if [ -e "$launcher" ] || [ -L "$launcher" ]; then
    echo "Doctor: lanzador existente conservado: $launcher"
else
    sh "$doctor_dir/install.sh"
fi
echo 'Doctor: instalado; ejecutá linux-doctor desde una nueva sesión.'
echo 'Doctor: no ejecuta diagnósticos ni reparaciones automáticamente.'
