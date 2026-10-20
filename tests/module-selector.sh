#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Pruebas headless: ninguna invoca apk, apt ni una interfaz gráfica real.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/mock"

cat > "$tmp/mock/dialog" <<'MOCK'
#!/bin/sh
# Verifica que se haya usado un checklist y sus etiquetas claras.
case " $* " in *" --checklist "*) ;; *) exit 42 ;; esac
[ "${MOCK_CANCEL:-0}" = 0 ] || exit 1
for item in ${MOCK_SELECTION:-rotate audio brightness}; do
    printf '%s\n' "$item"
done
MOCK
chmod +x "$tmp/mock/dialog"
PATH="$tmp/mock:$PATH"
export PATH
selector="$root/lib/module-selector.sh"
sh -n "$selector"

out=$(MOCK_SELECTION='wifi st bluetooth' sh "$selector" --dialog)
test "$out" = 'fish,wifi,bluetooth,st'
out=$(MOCK_SELECTION='' sh "$selector" --dialog)
test "$out" = 'fish,rotate,audio,brightness'
out=$(MOCK_SELECTION='slock' sh "$selector" --auto)
test "$out" = 'fish,slock'

if MOCK_SELECTION='wifi unknown' sh "$selector" --dialog > "$tmp/result" 2> "$tmp/error"; then
    echo 'FALLO: selector aceptó un módulo no permitido.' >&2; exit 1
fi
test ! -s "$tmp/result"
grep -Fq 'Selección no válida: unknown' "$tmp/error"

if MOCK_CANCEL=1 sh "$selector" --dialog > "$tmp/result" 2> "$tmp/error"; then
    echo 'FALLO: dialog cancelado se tomó como éxito.' >&2; exit 1
else
    code=$?
    test "$code" -eq 130
fi
test ! -s "$tmp/result"

out=$(printf '1,7,10\n' | sh "$selector" --text)
test "$out" = 'fish,rotate,dshortcuts,slock'
out=$(printf '\n' | sh "$selector" --text)
test "$out" = 'fish,rotate,audio,brightness'
if printf '1,11\n' | sh "$selector" --text > "$tmp/result" 2> "$tmp/error"; then
    echo 'FALLO: el selector numérico aceptó opción inválida.' >&2; exit 1
fi
test ! -s "$tmp/result"
if printf 'q\n' | sh "$selector" --text > "$tmp/result" 2> "$tmp/error"; then
    echo 'FALLO: cancelar el menú numérico se tomó como éxito.' >&2; exit 1
else
    code=$?
    test "$code" -eq 130
fi
test ! -s "$tmp/result"

printf 'ID=alpine\nVERSION_ID=3.24.2\n' > "$tmp/os-release"
MOCK_SELECTION='st wifi' LINUX_SETUP_OS_RELEASE="$tmp/os-release" \
    sh "$root/install.sh" --menu --dry-run > "$tmp/result"
grep -Fxq 'Módulos: fish,wifi' "$tmp/result"
grep -Fxq 'Suckless: st (módulos independientes; sin reemplazos automáticos).' "$tmp/result"
grep -Fq 'Simulación: no se instalaron paquetes' "$tmp/result"
MOCK_CANCEL=1 LINUX_SETUP_OS_RELEASE="$tmp/os-release" \
    sh "$root/install.sh" --menu --dry-run > "$tmp/result"
grep -Fxq 'Selección cancelada: no se modificó nada.' "$tmp/result"
! grep -Fq 'Paquetes base:' "$tmp/result"

if LINUX_SETUP_OS_RELEASE="$tmp/os-release" sh "$root/install.sh" \
    --menu --modules wifi --dry-run >/dev/null 2>&1; then
    echo 'FALLO: --menu y --modules combinados.' >&2; exit 1
fi
echo 'OK: dialog y selector de texto, entradas validadas, cancelación y dry-run sin instalaciones.'
