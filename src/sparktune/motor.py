"""Motor: convierte acciones en un plan, lo muestra y lo aplica sin tocar los originales."""

import os
from dataclasses import dataclass
from pathlib import Path

from .acciones import Accion
from .errores import ErrorEjecucion, ErrorSparkTune
from .ficheros import Entrada, leer_carpeta

NOMBRE_SALIDA = "sparktune-salida"
MARCA_INCOMPLETA = ".incompleto"


@dataclass(frozen=True)
class Paso:
    accion: Accion
    fuentes: tuple[Entrada, ...]

    def lineas(self) -> list[str]:
        return [f"{self.accion.id} ({len(self.fuentes)} archivos)", *self.accion.describir(self.fuentes)]


@dataclass(frozen=True)
class Plan:
    """Lo que se va a escribir y dónde. La simulación y la ejecución muestran lo mismo."""

    destino: Path
    pasos: tuple[Paso, ...]

    @staticmethod
    def preparar(carpeta: Path, acciones: list[Accion]) -> "Plan":
        """Fábrica: lee la carpeta y prepara el plan."""
        base, entradas = leer_carpeta(carpeta)
        return Plan.desde_entradas(base, entradas, acciones)

    @staticmethod
    def desde_entradas(carpeta: Path, entradas: list[Entrada], acciones: list[Accion]) -> "Plan":
        """Fábrica: revisa cada acción antes de reservar una salida."""
        assert acciones and all(isinstance(accion, Accion) for accion in acciones)
        pasos = []
        for accion in acciones:
            fuentes = accion.seleccionar(entradas)
            accion.revisar(fuentes)
            pasos.append(Paso(accion, fuentes))
        return Plan(Plan._destino_libre(carpeta), tuple(pasos))

    @staticmethod
    def _destino_libre(carpeta: Path) -> Path:
        destino, numero = carpeta / NOMBRE_SALIDA, 1
        while os.path.lexists(destino):
            numero += 1
            destino = carpeta / f"{NOMBRE_SALIDA}-{numero}"
        return destino

    def lineas(self) -> list[str]:
        return [f"Salida prevista: {self.destino}", *(linea for paso in self.pasos for linea in paso.lineas())]

    def aplicar(self) -> None:
        """Crea la salida. Si algo falla, deja la marca .incompleto y conserva los originales."""
        # mkdir sin exist_ok reserva la salida incluso con dos ejecuciones simultáneas.
        self.destino.mkdir(mode=0o700)
        try:
            marca = self.destino / MARCA_INCOMPLETA
            marca.touch(exist_ok=False)
            for paso in self.pasos:
                carpeta = self.destino / paso.accion.id
                carpeta.mkdir()
                paso.accion.escribir(paso.fuentes, carpeta)
            marca.unlink()
        except (OSError, ErrorSparkTune, UnicodeError) as error:
            raise ErrorEjecucion(f"Ejecución incompleta en {self.destino}. Los originales se conservan. "
                                 f"Revisa o descarta esa salida antes de usarla. Detalle: {error}") from error
