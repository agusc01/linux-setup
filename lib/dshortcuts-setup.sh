#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Compilar una copia FIEL y fijada del fork. No modifica el repositorio original.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/dshortcuts-deps.sh"
. "$root/lib/source-preserve.sh"
version=2f29a3dffa606f8823d80a6a7ff381ff0a1b1ab6
source_dir=''
dry_run=0
yes=0
verify=0
save_sources=0
upgrade_menu=0
for arg in "$@"; do
    : "$arg"
done
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --yes) yes=1 ;;
        --verify) verify=1 ;;
        --save-sources) save_sources=1 ;;
        --upgrade-menu) upgrade_menu=1 ;;
        --source)
            [ "$#" -ge 2 ] || { echo 'Error: --source requiere ruta.' >&2; exit 2; }
            source_dir=$2; shift ;;
        *) echo "Error: argumento desconocido $1" >&2; exit 2 ;;
    esac
    shift
done
# La actualización del menú es una operación explícita sin recompilación.
# Rechazar combinaciones para no escribir fuentes o ejecutables por sorpresa.
if [ "$upgrade_menu" -eq 1 ]; then
    [ "$verify" -eq 0 ] && [ "$save_sources" -eq 0 ] && [ -z "$source_dir" ] && [ "$yes" -eq 0 ] || {
        echo 'Error: --upgrade-menu solo se combina con --dry-run.' >&2; exit 2
    }
    if [ "$dry_run" -eq 1 ]; then
        sh "$root/lib/dshortcuts-menu-upgrade.sh" --dry-run
    else
        sh "$root/lib/dshortcuts-menu-upgrade.sh"
    fi
    exit $?
fi
prefix="$HOME/.local"
launcher="$prefix/bin/dshortcuts"
data="$prefix/share/linux-setup/dshortcuts"
binary="$data/dshortcuts"
marker="$data/managed"
header='# linux-setup-managed: agusc01/linux-setup'
managed_launcher() {
    [ -f "$launcher" ] && [ ! -L "$launcher" ] &&
        head -n 2 "$launcher" | grep -Fqx "$header"
}
managed_data() {
    [ -f "$marker" ] && [ ! -L "$marker" ] &&
        grep -Fqx "$header" "$marker"
}
[ "$save_sources" -eq 0 ] || [ -z "$source_dir" ] || {
    echo 'Error: --save-sources no admite --source.' >&2; exit 2
}
if [ "$verify" -eq 1 ]; then
    [ -x "$binary" ] && managed_launcher && managed_data || {
        echo 'Error: dshortcuts no está instalado o hay archivos ajenos.' >&2; exit 1
    }
    "$binary" -v
    exit 0
fi

echo 'dshortcuts: fork agusc01/dshortcuts (commit fijado para instalación reproducible).'
echo 'Menú C moderno: volumen, brillo, rotación, Wi-Fi, Bluetooth, Rofi y controles de dwm.'
echo "Launcher: $launcher | compilado: $binary"
echo 'No se cambian el fork, keys.h de dwm ni las configuraciones privadas.'
echo 'Fuentes persistentes: ~/.local/src/dshortcuts (sin sobrescribir cambios). '
if [ "$dry_run" -eq 1 ]; then
    if [ "$save_sources" -eq 1 ]; then
        echo 'Simulación: conservar fuentes de dshortcuts sin recompilar ni modificar ejecutables.'
        exit 0
    fi
    . /etc/os-release
    printf 'Paquetes gestionados automáticamente (%s): git %s\n' "$ID" "$(dshortcuts_packages "$ID")"
    echo 'Simulación: compilaría con overlays locales y verificaría dshortcuts -v.'
    exit 0
fi
[ "$(id -u)" -ne 0 ] || { echo 'Error: ejecutá como usuario normal.' >&2; exit 1; }
if [ "$save_sources" -eq 1 ]; then
    saved=$(linux_setup_source_existing dshortcuts) || exit 1
    if [ -n "$saved" ]; then
        echo "Fuentes conservadas: $saved (sin cambios)"
        exit 0
    fi
    command -v git >/dev/null 2>&1 && command -v patch >/dev/null 2>&1 || {
        echo 'Error: faltan git o patch para preparar fuentes.' >&2; exit 1
    }
    temp=$(mktemp -d)
    trap 'rm -rf "$temp"' EXIT HUP INT TERM
    work="$temp/dshortcuts"
    mkdir "$work"
    git -C "$work" init -q
    git -C "$work" remote add origin https://github.com/agusc01/dshortcuts.git
    git -C "$work" fetch -q --depth 1 origin "$version"
    git -C "$work" checkout -q --detach FETCH_HEAD
    [ "$(git -C "$work" rev-parse HEAD)" = "$version" ] || {
        echo 'Error: revisión inesperada de dshortcuts.' >&2; exit 1
    }
    cp "$root/profiles/dshortcuts/config.h" "$work/config.h"
    cp "$root/profiles/dshortcuts/items.h" "$work/items.h"
    patch -s -d "$work" -p1 < "$root/profiles/dshortcuts/safe.patch" || exit 1
    linux_setup_source_save dshortcuts "$work"
    echo 'Fuentes guardadas sin modificar el ejecutable existente.'
    exit 0
