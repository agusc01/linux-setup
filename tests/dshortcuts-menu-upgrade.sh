#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Pruebas aisladas: upgrade de items.h no ejecuta git/make ni toca un binario.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/src/dshortcuts" "$tmp/state" "$tmp/home"
cat > "$tmp/bin/id" <<'EOF'
#!/bin/sh
if [ "$1" = -u ]; then printf '%s\n' 1000; exit 0; fi
exec /usr/bin/id "$@"
EOF
chmod 755 "$tmp/bin/id"
PATH="$tmp/bin:$PATH"
HOME="$tmp/home"
LINUX_SETUP_SOURCE_DIR="$tmp/src"
XDG_STATE_HOME="$tmp/state"
export PATH HOME LINUX_SETUP_SOURCE_DIR XDG_STATE_HOME
dest="$LINUX_SETUP_SOURCE_DIR/dshortcuts"
printf 'all:\n\t@true\n' > "$dest/Makefile"
printf '/* usuario */\n' > "$dest/config.h"
cp "$root/profiles/dshortcuts/items-v1.h" "$dest/items.h"
printf '%s\n' 'binario no tocar' > "$tmp/binary"
cp "$dest/config.h" "$tmp/config-backup"
sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu --dry-run > "$tmp/report"
cmp "$dest/items.h" "$root/profiles/dshortcuts/items-v1.h"
test ! -e "$XDG_STATE_HOME/linux-setup/backups"
sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu > "$tmp/report"
cmp "$dest/items.h" "$root/profiles/dshortcuts/items.h"
cmp "$dest/config.h" "$tmp/config-backup"
grep -Fqx 'binario no tocar' "$tmp/binary"
backup=$(find "$XDG_STATE_HOME/linux-setup/backups/dshortcuts" -name items.h -print -quit)
[ -n "$backup" ] && cmp "$backup" "$root/profiles/dshortcuts/items-v1.h"
# Dos ejecuciones seguidas deben ser idempotentes, sin crear más respaldos.
count=$(find "$XDG_STATE_HOME/linux-setup/backups/dshortcuts" -name items.h | wc -l)
sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu > "$tmp/report"
[ "$(find "$XDG_STATE_HOME/linux-setup/backups/dshortcuts" -name items.h | wc -l)" -eq "$count" ]
# Fuentes editadas NUNCA se reemplazan: incluso con --upgrade-menu.
printf '/* personal */\n' > "$dest/items.h"
if sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu > "$tmp/report" 2>&1; then
    echo 'FALLO: sobrescribió items.h personalizado.' >&2; exit 1
fi
grep -Fxq '/* personal */' "$dest/items.h"
# Fuentes enlazadas nunca se siguen.
rm "$dest/items.h"
ln -s "$root/profiles/dshortcuts/items-v1.h" "$dest/items.h"
if sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu > "$tmp/report" 2>&1; then
    echo 'FALLO: aceptó items.h enlazado.' >&2; exit 1
fi
test -L "$dest/items.h"
# No combinar migración con compilación ni carga de archivos externos.
if sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu --yes > "$tmp/report" 2>&1 ||
   sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu --save-sources > "$tmp/report" 2>&1 ||
   sh "$root/lib/dshortcuts-setup.sh" --upgrade-menu --source "$dest" > "$tmp/report" 2>&1; then
    echo 'FALLO: aceptó opciones incompatibles.' >&2; exit 1
fi
# Menús anidados C: 14 layouts, 17 gaps y 3 acciones de borde;
# cadenas literales únicamente, sin shell heredada.
items="$root/profiles/dshortcuts/items.h"
grep -Fq 'static item dwm_layouts[]' "$items"
grep -Fq 'static item dwm_gaps[]' "$items"
grep -Fq 'static item dwm_borders[]' "$items"
grep -Fq '"lt-shortcut layout"' "$items"
grep -Fq '"lt-shortcut gap"' "$items"
grep -Fq '"lt-shortcut border"' "$items"
if grep -Eq 'SCRIPT_ROFI|SCRIPT_DSHORTCUTS|~/.bash_scripts' "$items"; then
    echo 'FALLO: menú C depende de rutas Bash heredadas.' >&2; exit 1
fi
echo '[OK] dshortcuts: menú editable respaldado, idempotente y sin pisar personalizaciones.'
