# linux-setup

Instalador de arranque para **Alpine Linux y Debian/Ubuntu**, con **Fish obligatorio** y módulos independientes de [linux-tools](https://github.com/agusc01/linux-tools).

## Primer arranque

Desde una Alpine **recién instalada**, necesitás `git` para poder clonar el instalador. Si todavía no existe, ejecutá como root `su -`, luego `apk add git` y finalmente `exit`. El instalador instalará Fish y el resto, sin necesidad de root permanente.

Cloná este repositorio como usuario común:

```sh
git clone https://github.com/agusc01/linux-setup.git
cd linux-setup
sh install.sh --dry-run
sh install.sh
```

En modo interactivo ofrece `fish` (obligatorio), `rotate`, `audio`, `brightness`, `wifi` y `bluetooth`. Sin interfaz interactiva, indicá `--modules fish,rotate,audio,brightness --yes`. Se confirma antes de instalar; no escribe configuraciones ajenas ni instala `doas`.

Instala automáticamente Fish y Git mediante `apk` o `apt-get`, y las dependencias X11 (`xrandr`, `xinput`) solamente cuando se seleccionan rotación o brillo. Obtiene `linux-tools` desde GitHub y deja que ese proyecto instale y configure las funciones, audio, firmware y demás herramientas. Usa `doas`, `sudo` o `su` existentes solo para los paquetes. Nunca ejecuta todo el instalador como root.

## Audio Cherry Trail (Intel Atom x5-Z8350, NAU8824)

En el equipo probado, desde la **BIOS** configurá `Chipset → Audio Configuration → LPE Audio Support → LPE Audio ACPI mode`. Esta configuración **no** puede hacerse desde un script. Después, seleccioná `audio` en linux-setup.

El módulo de audio de linux-tools detecta los dispositivos ACPI `808622A8:00` e I²C `10508824:00`, comprueba `sof-cht.ri` y `sof-cht-nau8824.tplg` e instala `sof-firmware` desde el `community` temporal de tu versión de Alpine, con consentimiento, sin modificar los repositorios permanentes.

Si SOF acaba de instalarse, reiniciá, verificá `aplay -l` (debe aparecer `nau8824`), ajustá los controles con `alsamixer` y **guardá la mezcla comprobada** con `lt-audio-save save`; el servicio OpenRC ALSA la restaura al iniciar.

No se fuerza sonido en equipos con otro códec. Para los detalles, ver la guía de `linux-tools`.

## Estado del proyecto

**Primera entrega de bootstrap:** Fish, Git, rotación, brillo y audio; menú de texto. Todavía faltan el selector de módulos con `dialog`, instaladores de dwm/st/slock, dshortcuts, Rofi, dbar, Ranger y otros componentes. No se borra ni archiva ningún repositorio anterior.

Ejecutá `sh tests/check.sh` para las pruebas básicas, sin instalar paquetes en el entorno de test.

## Wi-Fi y Bluetooth

Esta integración reutiliza el código de linux-tools: `sh install.sh --modules wifi,bluetooth --dry-run` permite inspeccionar los paquetes previstos, y `sh install.sh --modules wifi,bluetooth` instala las funciones Fish y solicita autorización para dependencias. **El módulo Wi-Fi respeta el gestor que ya está en funcionamiento.** Si detecta `wpa_supplicant` en Alpine (como en la notebook con `wlan0` y `udhcpc`), instala únicamente `iw` desde `main` y permite `lt-wifi status` y `lt-wifi list` sin habilitar NetworkManager. Si NetworkManager ya está activo, usa `nmcli`. En nuevas instalaciones sin wpa_supplicant en ejecución, puede preparar NetworkManager desde `community` temporal, pero **nunca interrumpe ni sustituye el gestor de red existente**. Para conectar mediante wpa_supplicant, el socket `ctrl_interface` debe estar preparado y accesible; el instalador no modifica credenciales ni reinicia la conexión.

En Alpine, Bluetooth prepara BlueZ y D-Bus de `main` con servicios OpenRC. La disponibilidad de un adaptador físico y los perfiles de audio Bluetooth se comprueban por separado. No configura doas.

## Comandos administrativos sin rutas completas

Fish es obligatorio y linux-tools agrega `/sbin`, `/usr/sbin` y `/usr/local/sbin` al final del PATH cuando existan. Esto permite `wpa_cli`, `modprobe`, `rc-service` y otras herramientas **sin** prefijar `/sbin/` a cada comando. No concede permisos elevados: `doas` o `su` siguen siendo necesarios para operaciones de root.

Si el cambio se instaló en una terminal que ya estaba abierta, recargar `source ~/.config/fish/conf.d/linux-tools.fish` o abrir otra sesión Fish.
