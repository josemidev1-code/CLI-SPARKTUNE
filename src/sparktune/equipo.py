"""Medición agregada del equipo, sin nombres de usuario, del equipo ni rutas."""

import os
import platform
import shutil

import psutil

_GIB = 1024**3


def es_windows() -> bool:
    return platform.system() == "Windows"


def contexto_equipo() -> dict:
    """Datos agregados para preparar el plan, sin identificadores de usuario o máquina."""
    sistema = platform.system()
    unidad = os.environ.get("SystemDrive", "C:") + "\\" if sistema == "Windows" else "/"
    try:
        espacio = round(shutil.disk_usage(unidad).free / _GIB, 1)
    except OSError:
        espacio = None
    try:
        ram = round(psutil.virtual_memory().total / _GIB, 1)
    except (OSError, psutil.Error, NotImplementedError):
        ram = None
    try:
        bateria = psutil.sensors_battery()
        con_bateria = bateria is not None
        enchufado = bateria.power_plugged if bateria else None
    except (OSError, psutil.Error, NotImplementedError):
        con_bateria = enchufado = None
    return {
        "sistema": sistema, "arquitectura": platform.machine(), "nucleos_logicos": os.cpu_count(),
        "ram_gib": ram, "disco_libre_gib": espacio, "con_bateria": con_bateria, "enchufado": enchufado,
    }


def resumen_equipo(equipo: dict) -> str:
    ram, disco = equipo["ram_gib"], equipo["disco_libre_gib"]
    partes = [f"{equipo['sistema']} {equipo['arquitectura']}",
              f"{ram:g} GiB de RAM" if ram is not None else "RAM desconocida",
              f"{disco:g} GiB libres" if disco is not None else "espacio libre desconocido"]
    if equipo["con_bateria"]:
        # psutil devuelve None si Windows no informa del cargador: no se da por enchufado.
        carga = {True: "enchufado", False: "desenchufado"}.get(equipo["enchufado"], "estado de carga desconocido")
        partes.append(f"con batería, {carga}")
    elif equipo["con_bateria"] is False:
        partes.append("sin batería")
    return " · ".join(partes)


def tipo_equipo(equipo: dict) -> str:
    """El equipo en palabras sencillas: portátil si tiene batería, sobremesa si no."""
    tipo = {True: "un portátil (tiene batería)", False: "un ordenador de sobremesa (sin batería)"}.get(
        equipo.get("con_bateria"), "un ordenador")
    detalles = []
    if equipo.get("ram_gib") is not None:
        detalles.append(f"{equipo['ram_gib']:g} GB de memoria")
    if equipo.get("disco_libre_gib") is not None:
        detalles.append(f"{equipo['disco_libre_gib']:g} GB libres en el disco")
    return tipo + (", con " + " y ".join(detalles) if detalles else "")
