# linux-setup

Instalador de arranque para **Alpine Linux y Debian/Ubuntu**, con **Fish obligatorio** y módulos independientes de [linux-tools](https://github.com/agusc01/linux-tools).

## Fuentes persistentes de dwm, st, slock y dshortcuts

El instalador **conserva una copia editable** de los repositorios fuente que descarga y compila:

```text
~/.local/src/dwm/
~/.local/src/st/
~/.local/src/slock/
~/.local/src/dshortcuts/
```

Los ejecutables continúan en sus rutas actuales (`/usr/local/bin/dwm`, `/usr/local/bin/st`, `/usr/local/bin/slock` y el lanzador `~/.local/bin/dshortcuts`). **Nunca se borra ni reemplaza un directorio de fuentes persistente**; si ya existe, se utiliza una copia temporal para compilar y se conserva su `config.h`, `items.h` y cualquier otro cambio.

Las instalaciones anteriores a este cambio conservan los ejecutables pero no necesariamente sus fuentes. Para **recuperarlas sin recompilar ni alterar nada instalado**, desde el repositorio:

```sh
sh lib/suckless-setup.sh --modules dwm,st,slock --save-sources
sh lib/dshortcuts-setup.sh --save-sources
```

Si una carpeta de `dwm` o `st` ya existe pero no tiene `config.h`, `--save-sources` completa **únicamente ese archivo** copiando `config.def.h`. No sobrescribe un `config.h` existente ni recompila los ejecutables. Si falta también `config.def.h` o hay enlaces simbólicos inesperados, informa el problema sin reemplazar fuentes.

Solo utiliza Git para obtener los commits fijados y `patch` para aplicar las integraciones correspondientes. No necesita `doas`. Las copias recuperadas reproducen el código fijado y sus parches, no extraen `config.h` de un binario existente.

Luego podés editar, por ejemplo, `~/.local/src/dwm/config.h` y **recompilar expresamente** con:

```sh
sh lib/suckless-setup.sh --modules dwm --reinstall
```

El instalador compila una copia de la fuente editable y respalda el ejecutable anterior antes de reemplazarlo. No sobrescribe el árbol de código. Para `dshortcuts`, su instalación normal usa la copia persistente y conserva `config.h` e `items.h`. Los modos `--dry-run` y `--build-only` no modifican fuentes persistentes.

## Auditoría de atajos del fork dwm

El fork `agusc01/dwm` utiliza `keys.h` y `launchers.h` como fuente de verdad. Para revisar **sin ejecutar ningún atajo** qué comandos externos están disponibles en el entorno Fish actual:

```sh
sh lib/dwm-shortcuts-check.sh
sh install.sh --verify
```

El auditor lee los comandos `SHCMD("...")` y el lanzador Rofi declarado, comprueba las funciones Fish y ejecutables disponibles **sin invocarlos**, y propone equivalencias orientativas con `lt-rofi`, `lt-volume` y `lt-brightness`. No instala comandos faltantes ni modifica `keys.h`, `config.h`, `.xinitrc` o el ejecutable dwm. `--verify` muestra una advertencia específica `dwm-atajos` si encuentra comandos ausentes; el listado detallado se obtiene con el primer comando. Este chequeo es de **dependencias declaradas**, no garantiza que cada atajo funcione durante una sesión X11 ni que las acciones internas de dwm correspondan al binario instalado.

Los nombres de los comandos antiguos pueden continuar presentes en tu fork, por ejemplo `rofi_menu`, `rofi_launcher`, `s0`, `b1` o `fsignal`. Su reemplazo es una decisión explícita, no automática, para conservar el comportamiento de tu configuración personalizada.

## Verificación de fuentes editables

`sh install.sh --verify` comprueba los ejecutables y, de forma **independiente**, las fuentes de cada módulo `dwm`, `st`, `slock` o `dshortcuts` registrado en el inventario. Se revisan las carpetas de `~/.local/src/` (o `LINUX_SETUP_SOURCE_DIR`), el `Makefile`, el archivo `.c` principal, los `config.h` aplicables y `items.h` para dshortcuts.

- **OK:** archivos fuente esenciales y configuración editable presentes.
- **WARN:** faltan las fuentes de una instalación anterior, o falta `config.h` editable. Esto no implica que falle el ejecutable instalado. Para recuperar fuentes: `--save-sources`.
- **FAIL:** la carpeta existe, pero le faltan archivos esenciales o contiene enlaces simbólicos inesperados. No se siguen enlaces ni se modifica nada.

La verificación es **de solo lectura**: no ejecuta `make`, no recompila, no actualiza y no sobrescribe configuraciones. El resumen incluye ahora también los resultados individuales de fuentes; por eso el número total de controles puede ser mayor que el de módulos instalados.

## Actualizaciones seguras según el inventario

```sh
sh install.sh --check-updates
sh install.sh --update --dry-run
sh install.sh --update
sh install.sh --verify
```

El gestor lee los módulos de `~/.local/state/linux-setup/installed-modules`. También admite `--modules doctor` para actualizar solo ese módulo. Nunca instala módulos no seleccionados, cambia el sistema durante una consulta ni desinstala componentes.

- **linux-tools:** compara el commit del checkout local con `main` en GitHub. Si hay diferencias, exige que el checkout esté limpio, en `main`, con origen oficial y que el avance sea fast-forward. Respalda los archivos administrados antes de aplicar solo los módulos registrados con `--no-deps`. Si falla el instalador, restaura el checkout y los archivos existentes; por precaución, no borra archivos nuevos.
- **linux-doctor:** compara los archivos desplegados con los publicados y reutiliza el instalador con backup y rollback ya existente.
- **dwm, st, slock y dshortcuts:** sus forks usan commits fijados y parches comprobados. Se informa de que están fijados; **no** se sustituyen automáticamente por un HEAD arbitrario. Sus revisiones se actualizarán en una entrega posterior, tras compilar y probar cada cambio.
- **Sin inventario:** no se infieren módulos antiguos. Volvé a instalarlos a través del selector para registrarlos antes de actualizar.

Las actualizaciones de `linux-tools` son de archivos de usuario, sin nuevas dependencias ni cambios de servicios; si una versión nueva requiere otra dependencia, se prepara mediante la instalación normal. El backup es preventivo y no constituye una transacción perfecta de todo el sistema: si la actualización añadió archivos antes de fallar, se dejan para revisión manual en lugar de borrar archivos desconocidos.

## Verificar la instalación real

`sh tests/check.sh` prueba el **código del instalador**; `sh install.sh --verify` revisa **los módulos que efectivamente se instalaron** en la cuenta actual:

```sh
sh install.sh --verify
```

Al finalizar una instalación exitosa, `linux-setup` mantiene un inventario acumulativo en `~/.local/state/linux-setup/installed-modules` (o bajo `XDG_STATE_HOME` cuando está configurado). Se guarda **solo después de instalar**, no durante `--dry-run` ni si algún módulo falla. No se incluye un componente simplemente por estar disponible en el sistema.

La verificación de dwm, st y slock consulta tanto `PATH` como `/usr/local/bin`, donde el instalador compila los binarios, aunque Alpine no incluya esa ruta en la shell que ejecuta la comprobación. No ejecuta el escritorio ni exige cambiar el `PATH` para dar un resultado correcto.

La verificación es de **solo lectura** y muestra `OK`, `WARN` o `FAIL` por cada módulo del inventario: presencia de Fish y PATH, funciones de rotación, herramientas de audio, Wi-Fi, Bluetooth, brillo, Rofi, dshortcuts, dwm, st, slock y linux-doctor. La disponibilidad de herramientas no implica que el hardware esté operativo; las verificaciones funcionales de audio, Wi-Fi y Bluetooth corresponden a diagnósticos complementarios. Si está instalado `linux-doctor`, se agrega su resumen sin duplicar sus resultados como fallos del inventario.

Si una instalación anterior no tiene registro, se informa y se solicita reinstalar los módulos deseados para crearlo; **no se inventa un historial**. Al terminar la instalación se ejecuta una verificación automática, y sus errores se muestran como advertencia de revisión sin ocultar los módulos correctamente instalados.

## Diagnóstico opcional con linux-doctor

El repositorio independiente [linux-doctor](https://github.com/agusc01/linux-doctor) puede instalarse desde el selector (opción **doctor**) o con `sh install.sh --modules doctor`. No requiere Xorg, Fish en ejecución ni permisos root propios; la instalación general de `linux-setup` sigue preparando Fish como dependencia habitual.

```sh
sh install.sh --modules doctor --dry-run
sh install.sh --modules doctor
# Actualización explícita: no reinstala Fish ni otros módulos
sh install.sh --modules doctor --update --dry-run
sh install.sh --modules doctor --update
~/.local/bin/linux-doctor --verbose
~/.local/bin/linux-doctor --json
```

`linux-setup` clona `linux-doctor` en `~/.local/share/linux-setup/linux-doctor` y llama a su instalador de usuario. No ejecuta diagnósticos automáticamente ni repara nada: la opción `--repair` de linux-doctor 0.1 solo imprime sugerencias. Si ya hay un launcher `~/.local/bin/linux-doctor`, se conserva. Si el checkout existe, se valida su origen y no se hace `git pull` implícito. La opción `--update` descarga una revisión nueva a un directorio temporal, preserva la instalación y archivos adicionales, crea un backup antes de reemplazarla y restaura la anterior si falla la instalación. El checkout original no se modifica. Los módulos opcionales ausentes no se consideran errores.

## Primer arranque automatizado (Alpine y Debian)

**[Guía paso a paso](docs/primeros-pasos.md)**. Después de instalar el sistema, como root descargá y ejecutá el asistente:

```sh
wget -O bootstrap.sh https://raw.githubusercontent.com/agusc01/linux-setup/main/bootstrap.sh
sh bootstrap.sh
```

Te pide el nombre del usuario, valida o crea la cuenta y gestiona su contraseña durante la creación. En Alpine instala Git y `doas`, configura `wheel` y verifica `doas id -u`; en Debian instala Git y `sudo`, configura `sudo` y verifica `sudo id -u`. No es necesario introducir manualmente comandos de usuarios y permisos.

Después entrá como el usuario normal y ejecutá `git clone https://github.com/agusc01/linux-setup.git`, `cd linux-setup` y `sh install.sh`. Al elegir `dwm`, Alpine configura también `input`, `video` y `audio` para ese usuario (cuando existen). Cerrá e iniciá sesión nuevamente si se agregaron grupos.

## Recuperar `startx` después de instalar Alpine

Si aparece `xf86OpenConsole: Cannot open virtual console 1 (Permission denied)`, Xorg no tiene acceso a la sesión de consola. No ejecutes `doas startx` ni cambies permisos de `/dev/tty*`.

Primero reiniciá Alpine si acabás de instalar Xorg/eudev o de agregar grupos, porque la sesión anterior puede tener permisos antiguos. Si persiste, ejecutá desde `linux-setup` como usuario normal:

```sh
git pull --ff-only origin main
sh lib/xorg-setup.sh --dry-run
sh lib/xorg-setup.sh
```

En Alpine, el instalador prepara D-Bus y elogind, inicia y habilita sus servicios en OpenRC, y respeta un gestor `seatd` ya habilitado para no configurarlos en paralelo. Reiniciá y volvé a iniciar sesión en una TTY antes de probar `startx`. Esto también funciona si dwm ya estaba instalado; **no requiere recompilarlo**.

## Una única aprobación y menos solicitudes de contraseña

Con `sh install.sh`, el selector elige módulos y a continuación se muestra **una sola confirmación para la instalación completa**. Los instaladores internos reciben automáticamente esa aprobación, por lo que no vuelven a preguntar `s/N` por cada componente. Para instalaciones no interactivas, `--yes` sigue siendo explícito.

En Alpine, el archivo doas **administrado por linux-setup** utiliza `permit persist :wheel`: tras introducir la contraseña, las siguientes operaciones administrativas pueden reutilizar la autenticación durante un período limitado. **No es `nopass`** y la contraseña puede volver a solicitarse cuando caduque el período. El instalador respeta políticas ajenas y no almacena contraseñas. Para sesiones Debian/Ubuntu se respeta la caché normal de `sudo`.

En nuevas sesiones Fish se agregan `/sbin`, `/usr/sbin` y `/usr/local/sbin` al PATH, con verificación de `reboot` desde Fish. Como un script hijo no puede cambiar el entorno de la shell que lo llamó, **abrí una nueva sesión Fish** después de instalar; no hace falta escribir `/sbin/reboot` si la shell y `doas` resuelven la orden correctamente.

## Primer arranque

Con `bootstrap.sh` completado y una sesión de usuario normal, Git ya está disponible y podés clonar el repositorio.

Cloná este repositorio como usuario común:

```sh
git clone https://github.com/agusc01/linux-setup.git
cd linux-setup
sh install.sh --dry-run
sh install.sh
```

En modo interactivo muestra un checklist con `dialog`: Fish (obligatorio) más rotación, audio, brillo, Wi-Fi, Bluetooth, Rofi, dshortcuts, dwm, st y slock (siempre desmarcado por seguridad). Si `dialog` aún no existe, ofrece un selector de texto sin necesitar paquetes adicionales y, tras aprobar la instalación, agrega `dialog` para próximas ejecuciones. Sin interfaz interactiva, indicá `--modules fish,rotate,audio,brightness --yes`. Se confirma antes de instalar; no escribe configuraciones ajenas; `doas` se configura durante el bootstrap inicial.

Instala automáticamente Fish y Git mediante `apk` o `apt-get`, y las dependencias X11 (`xrandr`, `xinput`) solamente cuando se seleccionan rotación o brillo. Obtiene `linux-tools` desde GitHub y deja que ese proyecto instale y configure las funciones, audio, firmware y demás herramientas. Usa `doas`, `sudo` o `su` existentes solo para los paquetes. Nunca ejecuta todo el instalador como root.

## Audio Cherry Trail (Intel Atom x5-Z8350, NAU8824)

En el equipo probado, desde la **BIOS** configurá `Chipset → Audio Configuration → LPE Audio Support → LPE Audio ACPI mode`. Esta configuración **no** puede hacerse desde un script. Después, seleccioná `audio` en linux-setup.

El módulo de audio de linux-tools detecta los dispositivos ACPI `808622A8:00` e I²C `10508824:00`, comprueba `sof-cht.ri` y `sof-cht-nau8824.tplg` e instala `sof-firmware` desde el `community` temporal de tu versión de Alpine, con consentimiento, sin modificar los repositorios permanentes.

Si SOF acaba de instalarse, reiniciá, verificá `aplay -l` (debe aparecer `nau8824`), ajustá los controles con `alsamixer` y **guardá la mezcla comprobada** con `lt-audio-save save`; el servicio OpenRC ALSA la restaura al iniciar.

No se fuerza sonido en equipos con otro códec. Para los detalles, ver la guía de `linux-tools`.

## Estado del proyecto

**Primera entrega de bootstrap:** Fish, Git, rotación, brillo y audio; menú de texto. Todavía faltan dbar, Ranger y otros componentes. `dwm`, `st` y `slock` ya cuentan con módulos de instalación independientes, además de dshortcuts. No se borra ni archiva ningún repositorio anterior.

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

También podés ejecutar **`sh lib/dshortcuts-setup.sh` directamente**: detecta los paquetes faltantes (por ejemplo, `patch`) e instala únicamente esos paquetes mediante `doas`, `sudo` o `su`, tras pedirte confirmación. No hace falta ejecutar `apk add patch` ni `apt-get install patch` manualmente. Ambos instaladores comparten la misma lista de dependencias para Alpine y Debian/Ubuntu.

Los comandos `sh lib/dshortcuts-setup.sh --dry-run` y `sh lib/dshortcuts-setup.sh --verify` no instalan paquetes. La verificación exige que dshortcuts ya esté compilado. En cambio, `sh install.sh --modules dshortcuts` hace la instalación completa. **`--verify` no es una opción de ese instalador principal**; corresponde al script de dshortcuts y a linux-tools.

Seleccionar `dshortcuts` incluye automáticamente **fish, rotate, audio, brightness, wifi, bluetooth, rofi y shortcuts**. También instala el compilador, `make`, `patch` y cabeceras X11. El ejecutable se guarda en `~/.local/share/linux-setup/dshortcuts/dshortcuts` y se lanza con un script de usuario en `~/.local/bin/dshortcuts`. Un launcher existente ajeno **no se sobrescribe**, y no se llama `make install` como root. No se alteran `dwm/keys.h`, `st`, `slock` ni el `PATH` de root.

Menú nuevo disponible: aplicaciones, ejecutar, cambiar ventanas, volumen, brillo, rotación completa de pantalla y táctil, consultar redes Wi-Fi y dispositivos Bluetooth. Todas las acciones se despachan mediante `lt-shortcut`, con claves permitidas; no hay botones de apagado/reinicio sin confirmación ni referencias antiguas a `~/.bash_scripts`. Para que las opciones funcionen, `linux-tools` debe haber instalado los módulos indicados.

Si usás el fork dwm con el atajo `Super+P`, éste seguirá abriendo `dshortcuts` siempre que dwm encuentre `~/.local/bin` en su PATH. Si el dwm instalado es el original de suckless, ese atajo **no existe** hasta que se configure manualmente.

**Pendiente:** trasladar los menús especializados para navegadores, layouts, gaps y señales de dwm; no se anuncian como funcionales mientras sus scripts no estén adaptados.

## Reparación de dshortcuts SIGSEGV y selección de ventanas Rofi en dwm

Si los submenús **Equipo** o **Rotar pantalla y táctil** cierran dshortcuts con SIGSEGV, actualizá linux-setup y recompilá **como usuario normal**:

```sh
git pull --ff-only origin main
sh lib/dshortcuts-setup.sh --dry-run
sh lib/dshortcuts-setup.sh
sh lib/dshortcuts-setup.sh --verify
dshortcuts
```

El parche al fork C inicializa `master->next` al entrar por primera vez a un submenú y evita obtener cero columnas con textos largos. Las pruebas de CI ahora navegan por menús anidados bajo Xvfb para detectar bloqueos o señales fatales. El código fuente original en GitHub no se modifica.

Por defecto dwm interpreta una petición `_NET_ACTIVE_WINDOW` como urgencia (se destaca el tag en la barra), sin navegar al tag ni enfocar la ventana. Por eso `lt-rofi windows` puede listar ventanas de otros escritorios pero no cambiar a ellas. El arreglo pertenece al **gestor dwm**, no a Rofi.

Para el dwm compilado originalmente en `/usr/src/suckless/dwm`, **opt-in** (no se ejecuta al instalar dshortcuts):

```sh
sh lib/dwm-rofi-setup.sh --dry-run
sh lib/dwm-rofi-setup.sh
```

Si el código fuente está en otro directorio, utilizá `--source /ruta/al/dwm`. El instalador usa una copia temporal del código fuente existente, **preserva config.h/keys.h**, aplica un parche acotado a `clientmessage`, compila sin modificar el checkout y, tras un respaldo privado en `~/.local/state/linux-setup/backups/`, instala en `/usr/local/bin/dwm`. Solo toca el binario después de comprobar que compiló. Solicita autorización para las dependencias faltantes y para instalar el ejecutable; nunca ejecuta la compilación como root. No modifica `.xinitrc` ni reinicia la sesión X11.

Al terminar, cerrá dwm de manera normal e iniciá nuevamente `startx` para usar el ejecutable nuevo. Probá `lt-rofi windows` seleccionando una ventana en el tag actual y luego otra en un tag diferente: debe enfocar cada una sin moverlas permanentemente de tag.

El parche fue diseñado para el manejo estándar de `_NET_ACTIVE_WINDOW` usado tanto en dwm original como en el fork consultado. Si `patch` lo rechaza en una versión más modificada, el instalador aborta sin cambiar el binario anterior. No se sobrescriben modificaciones ajenas en el código fuente.

## Instalación reproducible de dwm, st y slock

Tres módulos **opcionales**, separados del resto de las herramientas. Se obtienen de los forks personales `agusc01/dwm`, `agusc01/st` y `agusc01/slock`, cada uno **fijado a una revisión Git exacta**. Fish sigue siendo obligatorio en `linux-setup`; no se modifica el repositorio del fork ni las fuentes ya existentes.

```sh
# Ver primero qué hará en Alpine/Debian.
sh install.sh --modules dwm,st --dry-run

# Instala Fish/linux-tools si hace falta y compila dwm + st.
sh install.sh --modules dwm,st

# slock requiere un opt-in explícito; no se incluye con dwm.
sh install.sh --modules slock --dry-run
sh install.sh --modules slock
```

Si ya tenés `/usr/local/bin/dwm`, `/usr/local/bin/st` o `/usr/local/bin/slock`, **NO** se sobrescriben al ejecutar la instalación habitual: se informan como «Sin cambios». Una reinstalación se solicita expresamente, con respaldo previo del ejecutable anterior:

```sh
# Preservar configuración personalizada del dwm que ya funciona.
sh lib/suckless-setup.sh --modules dwm --source /usr/src/suckless/dwm --reinstall --dry-run
sh lib/suckless-setup.sh --modules dwm --source /usr/src/suckless/dwm --reinstall

# Reinstalar st desde su código local, si corresponde.
sh lib/suckless-setup.sh --modules st --source /usr/src/suckless/st --reinstall --dry-run
```

Con `--source` solo se acepta **un módulo por ejecución**. Se copia el código local a un directorio temporal; no se cambian `config.h`, `keys.h` ni otros archivos de origen. Si no se indica `--source`, se compila la revisión fijada del fork GitHub (que podría tener configuraciones distintas de tus modificaciones locales). Para dwm, el instalador aplica en la copia el parche Rofi de navegación entre tags si todavía no está incluido. Si no puede aplicar ese parche, aborta sin reemplazar nada.

En Alpine v3.24 el fork de dwm requiere `imlib2-dev` de **community**. El instalador obtiene solo esa dependencia usando un repositorio temporal `--repository`, sin editar `/etc/apk/repositories`, y pide autorización antes de instalar. El resto de las dependencias se prepara automáticamente para cada módulo, sin pedir `apk add` manuales. `st` necesita `tic` del paquete `ncurses`; se instala también la entrada `st.info` en `~/.terminfo` del usuario. **Las instalaciones nuevas de dwm y st incluyen automáticamente las fuentes DejaVu** (Alpine: `font-dejavu`; Debian/Ubuntu: `fonts-dejavu-core`). En la copia temporal de los forks fijados se reemplazan únicamente las referencias a Ubuntu/Liberation Mono por DejaVu Sans Mono para evitar que `startx` termine con `cannot load font from name: 'Ubuntu:size=16'`. Las fuentes locales pasadas mediante `--source` no se modifican; si necesitan una fuente personalizada, el usuario debe aportarla. La integración **no** ejecuta `make install` como root.

Si ya instalaste dwm antes de esta corrección y se cierra al arrancar por falta de fuente, ejecutá `git pull --ff-only` en `linux-setup` y `sh lib/suckless-setup.sh --modules dwm --reinstall` para sustituir el binario conservando un respaldo. Las instalaciones nuevas no requieren esta reinstalación.\n\nCuando se instala dwm y **no existe** `~/.xinitrc`, se crea uno mínimo que lanza `/usr/local/bin/dwm` y expone `~/.local/bin` para los atajos. Si ya existe, se conserva íntegro, incluso si es un enlace simbólico. No inicia ni reinicia Xorg/dwm automáticamente. Para entrar en una instalación nueva con Xorg configurado, usá `startx`.

**Seguridad de slock:** es un bloqueador de pantalla; necesita un binario propiedad de root con permiso `4755` para autenticar la contraseña local. Por eso no se instala implícitamente al pedir dwm. Verifica `nobody:nogroup`, no se ejecuta de forma automática y debe probarse únicamente cuando el usuario sepa cómo desbloquear su cuenta. En ningún caso se modifica la contraseña.

Para compilar y verificar fuentes sin reemplazar ejecutables ni terminfo:

```sh
sh lib/suckless-setup.sh --modules dwm,st,slock --build-only --yes
```

La compilación normal usa un directorio temporal y solo instala binarios una vez que se han compilado correctamente. Las copias de seguridad quedan en `~/.local/state/linux-setup/backups/`. Después de actualizar dwm, salí de dwm normalmente y volvé a entrar mediante `startx`; no se fuerza un reinicio en caliente.

## Selector interactivo de módulos con dialog

Ejecutá como usuario normal desde el directorio de `linux-setup`:

```sh
# Abre el selector con casillas (o alternativa de texto si dialog todavía no está).
sh install.sh --menu

# También aparece automáticamente con "sh install.sh" en una terminal interactiva.
sh install.sh

# Seleccionar módulos y revisar el plan sin instalar nada.
sh install.sh --menu --dry-run

# Para automatizaciones no hace falta una UI:
sh install.sh --modules wifi,bluetooth --dry-run
sh install.sh --modules wifi,bluetooth --yes

# Forzar menú de texto aun si dialog está instalado:
sh install.sh --text-menu
```

Con `dialog`, usá **flechas** para navegar, **Espacio** para marcar/desmarcar y **Enter** para continuar. `Fish` nunca puede desmarcarse. Los módulos rotación, audio y brillo están preseleccionados; `slock` está desmarcado y requiere marcarlo explícitamente por sus permisos setuid-root. `dshortcuts` incorpora automáticamente los módulos necesarios para sus submenús, incluso si no estaban marcados individualmente.

Al continuar se imprime el **resumen de sistema, módulos, paquetes y fuentes** y se pide una segunda confirmación antes de modificar nada. **Cancelar** el selector sale sin tocar archivos, paquetes ni servicios. Si `dialog` no está instalado en una Alpine nueva, un selector numérico permite elegir en la primera ejecución; únicamente después de confirmar la instalación se instala `dialog` con el resto de paquetes. No se exige `apk add dialog` manual. También admite `--text-menu` para terminales limitadas.

Para scripts o recuperación desde SSH, `--modules` sigue funcionando sin abrir menús. No se puede combinar `--menu` con `--modules`. En ausencia de TTY, `sh install.sh --dry-run` o `sh install.sh --modules ... --yes` mantienen el comportamiento no interactivo y sin dependencias de `dialog`.

Validación:

```sh
sh tests/check.sh
sh tests/module-selector.sh
```
