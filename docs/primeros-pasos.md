# Preparación inicial: Alpine Linux y Debian

Esta guía cubre **lo que se realiza una sola vez como root**, antes de ejecutar el instalador `linux-setup` como usuario normal. Sustituí `USUARIO` por el nombre real de la cuenta y elegí **únicamente** la sección de tu distribución.

> **Seguridad:** en Alpine, la regla de `doas` para `wheel` concede privilegios administrativos; en Debian, los integrantes del grupo `sudo` pueden obtenerlos mediante `sudo` cuando la política del sistema lo permite. Usá autenticación con contraseña, evitá configurar `nopass` o `NOPASSWD` y no sobrescribas configuraciones existentes sin revisarlas. No ejecutes `linux-setup` completo como root.

## Alpine Linux

### 1. Repositorios APK

Como root, comprobá la rama estable instalada:

```sh
cat /etc/alpine-release
cat /etc/apk/repositories
```

Editá el archivo **solamente si es necesario**:

```sh
vi /etc/apk/repositories
```

Ejemplo de las líneas para la **misma rama de tu instalación** (reemplazá `vX.X` por la rama real, por ejemplo `v3.24`; **no** uses `v3.24.2`):

```text
https://dl-cdn.alpinelinux.org/alpine/vX.X/main
https://dl-cdn.alpinelinux.org/alpine/vX.X/community
```

`main` cubre el sistema base; `community` permite algunos paquetes opcionales. Podés dejar `community` comentado cuando no lo necesites: algunos módulos lo utilizan **temporalmente** y no cambian el listado permanente. No elimines repositorios personalizados ni mezcles ramas diferentes. Actualizá los índices:

```sh
apk update
```

### 2. Crear usuario y habilitar doas

Como **root**, para una instalación nueva, ejecutá:

```sh
apk add doas git
adduser -h /home/USUARIO -s /bin/ash USUARIO
adduser USUARIO wheel
```

`adduser` pedirá la contraseña de la cuenta. Si el usuario ya existe, **no** lo recrees: agregalo solamente a `wheel` si corresponde.

Configurá doas con contraseña. Si ya hay reglas en `/etc/doas.d/doas.conf`, revisalas y editá el archivo en lugar de sobrescribirlas:

```sh
mkdir -p /etc/doas.d
printf 'permit :wheel\n' > /etc/doas.d/doas.conf
chmod 0400 /etc/doas.d/doas.conf
```

Los comandos anteriores crean la configuración de una **instalación nueva**; la redirección `>` reemplaza el contenido si el archivo ya existe. Cerrá la sesión root, iniciá como `USUARIO` y comprobá:

```sh
doas id -u
doas apk update
```

`doas id -u` debe imprimir `0`.

## Debian (también aplicable a Ubuntu con ajustes mínimos)

### 1. Repositorios APT

Debian **no** usa `/etc/apk/repositories`. Los repositorios suelen configurarse en `/etc/apt/sources.list.d/debian.sources` (formato deb822 en instalaciones modernas) o en `/etc/apt/sources.list` (formato tradicional).

Como root:

```sh
cat /etc/os-release
ls /etc/apt/sources.list.d/
apt update
```

Para modificar las fuentes, editá **el archivo que realmente utiliza tu instalación**, por ejemplo:

```sh
vi /etc/apt/sources.list.d/debian.sources
```

Ejemplo orientativo para **Debian 13 (Trixie)**, formato deb822; no lo copies en versiones distintas:

```text
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

No dupliques entradas si ya están presentes, ni reemplaces los repositorios de Ubuntu por los de Debian.

### 2. Crear usuario y habilitar sudo

En Debian se utiliza **`sudo`** para administrar el sistema. No hace falta instalar ni configurar `doas`.

Como root, instalá `sudo` y Git si faltan:

```sh
apt update
apt install sudo git
```

En una instalación nueva, creá el usuario si todavía no existe y añadilo al grupo `sudo`:

```sh
adduser USUARIO
usermod -aG sudo USUARIO
```

Si el usuario ya existe, **no** vuelvas a crearlo: utilizá únicamente `usermod -aG sudo USUARIO` si todavía no pertenece al grupo. `-aG` conserva los demás grupos.

En Debian, las instalaciones habituales incluyen una regla para el grupo `sudo` en `/etc/sudoers`, pero verificá que esté habilitada mediante `visudo` si `sudo` no funciona. **No uses redirecciones sobre `/etc/sudoers`**: un error de sintaxis podría bloquear el acceso administrativo.

Cerrá la sesión root e iniciá una sesión nueva como `USUARIO` para aplicar los grupos. Comprobá:

```sh
groups
sudo id -u
sudo apt update
```

`sudo id -u` debe imprimir `0`. Si `sudo` no está configurado en esa instalación, regresá a root para revisarlo sin modificar permisos a ciegas.

## Instalación común, sin comandos manuales adicionales

Desde aquí, `linux-setup` utiliza `doas` en Alpine o `sudo` en Debian cuando necesita instalar paquetes, y su instalación se ejecuta como usuario normal.

Con la sesión abierta como **usuario normal**:

```sh
git clone https://github.com/agusc01/linux-setup.git
cd linux-setup
sh install.sh --dry-run
sh install.sh
```

El instalador detecta Alpine o Debian/Ubuntu y prepara sus dependencias:

| Función | Alpine | Debian/Ubuntu |
|---|---|---|
| `whereis` | `util-linux-misc` | `util-linux` |
| Fish | `fish` | `fish` |
| Git | `git` | `git` |
| Paquetes | `apk` | `apt-get` |

**No necesitás ejecutar `apk add util-linux-misc` ni `apt install util-linux` manualmente** después de instalar con `linux-setup`.

El instalador también deja `~/.config/fish/conf.d/linux-setup-path.fish` con:

```fish
fish_add_path /sbin /usr/sbin
```

Esto agrega rutas administrativas al `PATH` de **nuevas sesiones Fish**, sin dar privilegios root y sin afectar otras shells. Si el archivo ya existe y no pertenece al instalador, se conserva sin sobrescribirlo.

Para comprobarlo en una nueva sesión Fish:

```fish
whereis dwm
type -a rc-service
fish --version
```

`rc-service` es propio de OpenRC (Alpine); en Debian con systemd corresponde `systemctl`. La disponibilidad de comandos concretos depende de los módulos que selecciones.
