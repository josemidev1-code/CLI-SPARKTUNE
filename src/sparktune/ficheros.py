"""Lectura segura de la carpeta de trabajo y de los archivos de origen."""

import os
import stat
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path, PureWindowsPath

from .errores import ErrorEjecucion


def es_enlace(estado: os.stat_result) -> bool:
    """Incluye los enlaces simbólicos, las junctions y otros puntos de reanálisis de Windows."""
    return stat.S_ISLNK(estado.st_mode) or bool(
        getattr(estado, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT
    )


def nombre_portable(nombre: str) -> bool:
    """El nombre se puede crear tal cual en Windows, Linux y macOS."""
    return (not PureWindowsPath(nombre).is_reserved() and not nombre.endswith((" ", "."))
            and all(ord(letra) >= 32 and letra not in '<>:"/\\|?*' for letra in nombre))


def firma(estado: os.stat_result) -> tuple:
    """Datos que deben coincidir entre la vista previa y la lectura del archivo."""
    if os.name == "nt":
        # En Windows, Path.lstat() y os.fstat() usan APIs distintas: el número de volumen
        # y el identificador del archivo pueden llegar con distinta anchura de bits.
        return estado.st_ino & 0xFFFF_FFFF_FFFF_FFFF, estado.st_size, estado.st_mtime_ns
    return estado.st_dev, estado.st_ino, estado.st_size, estado.st_mtime_ns, estado.st_ctime_ns


@dataclass(frozen=True)
class Entrada:
    """Un elemento de la carpeta tal como estaba al preparar el plan."""

    ruta: Path
    estado: os.stat_result

    @property
    def tipo(self) -> str:
        if es_enlace(self.estado):
            return "enlace"
        if stat.S_ISREG(self.estado.st_mode):
            return "archivo"
        if stat.S_ISDIR(self.estado.st_mode):
            return "carpeta"
        return "especial"

    def ficha(self) -> dict:
        fecha = datetime.fromtimestamp(self.estado.st_mtime, timezone.utc).isoformat(timespec="seconds")
        ficha = {"nombre": self.ruta.name, "tipo": self.tipo, "modificado": fecha}
        if self.tipo == "archivo":
            ficha["bytes"] = self.estado.st_size
        return ficha

    def comprobar(self, actual: os.stat_result) -> None:
        """Falla si el archivo ya no es el mismo archivo regular de la vista previa."""
        if es_enlace(actual) or not stat.S_ISREG(actual.st_mode) or firma(actual) != firma(self.estado):
            raise ErrorEjecucion(f"El archivo cambió después de preparar el plan: {self.ruta.name!r}.")

    @contextmanager
    def abrir(self):
        """Abre el archivo sin seguir enlaces y comprueba que no cambia mientras se lee."""
        self.comprobar(self.ruta.lstat())
        flags = (os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
                 | getattr(os, "O_BINARY", 0))
        with os.fdopen(os.open(self.ruta, flags), "rb") as flujo:
            self.comprobar(os.fstat(flujo.fileno()))
            yield flujo
            self.comprobar(os.fstat(flujo.fileno()))


def _enlace_del_sistema(estado: os.stat_result) -> bool:
    """Enlaces de root como /tmp o /var en macOS: un usuario sin privilegios no puede crearlos.

    En Windows st_uid siempre vale 0, así que allí se rechaza cualquier enlace.
    """
    return os.name != "nt" and estado.st_uid == 0


def leer_carpeta(carpeta: Path) -> tuple[Path, list[Entrada]]:
    """Devuelve la carpeta absoluta y su contenido inmediato, ordenado por nombre."""
    carpeta = carpeta.expanduser().absolute()
    # Inspecciona cada componente antes de permitir escrituras bajo la ruta.
    for componente in [*reversed(carpeta.parents), carpeta]:
        try:
            estado = componente.lstat()
        except FileNotFoundError:
            raise ErrorEjecucion(f"No existe la carpeta {carpeta}. Comprueba la ruta.") from None
        if componente.name == ".." or (es_enlace(estado) and not _enlace_del_sistema(estado)):
            raise ErrorEjecucion(f"La ruta contiene un enlace o '..': {componente!s}.")
    if not carpeta.is_dir():
        raise ErrorEjecucion(f"Se esperaba una carpeta: {carpeta}.")
    entradas = [Entrada(ruta, ruta.lstat()) for ruta in carpeta.iterdir()]
    return carpeta, sorted(entradas, key=lambda entrada: (entrada.ruta.name.casefold(), entrada.ruta.name))
