# Preparación inicial automatizada (Alpine / Debian / Ubuntu)

El objetivo es que, tras instalar el sistema operativo, **no tengas que escribir comandos `apk add doas git`, `adduser`, `usermod`, crear reglas de `doas` ni asignar grupos de Xorg manualmente**.

## Primer arranque: usuario root

Después de ejecutar `setup-alpine` (en Alpine) e iniciar sesión como root, necesitás descargar el bootstrap desde este repositorio. Alpine Standard incluye normalmente el cliente `wget` de BusyBox. Descargá el archivo para poder inspeccionarlo y ejecutarlo, **no lo canalices directamente a `sh`**:

```sh
wget -O bootstrap.sh https://raw.githubusercontent.com/agusc01/linux-setup/main/bootstrap.sh
sh bootstrap.sh
```

En Debian/Ubuntu, iniciá como root (`su -`) y utilizá el mismo script. Si `wget` no está disponible, descargá el archivo con el cliente HTTP ya instalado; el programa de preparación no requiere Git de antemano.

El asistente solicita **solo el nombre del usuario** y, cuando crea una cuenta nueva, el sistema operativo pide su contraseña. Si la cuenta existe, comprueba su UID, home y shell para no confundirla con una cuenta de servicio. Solo admite nombres de usuario sencillos en minúsculas, con números, guiones y guion bajo.

| Tarea | Alpine | Debian/Ubuntu |
|---|---|---|
| Paquetes previos | `apk update; apk add doas git` | `apt-get update; apt-get install -y sudo git` |
| Cuenta nueva | `adduser` | `adduser` |
| Grupo administrativo | `wheel` | `sudo` |
| Política | `/etc/doas.d/linux-setup.conf`, autenticación requerida | Política `sudoers` propia del sistema |

El bootstrap no sustituye archivos ajenos de `doas` ni habilita `nopass`. Configura `permit persist :wheel` para que la autenticación con contraseña pueda reutilizarse temporalmente mientras se instalan paquetes; si caduca, se solicitará nuevamente. Comprueba que el usuario pertenezca al grupo y ejecuta una verificación real como ese usuario (`doas id -u` o `sudo id -u`). Deberá imprimir `0`, y se solicita su contraseña cuando corresponda. Si no puede confirmar la autenticación, **no declara el proceso completado** y muestra cómo repetir la comprobación. El bootstrap requiere TTY interactiva y ejecutarse como root.

> La pertenencia a `wheel` o `sudo` concede permisos administrativos. No lo ejecutes para cuentas de usuarios que no deban administrarlo.

## Continuar como usuario normal

Cerrá la sesión root, entrá con la cuenta creada y ejecutá:

```sh
git clone https://github.com/agusc01/linux-setup.git
cd linux-setup
sh tests/check.sh
sh install.sh
```

Si elegís `dwm`, el instalador ejecuta automáticamente la preparación de Xorg. **En Alpine, además asigna los grupos `input`, `video` y `audio` al usuario que está ejecutando el instalador**, si existen y aún no pertenecía a ellos. Las asignaciones se hacen con privilegios por `doas`; no se añaden a root ni se modifican otros usuarios. Cerrá sesión y volvé a entrar para que los nuevos grupos se apliquen.

En Debian/Ubuntu no añade esos grupos indiscriminadamente: normalmente los dispositivos se gestionan con permisos de sesión a través de logind.

## Repositorios

Después de instalar Fish, `linux-setup` configura su PATH con `/sbin`, `/usr/sbin` y `/usr/local/sbin` y ejecuta una comprobación en una nueva sesión Fish. Si ya tenías Fish abierto, iniciá una sesión nueva para que se cargue el archivo `conf.d`.\n\nEl archivo de Alpine es `/etc/apk/repositories`. La rama debe coincidir con `/etc/alpine-release` (por ejemplo `v3.24` para `3.24.2`). La instalación de Xorg puede habilitar `community`; se anuncia en la simulación. Debian/Ubuntu utilizan repositorios APT, típicamente bajo `/etc/apt/sources.list.d/`. El script no reemplaza listas de repositorios existentes.

## Seguridad y alcance

La primera descarga del bootstrap debe proceder del repositorio oficial y conviene revisar su contenido antes de ejecutarlo como root. Los cambios administrativos se aplican solo después de ejecutar expresamente `sh bootstrap.sh`. La instalación principal se ejecuta **como usuario normal**, sin root permanente. Una cuenta existente con un home diferente, UID de servicio o shell inválida se rechaza en lugar de modificarla.
