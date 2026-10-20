#!/bin/sh
# Bootstrap inicial: invocar como root desde la TTY, una sola vez.
# Solo pide nombre de usuario y la contraseña normal de una cuenta nueva.
set -eu
PATH="$PATH:/sbin:/usr/sbin"
export PATH
[ "$(id -u)" -eq 0 ] || { echo 'Error: ejecutá bootstrap.sh como root.' >&2; exit 1; }
[ -r /etc/os-release ] || { echo 'Error: falta /etc/os-release.' >&2; exit 1; }
. /etc/os-release
case "$ID" in alpine|debian|ubuntu) ;; *) echo "Distribución no soportada: $ID" >&2; exit 1 ;; esac
[ -t 0 ] || { echo 'Error: se necesita una terminal interactiva para crear o comprobar el usuario.' >&2; exit 1; }

printf 'Nombre del usuario normal: '
IFS= read -r username
# Nombres POSIX conservadores, sin argumentos inyectables ni rutas.
case "$username" in
    ''|root|*[!a-z0-9_-]*|-*|_* ) echo 'Usuario inválido: empezá con letra minúscula y usá a-z, 0-9, _ o -.' >&2; exit 2 ;;
esac
case "$username" in
    [a-z]*) ;;
    *) echo 'El nombre debe empezar con una letra minúscula.' >&2; exit 2 ;;
esac
[ "${#username}" -le 32 ] || { echo 'Usuario demasiado largo (máximo 32 caracteres).' >&2; exit 2; }
if id "$username" >/dev/null 2>&1; then
    # Una cuenta existente podría ser una cuenta del sistema, sin shell o con UID reservado.
    home=$(getent passwd "$username" | cut -d: -f6)
    shell=$(getent passwd "$username" | cut -d: -f7)
    uid=$(id -u "$username")
    if [ "$uid" -lt 1000 ] || [ "$home" != "/home/$username" ]; then
        echo 'La cuenta existe pero parece ser de sistema o tener un home diferente; no se modifica.' >&2
        exit 1
    fi
    case "$shell" in */sh|*/ash|*/bash|*/zsh|*/fish) ;; *) echo 'La cuenta existente no tiene una shell de inicio válida.' >&2; exit 1 ;; esac
    echo "Usuario existente validado: $username"
else
    if [ "$ID" = alpine ]; then
        adduser -h "/home/$username" -s /bin/ash "$username"
    else
        adduser "$username"
    fi
    id "$username" >/dev/null 2>&1 || { echo 'No se pudo crear la cuenta.' >&2; exit 1; }
    echo "Usuario creado: $username"
fi
if [ "$ID" = alpine ]; then
    apk update
    apk add doas git
    if ! id -nG "$username" | tr ' ' '\n' | grep -Fxq wheel; then
        adduser "$username" wheel
    fi
    # Archivo propio; no tocar reglas preexistentes ni seguir symlinks.
    conf=/etc/doas.d/linux-setup.conf
    mkdir -p /etc/doas.d
    if [ -L "$conf" ]; then
        echo 'Conflicto: la regla doas es un enlace simbólico; no se sobrescribe.' >&2; exit 1
    fi
    if [ -e "$conf" ]; then
        [ -f "$conf" ] && [ "$(cat "$conf")" = 'permit :wheel' ] || {
            echo 'Conflicto: configuración doas administrada modificada; no se sobrescribe.' >&2; exit 1
        }
    else
        ( umask 077; printf 'permit :wheel\n' > "$conf" )
    fi
    chmod 0400 "$conf"
    echo "doas configurado para wheel sin nopass ($conf)"
    test_command='doas id -u'
else
    apt-get update
    apt-get install -y sudo git
    if ! id -nG "$username" | tr ' ' '\n' | grep -Fxq sudo; then
        usermod -aG sudo "$username"
    fi
    echo 'sudo configurado mediante el grupo sudo existente.'
    test_command='sudo id -u'
fi

# Revalidar que la cuenta pertenece al grupo esperado antes de terminar.
if [ "$ID" = alpine ]; then group=wheel; else group=sudo; fi
id -nG "$username" | tr ' ' '\n' | grep -Fxq "$group" || {
    echo "Error: $username no pertenece a $group." >&2; exit 1
}
printf '\nVerificando privilegios de %s (se pedirá su contraseña)...\n' "$username"
if su - "$username" -c "$test_command" | grep -Fxq 0; then
    printf '[OK] El usuario %s puede usar %s para obtener privilegios administrativos.\n' "$username" "${test_command%% *}"
else
    echo 'El usuario pertenece al grupo correcto, pero la autenticación aún no se verificó.' >&2
    echo "Iniciá una sesión nueva como $username y comprobá: $test_command" >&2
    exit 1
fi
printf '\nPreparación inicial completada. Iniciá sesión como %s, cloná linux-setup y ejecutá sh install.sh.\n' "$username"
