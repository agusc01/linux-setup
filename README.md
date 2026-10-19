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

En modo interactivo ofrece `fish` (obligatorio), `rotate`, `audio`, `brightness`, `wifi`, `bluetooth` y `rofi`. Sin interfaz interactiva, indicá `--modules fish,rotate,audio,brightness --yes`. Se confirma antes de instalar; no escribe configuraciones ajenas ni instala `doas`.

Instala automáticamente Fish y Git mediante `apk` o `apt-get`, y las dependencias X11 (`xrandr`, `xinput`) solamente cuando se seleccionan rotación o brillo. Obtiene `linux-tools` desde GitHub y deja que ese proyecto instale y configure las funciones, audio, firmware y demás herramientas. Usa `doas`, `sudo` o `su` existentes solo para los paquetes. Nunca ejecuta todo el instalador como root.

## Audio Cherry Trail (Intel Atom x5-Z8350, NAU8824)

En el equipo probado, desde la **BIOS** configurá `Chipset → Audio Configuration → LPE Audio Support → LPE Audio ACPI mode`. Esta configuración **no** puede hacerse desde un script. Después, seleccioná `audio` en linux-setup.

El módulo de audio de linux-tools detecta los dispositivos ACPI `808622A8:00` e I²C `10508824:00`, comprueba `sof-cht.ri` y `sof-cht-nau8824.tplg` e instala `sof-firmware` desde el `community` temporal de tu versión de Alpine, con consentimiento, sin modificar los repositorios permanentes.

Si SOF acaba de instalarse, reiniciá, verificá `aplay -l` (debe aparecer `nau8824`), ajustá los controles con `alsamixer` y **guardá la mezcla comprobada** con `lt-audio-save save`; el servicio OpenRC ALSA la restaura al iniciar.

No se fuerza sonido en equipos con otro códec. Para los detalles, ver la guía de `linux-tools`.

## Estado del proyecto

**Primera entrega de bootstrap:** Fish, Git, rotación, brillo y audio; menú de texto. Todavía faltan el selector de módulos con `dialog`, instaladores de dwm/st/slock, dshortcuts, dbar, Ranger y otros componentes. No se borra ni archiva ningún repositorio anterior.

Ejecutá `sh tests/check.sh` para las pruebas básicas, sin instalar paquetes en el entorno de test.

## Wi-Fi y Bluetooth

Esta integración reutiliza el código de linux-tools: `sh install.sh --modules wifi,bluetooth --dry-run` permite inspeccionar los paquetes previstos, y `sh install.sh --modules wifi,bluetooth` instala las funciones Fish y solicita autorización para dependencias. **El módulo Wi-Fi respeta el gestor que ya está en funcionamiento.** Si detecta `wpa_supplicant` en Alpine (como en la notebook con `wlan0` y `udhcpc`), instala únicamente `iw` desde `main` y permite `lt-wifi status` y `lt-wifi list` sin habilitar NetworkManager. Si NetworkManager ya está activo, usa `nmcli`. En nuevas instalaciones sin wpa_supplicant en ejecución, puede preparar NetworkManager desde `community` temporal, pero **nunca interrumpe ni sustituye el gestor de red existente**. Para conectar mediante wpa_supplicant, el socket `ctrl_interface` debe estar preparado y accesible; el instalador no modifica credenciales ni reinicia la conexión.

En Alpine, Bluetooth prepara BlueZ y D-Bus de `main` con servicios OpenRC. La disponibilidad de un adaptador físico y los perfiles de audio Bluetooth se comprueban por separado. No configura doas.

## Comandos administrativos sin rutas completas

Fish es obligatorio y linux-tools agrega `/sbin`, `/usr/sbin` y `/usr/local/sbin` al final del PATH cuando existan. Esto permite `wpa_cli`, `modprobe`, `rc-service` y otras herramientas **sin** prefijar `/sbin/` a cada comando. No concede permisos elevados: `doas` o `su` siguen siendo necesarios para operaciones de root.

Si el cambio se instaló en una terminal que ya estaba abierta, recargar `source ~/.config/fish/conf.d/linux-tools.fish` o abrir otra sesión Fish.

## Recuperación del control Wi-Fi comprobado en Alpine

La notebook usa `wpa_supplicant` para `wlan0`, con DHCP mediante `udhcpc`. Después de instalar el módulo Wi-Fi y conectar una red, `lt-wifi status` y `lt-wifi list` funcionan sin configurar un socket. Para permitir **administración de redes guardadas** desde Fish, el archivo de configuración de `wpa_supplicant` debe contener estas directivas globales, **fuera de `network={...}`**:

