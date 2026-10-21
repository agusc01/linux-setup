#!/bin/sh
# Pruebas aisladas del auditor de atajos: no ejecuta acciones ni toca X11.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/sources/dwm" "$tmp/bin"
cat > "$tmp/sources/dwm/keys.h" <<'EOF'
static const Key keys[] = {
 { MODKEY, XK_p, spawn, SHCMD("dshortcuts") },
 { MODKEY, XK_o, spawn, SHCMD("st") },
 { MODKEY, XK_i, spawn, SHCMD("rofi_internet") },
 { MODKEY, XK_y, spawn, SHCMD("rofi_menu") },
 { MODKEY, XK_F9, spawn, SHCMD("s0 notify") },
 // { MODKEY, XK_x, spawn, SHCMD("disabled_command") },
};
EOF
cat > "$tmp/sources/dwm/launchers.h" <<'EOF'
static const char* menu[] = { "/usr/bin/fish", "-c", "rofi_menu", NULL };
EOF
cat > "$tmp/bin/fish" <<'EOF'
#!/bin/sh
exit 1
EOF
for name in dshortcuts st; do
    printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/$name"
done
chmod +x "$tmp/bin/"*
export LINUX_SETUP_SOURCE_DIR="$tmp/sources"
PATH="$tmp/bin:$PATH"
export PATH
auditor="$root/lib/dwm-shortcuts-check.sh"
if sh "$auditor" --quiet; then
    echo 'FALLO: auditor aceptó comandos ausentes.' >&2; exit 1
fi
sh "$auditor" --report > "$tmp/report" || :
grep -Fq '[OK' "$tmp/report"
grep -Fq '[FALTA] rofi_menu' "$tmp/report"
grep -Fq 'lt-rofi menu' "$tmp/report"
grep -Fq 'lt-volume down' "$tmp/report"
if grep -Fq disabled_command "$tmp/report"; then
    echo 'FALLO: auditor analizó un atajo comentado.' >&2; exit 1
fi
for name in rofi_internet rofi_menu s0; do
    printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/$name"
    chmod +x "$tmp/bin/$name"
done
sh "$auditor" --quiet
sh "$auditor" --report > "$tmp/report"
grep -Fq 'faltantes: 0' "$tmp/report"
# No seguir enlaces simbólicos como fuente de atajos.
mv "$tmp/sources/dwm/keys.h" "$tmp/actual-keys.h"
ln -s "$tmp/actual-keys.h" "$tmp/sources/dwm/keys.h"
if sh "$auditor" --report > "$tmp/report" 2>&1; then
    echo 'FALLO: aceptó keys.h simbólico.' >&2; exit 1
fi
printf '%s\n' '[OK] Atajos dwm: comandos detectados, recomendaciones y seguridad sin ejecutar acciones.'
