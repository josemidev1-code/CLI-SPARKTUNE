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
