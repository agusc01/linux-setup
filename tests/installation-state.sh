#!/bin/sh
# Tests del inventario: HOME aislado y sin privilegios ni instalaciones.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/home"
cat > "$tmp/bin/id" <<'MOCK'
#!/bin/sh
if [ "$1" = -u ]; then echo 1000; exit 0; fi
exec /usr/bin/id "$@"
MOCK
chmod 755 "$tmp/bin/id"
HOME="$tmp/home"
XDG_STATE_HOME="$tmp/home/state"
PATH="$tmp/bin:$PATH"
export HOME XDG_STATE_HOME PATH
state="$XDG_STATE_HOME/linux-setup/installed-modules"
script="$root/lib/installation-state.sh"
if sh "$script" --verify > "$tmp/result" 2>&1; then
    echo 'FALLO: verificación sin registro debería informar que falta.' >&2; exit 1
else
    code=$?
    test "$code" -eq 2
fi
grep -Fq 'Sin registro de módulos' "$tmp/result"
sh "$script" --record fish,doctor > "$tmp/result"
test -f "$state"
grep -Fxq fish "$state"
grep -Fxq doctor "$state"
test "$(grep -Fc fish "$state")" -eq 1
sh "$script" --record doctor,rotate > "$tmp/result"
grep -Fxq rotate "$state"
test "$(grep -Fc doctor "$state")" -eq 1
if sh "$script" --record fish,desconocido > "$tmp/result" 2>&1; then
    echo 'FALLO: se registró módulo desconocido.' >&2; exit 1
fi
! grep -Fq desconocido "$state"
if sh "$script" --verify > "$tmp/result" 2>&1; then
    echo 'FALLO: no detectó los módulos faltantes.' >&2; exit 1
fi
grep -Fq '[FAIL] doctor' "$tmp/result"
grep -Fq '[FAIL] rotate' "$tmp/result"
grep -Fq 'Resumen:' "$tmp/result"
# Sólo lectura: verificar no altera el inventario.
cp "$state" "$tmp/before"
sh "$script" --verify > /dev/null 2>&1 || :
cmp "$state" "$tmp/before"
# dwm y st deben verificarse incluso si están fuera de PATH (Alpine/ash).
suckless="$tmp/usr-local-bin"
mkdir -p "$suckless" "$tmp/suckless-state/linux-setup"
LINUX_SETUP_SUCKLESS_BIN_DIR="$suckless"
XDG_STATE_HOME="$tmp/suckless-state"
export LINUX_SETUP_SUCKLESS_BIN_DIR XDG_STATE_HOME
printf '%s\n' '# linux-setup modules v1' 'dwm' 'st' > "$XDG_STATE_HOME/linux-setup/installed-modules"
printf '#!/bin/sh\nexit 0\n' > "$suckless/dwm"
printf '#!/bin/sh\nexit 0\n' > "$suckless/st"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/startx"
printf '#!/bin/sh\nexec /usr/local/bin/dwm\n' > "$HOME/.xinitrc"
chmod 755 "$suckless/dwm" "$suckless/st" "$tmp/bin/startx"
sh "$script" --verify > "$tmp/result"
grep -Eq '\[OK[[:space:]]*\] dwm' "$tmp/result"
grep -Eq '\[OK[[:space:]]*\] st' "$tmp/result"
rm "$suckless/st"
if sh "$script" --verify > "$tmp/result" 2>&1; then
    echo 'FALLO: no detectó st faltante.' >&2; exit 1
fi
grep -Eq '\[FAIL\] st' "$tmp/result"
# Fuentes de los cuatro forks: AUSENTE=WARN, presente íntegra=OK,
# incompleta o enlazada=FAIL. Nunca escribir sobre fuentes verificadas.
source_root="$tmp/persistent-sources"
LINUX_SETUP_SOURCE_DIR="$source_root"
export LINUX_SETUP_SOURCE_DIR
mkdir -p "$source_root"
printf '%s\n' '# linux-setup modules v1' 'dwm' 'st' 'slock' 'dshortcuts' > "$XDG_STATE_HOME/linux-setup/installed-modules"
sh "$script" --verify > "$tmp/result" 2>&1 || :
grep -Fq 'Fuente no recuperada:' "$tmp/result"
for name in dwm st slock dshortcuts; do
    mkdir -p "$source_root/$name"
    printf 'all:\n\t@true\n' > "$source_root/$name/Makefile"
    case "$name" in
        dwm) main=dwm.c ;;
        st) main=st.c ;;
        slock) main=slock.c ;;
        dshortcuts) main=dshortcuts.c ;;
    esac
    printf '/* fuente */\n' > "$source_root/$name/$main"
    if [ "$name" != slock ]; then
        printf '/* configurable */\n' > "$source_root/$name/config.h"
    fi
    if [ "$name" = dshortcuts ]; then
        printf '/* menu */\n' > "$source_root/$name/items.h"
    fi
done
cp "$source_root/dwm/config.h" "$tmp/unedited-before"
sh "$script" --verify > "$tmp/result" 2>&1 || :
grep -Fq '[OK' "$tmp/result"
grep -Fq 'dwm-fuente' "$tmp/result"
grep -Fq 'st-fuente' "$tmp/result"
grep -Fq 'slock-fuente' "$tmp/result"
grep -Fq 'dshortcuts-fuente' "$tmp/result"
grep -Fq 'Código y configuración disponibles:' "$tmp/result"
cmp "$source_root/dwm/config.h" "$tmp/unedited-before"
rm "$source_root/st/config.h"
sh "$script" --verify > "$tmp/result" 2>&1 || :
grep -Fq 'Falta config.h editable:' "$tmp/result"
rm "$source_root/dshortcuts/items.h"
sh "$script" --verify > "$tmp/result" 2>&1 || :
grep -Fq 'Falta items.h regular' "$tmp/result"
rm -rf "$source_root/dwm"
ln -s "$source_root/st" "$source_root/dwm"
sh "$script" --verify > "$tmp/result" 2>&1 || :
grep -Fq 'Ruta enlazada:' "$tmp/result"
printf '%s\n' '[OK] Inventario: registro acumulativo, validación, ausencia y solo lectura.'
