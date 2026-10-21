/* linux-setup-managed: agusc01/linux-setup */
/* Cada acción se delega en lt-shortcut; no utiliza utilidades heredadas. */
static item sound[] = {
    { "j", "Bajar volumen 10%" },
    { "k", "Subir volumen 10%" },
    { "m", "Alternar silencio" },
    { "u", "Activar sonido" },
    { "0", "Volumen 0%" },
    { "2", "Volumen 20%" },
    { "5", "Volumen 50%" },
    { "8", "Volumen 80%" },
    { "o", "Volumen 100%" }
};

static item brightness[] = {
    { "j", "Bajar brillo 10%" },
    { "k", "Subir brillo 10%" },
    { "1", "Brillo 10%" },
    { "3", "Brillo 30%" },
    { "5", "Brillo 50%" },
    { "7", "Brillo 70%" },
    { "o", "Brillo 100%" }
};

static item rotation[] = {
    { "n", "Normal" },
    { "r", "Derecha 90 grados" },
    { "i", "Invertida 180 grados" },
    { "l", "Izquierda 270 grados" }
};

static item wifi[] = {
    { "l", "Ver redes disponibles" },
    { "c", "Ver redes guardadas" }
};

static item bluetooth[] = {
    { "d", "Ver dispositivos" },
    { "s", "Escanear durante 8 segundos" }
};

static item machine[] = {
    { "v", "Volumen", "lt-shortcut volume", 1, sound, LENGTH(sound), 1 },
    { "b", "Brillo", "lt-shortcut brightness", 1, brightness, LENGTH(brightness), 1 },
    { "w", "Wi-Fi", "lt-shortcut wifi", 0, wifi, LENGTH(wifi), 1 },
    { "B", "Bluetooth", "lt-shortcut bluetooth", 0, bluetooth, LENGTH(bluetooth), 1 }
};

static item items[] = {
    { "a", "Aplicaciones (Rofi)", "lt-shortcut rofi a" },
    { "c", "Ejecutar comando (Rofi)", "lt-shortcut rofi r" },
    { "v", "Cambiar ventana (Rofi)", "lt-shortcut rofi w" },
    { "m", "Equipo", NULL, 0, machine, LENGTH(machine), 1 },
    { "r", "Rotar pantalla y tactil", "lt-shortcut rotate", 0, rotation, LENGTH(rotation), 1 }
};
