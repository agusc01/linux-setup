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

Esta integración reutiliza el código de linux-tools: `sh install.sh --modules wifi,bluetooth --dry-run` permite inspeccionar los paquetes previstos, y `sh install.sh --modules wifi,bluetooth` instala las funciones Fish y solicita autorización para dependencias. Para Wi-Fi instala NetworkManager desde `community` temporal en Alpine si es necesario. **No detiene ni reemplaza servicios de Wi-Fi existentes**, pues hacerlo puede interrumpir la conexión con la que se está instalando el sistema. Después hay que migrar el gestor de red de manera consciente.

En Alpine, Bluetooth prepara BlueZ y D-Bus de `main` con servicios OpenRC. La disponibilidad de un adaptador físico y los perfiles de audio Bluetooth se comprueban por separado. No configura doas.
