"""Carga y validación del catálogo acciones.json."""

import json
import os
from pathlib import Path

from .acciones import Accion
from .errores import AccionNoValida, ConfigError
from .esquema import objeto_sin_duplicados, validar_campos, validar_id


class Catalogo:
    """Acciones y perfiles ya validados. Se crea con desde_archivo() o desde_datos()."""

    VERSION = 1

    def __init__(self, acciones: dict[str, Accion], perfiles: dict[str, tuple[str, ...]], datos: dict):
        # Invariantes que garantiza desde_datos(); se comprueban durante el desarrollo.
        assert all(miembro in acciones for miembros in perfiles.values() for miembro in miembros)
        assert not set(acciones) & set(perfiles)
        self._acciones = acciones
        self._perfiles = perfiles
        self.datos = datos

    @property
    def acciones(self) -> list[Accion]:
        return list(self._acciones.values())

    @property
    def perfiles(self) -> dict[str, tuple[str, ...]]:
        return dict(self._perfiles)

    @staticmethod
    def ruta_por_defecto() -> Path:
        """./acciones.json si existe; si no, el catálogo incluido en el paquete."""
        candidatas = (Path("acciones.json"), Path(__file__).with_name("acciones.json"),
                      Path(__file__).resolve().parents[2] / "acciones.json")
        for ruta in candidatas:
            if os.path.lexists(ruta):
                return ruta
        return candidatas[0]

    @staticmethod
    def desde_archivo(ruta: Path | None = None) -> "Catalogo":
        """Fábrica: lee el JSON y lo valida antes de que se ejecute nada."""
        ruta = ruta or Catalogo.ruta_por_defecto()
        try:
            texto = Path(ruta).read_text(encoding="utf-8-sig")
            return Catalogo.desde_datos(json.loads(texto, object_pairs_hook=objeto_sin_duplicados))
        except (OSError, ValueError, RecursionError) as error:
            # ConfigError hereda de Exception, no de ValueError: se trata aparte.
            raise ConfigError(f"Catálogo inválido en {ruta}: {error}") from error
        except ConfigError as error:
            raise ConfigError(f"Catálogo inválido en {ruta}: {error}") from error

    @staticmethod
    def desde_datos(datos: object) -> "Catalogo":
        """Fábrica: valida un catálogo ya decodificado e indica el campo que falla."""
        validar_campos(datos, ("version", "acciones", "perfiles"), "El catálogo")
        if type(datos["version"]) is not int or datos["version"] != Catalogo.VERSION:
            raise ConfigError(f"version debe ser el entero {Catalogo.VERSION}.")
        lista = datos["acciones"]
        if not isinstance(lista, list) or not lista:
            raise ConfigError("acciones debe ser una lista no vacía.")
        acciones: dict[str, Accion] = {}
        for i, entrada in enumerate(lista):
            accion = Accion.desde_config(entrada, f"acciones[{i}]")
            if accion.id in acciones:
                raise ConfigError(f"acciones[{i}].id repetido: {accion.id}.")
            acciones[accion.id] = accion
        return Catalogo(acciones, Catalogo._validar_perfiles(datos["perfiles"], acciones), datos)

    @staticmethod
    def _validar_perfiles(perfiles: object, acciones: dict[str, Accion]) -> dict[str, tuple[str, ...]]:
        if not isinstance(perfiles, dict):
            raise ConfigError("perfiles debe ser un objeto de listas de acciones.")
        for perfil, miembros in perfiles.items():
            validar_id(perfil, "perfiles")
            if perfil in acciones:
                raise ConfigError(f"El perfil {perfil} coincide con una acción.")
            if not isinstance(miembros, list) or not miembros:
                raise ConfigError(f"perfiles.{perfil} debe ser una lista no vacía.")
            for miembro in miembros:
                if not isinstance(miembro, str) or miembro not in acciones:
                    raise ConfigError(f"perfiles.{perfil}: acción desconocida {miembro!r}.")
            if len(set(miembros)) != len(miembros):
                raise ConfigError(f"perfiles.{perfil} contiene acciones repetidas.")
        return {perfil: tuple(miembros) for perfil, miembros in perfiles.items()}

    def seleccionar(self, nombre: str) -> list[Accion]:
        """Resuelve «accion», «perfil» o «a,b,perfil» sin repetir acciones."""
        elegidas: dict[str, Accion] = {}
        for elemento in nombre.split(","):
            clave = elemento.strip()
            for identificador in self._perfiles.get(clave, (clave,)):
                if identificador not in self._acciones:
                    raise AccionNoValida(f"Acción o perfil desconocido: {identificador!r}. Consulta «acciones».")
                elegidas[identificador] = self._acciones[identificador]
        return list(elegidas.values())
