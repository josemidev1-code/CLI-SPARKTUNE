"""Excepciones propias de SparkTune.

Cada error previsible lleva su código de salida. La interfaz (cli.py) los
convierte en un mensaje claro y en ese código, sin mostrar trazas.
"""


class ErrorSparkTune(Exception):
    """Error previsible que el usuario puede corregir."""

    codigo_salida = 1


class ConfigError(ErrorSparkTune):
    """El catálogo acciones.json no existe, no es JSON o no cumple el esquema."""

    codigo_salida = 3


class AccionNoValida(ErrorSparkTune):
    """Se ha pedido una acción o un perfil que no están en el catálogo."""

    codigo_salida = 2


class ErrorEjecucion(ErrorSparkTune):
    """La carpeta no es utilizable o un archivo cambió durante la ejecución."""

    codigo_salida = 1


class ErrorIA(ErrorSparkTune):
    """El proveedor de IA no está disponible o respondió algo inutilizable."""

    codigo_salida = 1


class ErrorEnergia(ErrorSparkTune):
    """powercfg falló o el archivo que recuerda el plan original no se puede usar."""

    codigo_salida = 1


def describir(error: BaseException) -> str:
    """Mensaje en español para errores de la biblioteca estándar, que llegan en inglés."""
    import json

    if isinstance(error, json.JSONDecodeError):
        return f"JSON mal formado en la línea {error.lineno}, columna {error.colno}"
    if isinstance(error, FileNotFoundError):
        return f"No existe {error.filename}"
    if isinstance(error, PermissionError):
        return f"Sin permiso sobre {error.filename}"
    if isinstance(error, IsADirectoryError):
        return f"{error.filename} es una carpeta, no un archivo"
    if isinstance(error, NotADirectoryError):
        return f"{error.filename} no es una carpeta"
    if isinstance(error, UnicodeError):
        return "El archivo no está en UTF-8"
    if isinstance(error, OSError):
        return error.strerror or str(error)
    return str(error)