```ini
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=wheel
```

No se debe almacenar un PSK real en GitHub ni imprimir el contenido del archivo en tickets o capturas: el PSK hexadecimal también permite autenticarse en la red. Antes de editar, guardar un respaldo root:root con permisos 0600. El grupo wheel debe incluir únicamente cuentas de confianza, porque estas directivas permiten controlar conexiones a sus miembros. El script **no** modifica ese archivo ni reinicia `wpa_supplicant`: hay que programar el reinicio del servicio manualmente cuando se pueda tolerar una interrupción de conectividad.

Comprobar la configuración tras reiniciar de forma controlada:

```sh
wpa_cli -i wlan0 ping            # PONG
lt-wifi doctor                  # Socket de control: OK
lt-wifi connections             # Lista de redes ya guardadas
```

No mostrar todo `/etc/wpa_supplicant/wpa_supplicant.conf`, porque puede contener credenciales. Para confirmar solamente directivas globales:

```sh
doas grep -E '^[[:space:]]*(ctrl_interface|ctrl_interface_group)=' /etc/wpa_supplicant/wpa_supplicant.conf
```

Esto reproduce lo que **sí se verificó** en el equipo sin guardar contraseñas en el repositorio.

## Rofi para dwm (módulo independiente)

```sh
sh install.sh --modules rofi --dry-run
sh install.sh --modules rofi
lt-rofi
lt-rofi apps
lt-rofi run
lt-rofi windows
lt-rofi wifi
lt-rofi bluetooth
```

`linux-setup` delega toda la lógica en `linux-tools`: menú Rofi con aplicaciones, comandos, ventanas y consultas de redes/dispositivos, sin cambiar conexiones. En Alpine usa el paquete `rofi-x11-wayland` desde `community` de la **misma rama estable temporalmente**, en Debian/Ubuntu usa `rofi`. El instalador no sobrescribe `config.h` de dwm ni cambia los atajos existentes.

El programa C `dshortcuts` se mantiene en su propio repositorio. Su configuración histórica referencia `~/.bash_scripts`; primero hay que adaptar esos atajos para que apunten a `linux-tools` antes de instalarlo en una nueva máquina.

## dshortcuts (fork C) con Fish y linux-tools

El fork `agusc01/dshortcuts` conserva su repositorio y su código original; por limitaciones de permisos del conector, esta integración no escribe sobre el fork. `linux-setup` obtiene una **revisión exacta fijada** (`2f29a3dffa606f8823d80a6a7ff381ff0a1b1ab6`), crea una copia temporal, sustituye el menú por la plantilla `profiles/dshortcuts/{config.h,items.h}`, aplica un parche acotado para impedir lectura fuera de los límites en el menú y compila como usuario normal.

```sh
sh install.sh --modules dshortcuts --dry-run
sh install.sh --modules dshortcuts
dshortcuts -v
dshortcuts
```

Seleccionar `dshortcuts` incluye automáticamente **fish, rotate, audio, brightness, wifi, bluetooth, rofi y shortcuts**. También instala el compilador, `make`, `patch` y cabeceras X11. El ejecutable se guarda en `~/.local/share/linux-setup/dshortcuts/dshortcuts` y se lanza con un script de usuario en `~/.local/bin/dshortcuts`. Un launcher existente ajeno **no se sobrescribe**, y no se llama `make install` como root. No se alteran `dwm/keys.h`, `st`, `slock` ni el `PATH` de root.

Menú nuevo disponible: aplicaciones, ejecutar, cambiar ventanas, volumen, brillo, rotación completa de pantalla y táctil, consultar redes Wi-Fi y dispositivos Bluetooth. Todas las acciones se despachan mediante `lt-shortcut`, con claves permitidas; no hay botones de apagado/reinicio sin confirmación ni referencias antiguas a `~/.bash_scripts`. Para que las opciones funcionen, `linux-tools` debe haber instalado los módulos indicados.

Si usás el fork dwm con el atajo `Super+P`, éste seguirá abriendo `dshortcuts` siempre que dwm encuentre `~/.local/bin` en su PATH. Si el dwm instalado es el original de suckless, ese atajo **no existe** hasta que se configure manualmente.

**Pendiente:** trasladar los menús especializados para navegadores, layouts, gaps y señales de dwm; no se anuncian como funcionales mientras sus scripts no estén adaptados.