fi
if [ -e "$launcher" ] || [ -L "$launcher" ]; then
    managed_launcher || {
        echo "Conflicto: $launcher no fue creado por linux-setup. No se sobrescribe." >&2
        exit 1
    }
fi
if [ -e "$data" ] || [ -L "$data" ]; then
    [ -d "$data" ] && [ ! -L "$data" ] && managed_data || {
        echo "Conflicto: $data ya existe y no fue creado por linux-setup." >&2
        exit 1
    }
    [ ! -L "$binary" ] && { [ ! -e "$binary" ] || [ -f "$binary" ]; } || {
        echo "Conflicto: ejecutable inesperado en $binary." >&2; exit 1
    }
fi
if [ "$yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Error: usá --yes o confirmá interactivamente.' >&2; exit 2; }
    printf '¿Compilar e instalar dshortcuts para este usuario? [s/N]: '
    IFS= read -r ans || ans=''
    case "$ans" in s|S|si|Si|SI) : ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi

# El script también se puede ejecutar directamente: resolver dependencias antes de compilar.
[ -r /etc/os-release ] || { echo 'Error: no se encontró /etc/os-release.' >&2; exit 1; }
. /etc/os-release
dshortcuts_ensure_dependencies "$ID"
for cmd in git make cc patch; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: $cmd sigue sin estar disponible tras instalar las dependencias." >&2
        exit 1
    }
done

temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM
work="$temp/dshortcuts"
mkdir "$work"
saved=''
if [ -z "$source_dir" ]; then
    saved=$(linux_setup_source_existing dshortcuts) || exit 1
fi
if [ -n "$source_dir" ]; then
    [ -f "$source_dir/Makefile" ] && [ -f "$source_dir/dshortcuts.c" ] || {
        echo 'Error: --source no contiene el fork dshortcuts.' >&2; exit 1
    }
    cp -R "$source_dir/." "$work/"
elif [ -n "$saved" ]; then
    echo "Usando copia persistente sin modificar: $saved"
    cp -R "$saved/." "$work/"
else
    git -C "$work" init -q
    git -C "$work" remote add origin https://github.com/agusc01/dshortcuts.git
    git -C "$work" fetch -q --depth 1 origin "$version"
    git -C "$work" checkout -q --detach FETCH_HEAD
    [ "$(git -C "$work" rev-parse HEAD)" = "$version" ] || {
        echo 'Error: el commit descargado no coincide con la versión fijada.' >&2; exit 1
    }
fi
# No pisar las plantillas editadas ni volver a aplicar el parche.
if [ -z "$saved" ]; then
    cp "$root/profiles/dshortcuts/config.h" "$work/config.h"
    cp "$root/profiles/dshortcuts/items.h" "$work/items.h"
    patch -s -d "$work" -p1 < "$root/profiles/dshortcuts/safe.patch" || {
        echo 'Error: el código original cambió o el parche de seguridad no se pudo aplicar.' >&2; exit 1
    }
fi
make -C "$work" dshortcuts
"$work/dshortcuts" -v
linux_setup_source_save dshortcuts "$work"

mkdir -p "$prefix/bin" "$data"
if [ ! -e "$marker" ]; then printf '%s\n' "$header" > "$marker"; fi
temp_binary=$(mktemp "$data/.dshortcuts.XXXXXXXX")
cp "$work/dshortcuts" "$temp_binary"
chmod 755 "$temp_binary"
mv -f "$temp_binary" "$binary"
temp_launcher=$(mktemp "$prefix/bin/.linux-setup-dshortcuts.XXXXXXXX")
cat > "$temp_launcher" <<'EOF'
#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Launcher del ejecutable C, sin depender de rutas Bash ni root.
exec "$HOME/.local/share/linux-setup/dshortcuts/dshortcuts" "$@"
EOF
chmod 755 "$temp_launcher"
mv -f "$temp_launcher" "$launcher"
"$launcher" -v
echo 'OK: dshortcuts listo. Se puede abrir con "dshortcuts" dentro de dwm.'
