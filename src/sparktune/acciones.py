"""Tipos de acción de archivos. Cada tipo del catálogo es una clase.

Para añadir una acción de un tipo existente basta con editar acciones.json.
Para añadir un tipo nuevo, se crea una subclase con su atributo «tipo» y queda
registrada automáticamente para Accion.desde_config().
"""

import hashlib
import json
import re
import shutil
import unicodedata
from abc import ABC, abstractmethod
from pathlib import Path
from typing import ClassVar

from .errores import ConfigError, ErrorEjecucion
from .esquema import validar_campos, validar_id
from .ficheros import Entrada, nombre_portable

CAMPOS = ("id", "descripcion", "tipo", "extensiones")
_PATRON_EXTENSION = re.compile(r"\.[a-z0-9]{1,16}")


class Accion(ABC):
    """Una entrada del catálogo: qué archivos selecciona y qué escribe en la salida."""

    tipo: ClassVar[str]
    requiere_extensiones: ClassVar[bool] = False
    _tipos: ClassVar[dict[str, type["Accion"]]] = {}

    def __init_subclass__(cls, **kwargs):
        super().__init_subclass__(**kwargs)
        if "tipo" in cls.__dict__:
            Accion._tipos[cls.tipo] = cls

    def __init__(self, id: str, descripcion: str, extensiones: tuple[str, ...]):
        self.id = id
        self.descripcion = descripcion
        self.extensiones = extensiones

    @staticmethod
    def tipos() -> tuple[str, ...]:
        return tuple(Accion._tipos)

    @staticmethod
    def desde_config(datos: object, lugar: str) -> "Accion":
        """Fábrica: valida una entrada de acciones.json y crea la clase de su tipo."""
        validar_campos(datos, CAMPOS, lugar)
        validar_id(datos["id"], f"{lugar}.id")
        descripcion = datos["descripcion"]
        if not isinstance(descripcion, str) or not descripcion.strip() or not descripcion.isprintable():
            raise ConfigError(f"{lugar}.descripcion debe ser texto visible.")
        clase = Accion._tipos.get(datos["tipo"]) if isinstance(datos["tipo"], str) else None
        if clase is None:
            raise ConfigError(f"{lugar}.tipo debe ser {', '.join(Accion.tipos()[:-1])} "
                              f"o {Accion.tipos()[-1]}.")
        extensiones = datos["extensiones"]
        if not isinstance(extensiones, list) or (clase.requiere_extensiones and not extensiones):
            raise ConfigError(f"{lugar}.extensiones debe ser una lista con al menos una extensión "
                              f"para {clase.tipo}.")
        for extension in extensiones:
            if not isinstance(extension, str) or not _PATRON_EXTENSION.fullmatch(extension):
                raise ConfigError(f"{lugar}.extensiones: se esperaba una extensión como .png.")
        if len(set(extensiones)) != len(extensiones):
            raise ConfigError(f"{lugar}.extensiones contiene duplicados.")
        return clase(datos["id"], descripcion, tuple(extensiones))

    def seleccionar(self, entradas: list[Entrada]) -> tuple[Entrada, ...]:
        """Archivos regulares con una de las extensiones; sin extensiones, todos."""
        return tuple(entrada for entrada in entradas if entrada.tipo == "archivo"
                     and (not self.extensiones or entrada.ruta.suffix.lower() in self.extensiones))

    def revisar(self, fuentes: tuple[Entrada, ...]) -> None:
        """Comprueba antes de escribir nada que las fuentes se pueden procesar."""

    @abstractmethod
    def describir(self, fuentes: tuple[Entrada, ...]) -> list[str]:
        """Líneas del plan para esta acción, iguales en la simulación y en la ejecución."""

    @abstractmethod
    def escribir(self, fuentes: tuple[Entrada, ...], carpeta: Path) -> None:
        """Escribe el resultado en una carpeta nueva. Nunca modifica las fuentes."""


def _nombre(entrada: Entrada) -> str:
    return json.dumps(entrada.ruta.name, ensure_ascii=False)


class Copiar(Accion):
    """Copia los archivos seleccionados sin sobrescribir nada."""

    tipo = "copiar"
    requiere_extensiones = True

    def revisar(self, fuentes):
        nombres = set()
        for entrada in fuentes:
            nombre = entrada.ruta.name
            # «Foto.PNG» y «foto.png» chocarían en Windows y macOS.
            clave = unicodedata.normalize("NFC", nombre).casefold()
            if not nombre_portable(nombre) or clave in nombres:
                raise ErrorEjecucion(f"Nombre incompatible o en colisión en {self.id}: {nombre!r}.")
            nombres.add(clave)

    def describir(self, fuentes):
        return [f"  Copiar {_nombre(e)} → {self.id}/{_nombre(e)}" for e in fuentes]

    def escribir(self, fuentes, carpeta):
        for entrada in fuentes:
            # «xb» falla si el archivo ya existe: nunca se sobrescribe.
            with entrada.abrir() as origen, (carpeta / entrada.ruta.name).open("xb") as salida:
                shutil.copyfileobj(origen, salida)


class AccionInforme(Accion):
    """Crea un único JSON con un registro por archivo seleccionado."""

    informe: ClassVar[str]

    @abstractmethod
    def registro(self, entrada: Entrada) -> dict:
        """Datos de un archivo para el informe."""

    def describir(self, fuentes):
        return [f"  Crear {self.id}/{self.informe}", *(f"  Incluir {_nombre(e)}" for e in fuentes)]

    def escribir(self, fuentes, carpeta):
        registros = [self.registro(entrada) for entrada in fuentes]
        with (carpeta / self.informe).open("x", encoding="utf-8") as salida:
            json.dump(registros, salida, ensure_ascii=True, indent=2)
            salida.write("\n")


class Inventario(AccionInforme):
    tipo = "inventario"
    informe = "inventario.json"

    def registro(self, entrada):
        entrada.comprobar(entrada.ruta.lstat())
        return {"nombre": entrada.ruta.name, "bytes": entrada.estado.st_size}


class Huellas(AccionInforme):
    tipo = "huellas"
    informe = "sha256.json"

    def registro(self, entrada):
        with entrada.abrir() as origen:
            huella = hashlib.file_digest(origen, "sha256").hexdigest()
        return {"nombre": entrada.ruta.name, "bytes": entrada.estado.st_size, "sha256": huella}
