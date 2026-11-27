"""Reglas comunes del esquema de acciones.json."""

import re
from pathlib import PureWindowsPath

from .errores import ConfigError

PATRON_ID = re.compile(r"[a-z][a-z0-9-]{0,47}")


def validar_campos(objeto: object, esperados: tuple[str, ...], lugar: str) -> None:
    """Exige exactamente los campos esperados e indica cuál falta o sobra."""
    if not isinstance(objeto, dict):
        raise ConfigError(f"{lugar} debe ser un objeto.")
    for campo in esperados:
        if campo not in objeto:
            raise ConfigError(f"Falta el campo {lugar}.{campo}.")
    for campo in objeto:
        if campo not in esperados:
            raise ConfigError(f"Campo desconocido: {lugar}.{campo}.")


def validar_id(valor: object, lugar: str) -> None:
    """Los ID se usan como nombres de carpeta, así que deben ser portables."""
    if not isinstance(valor, str) or not PATRON_ID.fullmatch(valor):
        raise ConfigError(f"{lugar}: usa de 1 a 48 letras minúsculas ASCII, números o guiones, "
                          "empezando por letra.")
    if PureWindowsPath(valor).is_reserved():
        raise ConfigError(f"{lugar}: nombre reservado en Windows.")


def objeto_sin_duplicados(pares: list[tuple[str, object]]) -> dict:
    """Gancho de json.loads: un campo repetido es un error, no se sobrescribe en silencio."""
    objeto = {}
    for clave, valor in pares:
        if clave in objeto:
            raise ConfigError(f"Campo JSON repetido: {clave!r}.")
        objeto[clave] = valor
    return objeto
