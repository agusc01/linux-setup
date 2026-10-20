#!/bin/sh
# linux-setup-managed: agusc01/linux-setup
# Selector aislado: NUNCA instala paquetes ni modifica el sistema.
# Emite solo una lista CSV validada en stdout; la UI se dibuja en la TTY.
set -eu

usage() {
    echo 'Uso: sh lib/module-selector.sh [--auto|--dialog|--text]' >&2
}
mode=auto
while [ "$#" -gt 0 ]; do
    case "$1" in
        --auto) mode=auto ;;
        --dialog) mode=dialog ;;
        --text) mode=text ;;
        --help|-h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
    shift
done

selection=''
if [ "$mode" = dialog ] || { [ "$mode" = auto ] && command -v dialog >/dev/null 2>&1; }; then
    if ! command -v dialog >/dev/null 2>&1; then
        echo 'Error: dialog no está instalado; se usará el selector de texto con --text.' >&2
        exit 2
    fi
    # --stdout evita archivos temporales; --separate-output emite una opción por línea.
    # Fish es obligatorio y por ello NO puede desmarcarse.
    selection=$(dialog --stdout --separate-output --title 'linux-setup · Alpine / Debian' \
        --ok-label 'Continuar' --cancel-label 'Cancelar' \
        --checklist 'Fish se instala siempre. Espacio: marcar/desmarcar; Enter: continuar. slock requiere consentimiento explícito.' \
        0 0 0 \
        rotate 'Pantalla y táctil: rotación X11' on \
        audio 'Sonido y firmware (SOF cuando corresponde)' on \
        brightness 'Control de brillo' on \
        wifi 'Herramientas Wi-Fi (sin desconectar redes)' off \
        bluetooth 'Bluetooth y BlueZ' off \
        rofi 'Lanzador y selector de ventanas' off \
        dshortcuts 'Atajos visuales y submenús' off \
        dwm 'Gestor de ventanas X11 (fork fijado)' off \
        st 'Terminal suckless con terminfo' off \
        slock 'Bloqueo de pantalla setuid-root (4755)' off \
        doctor 'Diagnóstico del sistema (solo lectura)' off) || exit 130
else
    # Primer arranque sin dialog: alternativa POSIX sin instalar nada antes del consentimiento.
    # La instalación posterior añadirá dialog para futuras ejecuciones gráficas en terminal.
    printf '%s\n' \
        'linux-setup · selección de módulos' \
        'Fish se instalará obligatoriamente.' \
        ' 1) rotate       Rotación de pantalla y táctil' \
        ' 2) audio        Audio y SOF (cuando corresponda)' \
        ' 3) brightness   Control de brillo' \
        ' 4) wifi         Herramientas Wi-Fi' \
        ' 5) bluetooth    Bluetooth' \
        ' 6) rofi         Lanzador Rofi' \
        ' 7) dshortcuts   Menús de atajos' \
        ' 8) dwm          Gestor de ventanas' \
        ' 9) st           Terminal suckless' \
        '10) slock        Bloqueo de pantalla (setuid-root)' \
        '11) doctor       Diagnóstico del sistema'
        'Escribí números separados por comas, Enter para 1,2,3 o q para cancelar.' >&2
    printf 'Módulos [1,2,3]: ' >&2
    IFS= read -r numbers || exit 130
    case "$numbers" in
        '') numbers=1,2,3 ;;
        q|Q|salir|cancelar) exit 130 ;;
    esac
    # Validar TODOS los elementos antes de emitir el resultado.
    rest=$numbers
    while [ -n "$rest" ]; do
        case "$rest" in
            *,*) num=${rest%%,*}; rest=${rest#*,} ;;
            *) num=$rest; rest='' ;;
        esac
        case "$num" in
            1) selection="$selection rotate" ;;
            2) selection="$selection audio" ;;
            3) selection="$selection brightness" ;;
            4) selection="$selection wifi" ;;
            5) selection="$selection bluetooth" ;;
            6) selection="$selection rofi" ;;
            7) selection="$selection dshortcuts" ;;
            8) selection="$selection dwm" ;;
            9) selection="$selection st" ;;
            10) selection="$selection slock" ;;
            11) selection="$selection doctor" ;;
            *) echo "Número de módulo inválido: $num" >&2; exit 2 ;;
        esac
    done
fi

# Tanto la salida de dialog (separada por saltos de línea) como la entrada
# manual son datos no confiables: validarlos y normalizarlos a espacios.
# Sin esto, elegir más de un módulo podía omitir opciones intermedias.
normalized=''
for tag in $selection; do
    case "$tag" in
        rotate|audio|brightness|wifi|bluetooth|rofi|dshortcuts|dwm|st|slock|doctor) ;;
        *) echo "Selección no válida: $tag" >&2; exit 2 ;;
    esac
    case " $normalized " in
        *" $tag "*) : ;;
        *) normalized="$normalized $tag" ;;
    esac
done
selection=$normalized

# Orden canónico para que install.sh no dependa del orden devuelto por dialog.
modules=fish
for tag in rotate audio brightness wifi bluetooth rofi dshortcuts dwm st slock doctor; do
    case " $selection " in
        *" $tag "*) modules="$modules,$tag" ;;
    esac
done
printf '%s\n' "$modules"
