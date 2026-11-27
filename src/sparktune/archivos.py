"""Catálogo declarativo y operaciones portátiles sobre la carpeta elegida."""

import hashlib
import json
import os
import re
import shutil
import stat
import unicodedata
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path, PureWindowsPath

import typer


class ErrorArchivos(ValueError):
    """Error de catálogo o de operación que puede corregir el usuario."""


class ErrorCatalogo(ErrorArchivos):
    """El catálogo necesita una corrección antes de ejecutarse."""


class ErrorSeleccion(ErrorArchivos):
    """El usuario ha solicitado una acción o perfil desconocidos."""


@contextmanager
def errores_cli():
    try:
        yield
    except (ErrorArchivos, OSError, UnicodeError) as error:
        typer.echo(f"Error: {error}", err=True)
        if isinstance(error, ErrorCatalogo):
            raise typer.Exit(3) from error
        if isinstance(error, ErrorSeleccion):
            raise typer.Exit(2) from error
        raise typer.Exit(1) from error


def objeto_sin_duplicados(pares):
    objeto = {}
    for clave, valor in pares:
        if clave in objeto:
            raise ErrorArchivos(f"Campo JSON repetido: {clave!r}.")
        objeto[clave] = valor
    return objeto


def validar_campos(objeto, esperados, lugar):
    if not isinstance(objeto, dict):
        raise ErrorArchivos(f"{lugar} debe ser un objeto.")
    for campo in esperados:
        if campo not in objeto:
            raise ErrorArchivos(f"Falta el campo {lugar}.{campo}.")
    for campo in objeto:
        if campo not in esperados:
            raise ErrorArchivos(f"Campo desconocido: {lugar}.{campo}.")


def validar_id(valor, lugar):
    if not isinstance(valor, str) or not re.fullmatch(r"[a-z][a-z0-9-]{0,47}", valor):
        raise ErrorArchivos(f"{lugar}: usa de 1 a 48 letras minúsculas ASCII, números o guiones, empezando por letra.")
    if PureWindowsPath(valor).is_reserved():
        raise ErrorArchivos(f"{lugar}: nombre reservado en Windows.")


def cargar_catalogo(ruta: Path | None = None) -> dict:
    if ruta is None:
        ruta = Path("acciones.json")
        if not os.path.lexists(ruta):
            ruta = Path(__file__).with_name("acciones.json")
        if not os.path.lexists(ruta):
            ruta = Path(__file__).resolve().parents[2] / "acciones.json"
    try:
        texto = Path(ruta).read_text(encoding="utf-8-sig")
        catalogo = json.loads(texto, object_pairs_hook=objeto_sin_duplicados)
        validar_catalogo(catalogo)
    except (OSError, ValueError, RecursionError) as error:
        raise ErrorCatalogo(f"Catálogo inválido en {ruta}: {error}") from error
    return catalogo


def validar_catalogo(catalogo):
    validar_campos(catalogo, ("version", "acciones", "perfiles"), "El catálogo")
    if type(catalogo["version"]) is not int or catalogo["version"] != 1:
        raise ErrorArchivos("version debe ser el entero 1.")
    acciones = catalogo["acciones"]
    if not isinstance(acciones, list) or not acciones:
        raise ErrorArchivos("acciones debe ser una lista no vacía.")
    ids = set()
    for i, accion in enumerate(acciones):
        lugar = f"acciones[{i}]"
        validar_campos(accion, ("id", "descripcion", "tipo", "extensiones"), lugar)
        nombre = accion["id"]
        validar_id(nombre, f"{lugar}.id")
        if nombre in ids:
            raise ErrorArchivos(f"{lugar}.id repetido: {nombre}.")
        ids.add(nombre)
        descripcion = accion["descripcion"]
        if not isinstance(descripcion, str) or not descripcion.strip() or not descripcion.isprintable():
            raise ErrorArchivos(f"{lugar}.descripcion debe ser texto visible.")
        tipo = accion["tipo"]
        if tipo not in ("copiar", "inventario", "huellas"):
            raise ErrorArchivos(f"{lugar}.tipo debe ser copiar, inventario o huellas.")
        extensiones = accion["extensiones"]
        if not isinstance(extensiones, list) or (tipo == "copiar" and not extensiones):
            raise ErrorArchivos(f"{lugar}.extensiones debe ser una lista con al menos una extensión para copiar.")
        for extension in extensiones:
            if not isinstance(extension, str) or not re.fullmatch(r"\.[a-z0-9]{1,16}", extension):
                raise ErrorArchivos(f"{lugar}.extensiones: se esperaba una extensión como .png.")
        if len(set(extensiones)) != len(extensiones):
            raise ErrorArchivos(f"{lugar}.extensiones contiene duplicados.")
    if not isinstance(catalogo["perfiles"], dict):
        raise ErrorArchivos("perfiles debe ser un objeto de listas de acciones.")
    for perfil, miembros in catalogo["perfiles"].items():
        validar_id(perfil, "perfiles")
        if perfil in ids:
            raise ErrorArchivos(f"El perfil {perfil} coincide con una acción.")
        if not isinstance(miembros, list) or not miembros:
            raise ErrorArchivos(f"perfiles.{perfil} debe ser una lista no vacía.")
        for miembro in miembros:
            if not isinstance(miembro, str) or miembro not in ids:
                raise ErrorArchivos(f"perfiles.{perfil}: acción desconocida {miembro!r}.")
        if len(set(miembros)) != len(miembros):
            raise ErrorArchivos(f"perfiles.{perfil} contiene acciones repetidas.")


def seleccionar(catalogo, nombre):
    acciones = {accion["id"]: accion for accion in catalogo["acciones"]}
    elegidas = {}
    for elemento in nombre.split(","):
        clave = elemento.strip()
        for identificador in catalogo["perfiles"].get(clave, [clave]):
            if identificador not in acciones:
                raise ErrorSeleccion(f"Acción o perfil desconocido: {identificador!r}. Consulta «acciones».")
            elegidas[identificador] = acciones[identificador]
    return list(elegidas.values())


def es_enlace(estado):
    # Incluye junctions y otros puntos de reanálisis de Windows.
    return stat.S_ISLNK(estado.st_mode) or bool(
        getattr(estado, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT
    )


@dataclass(frozen=True)
class Entrada:
    ruta: Path
    estado: os.stat_result

    @property
    def tipo(self):
        if es_enlace(self.estado):
            return "enlace"
        if stat.S_ISREG(self.estado.st_mode):
            return "archivo"
        if stat.S_ISDIR(self.estado.st_mode):
            return "carpeta"
        return "especial"

    def ficha(self):
        fecha = datetime.fromtimestamp(self.estado.st_mtime, timezone.utc).isoformat(timespec="seconds")
        ficha = {"nombre": self.ruta.name, "tipo": self.tipo, "modificado": fecha}
        if self.tipo == "archivo":
            ficha["bytes"] = self.estado.st_size
        return ficha


def leer_carpeta(carpeta):
    carpeta = carpeta.expanduser().absolute()
    # Inspecciona cada componente antes de permitir escrituras bajo la ruta.
    for componente in [*reversed(carpeta.parents), carpeta]:
        if componente.name == ".." or es_enlace(componente.lstat()):
            raise ErrorArchivos(f"La ruta contiene un enlace o '..': {componente!s}.")
    if not carpeta.is_dir():
        raise ErrorArchivos(f"Se esperaba una carpeta: {carpeta}.")
    entradas = [Entrada(ruta, ruta.lstat()) for ruta in carpeta.iterdir()]
    return carpeta, sorted(entradas, key=lambda entrada: (entrada.ruta.name.casefold(), entrada.ruta.name))


def firma(estado):
    return estado.st_dev, estado.st_ino, estado.st_size, estado.st_mtime_ns, estado.st_ctime_ns


def comprobar(entrada, estado):
    if es_enlace(estado) or not stat.S_ISREG(estado.st_mode) or firma(estado) != firma(entrada.estado):
        raise ErrorArchivos(f"El archivo cambió después de preparar el plan: {entrada.ruta.name!r}.")


@contextmanager
def abrir_origen(entrada):
    comprobar(entrada, entrada.ruta.lstat())
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_BINARY", 0)
    with os.fdopen(os.open(entrada.ruta, flags), "rb") as flujo:
        comprobar(entrada, os.fstat(flujo.fileno()))
        yield flujo
        comprobar(entrada, os.fstat(flujo.fileno()))


@dataclass(frozen=True)
class Paso:
    id: str
    tipo: str
    fuentes: tuple[Entrada, ...]

    @property
    def informe(self):
        return "inventario.json" if self.tipo == "inventario" else "sha256.json"


def nombre_portable(nombre):
    return (not PureWindowsPath(nombre).is_reserved() and not nombre.endswith((" ", "."))
            and all(ord(letra) >= 32 and letra not in '<>:"/\\|?*' for letra in nombre))


def planificar(carpeta, entradas, acciones):
    pasos = []
    for accion in acciones:
        extensiones = accion["extensiones"]
        fuentes = tuple(entrada for entrada in entradas if entrada.tipo == "archivo"
                        and (not extensiones or entrada.ruta.suffix.lower() in extensiones))
        if accion["tipo"] == "copiar":
            nombres = set()
            for entrada in fuentes:
                nombre = entrada.ruta.name
                clave = unicodedata.normalize("NFC", nombre).casefold()
                if not nombre_portable(nombre) or clave in nombres:
                    raise ErrorArchivos(f"Nombre incompatible o en colisión en {accion['id']}: {nombre!r}.")
                nombres.add(clave)
        pasos.append(Paso(accion["id"], accion["tipo"], fuentes))
    destino = carpeta / "sparktune-salida"
    numero = 1
    while os.path.lexists(destino):
        numero += 1
        destino = carpeta / f"sparktune-salida-{numero}"
    return destino, pasos


def mostrar_plan(destino, pasos):
    typer.echo(f"Salida prevista: {destino}")
    for paso in pasos:
        typer.echo(f"{paso.id} ({len(paso.fuentes)} archivos)")
        if paso.tipo != "copiar":
            typer.echo(f"  Crear {paso.id}/{paso.informe}")
        for entrada in paso.fuentes:
            nombre = json.dumps(entrada.ruta.name, ensure_ascii=False)
            if paso.tipo == "copiar":
                typer.echo(f"  Copiar {nombre} → {paso.id}/{nombre}")
            else:
                typer.echo(f"  Incluir {nombre}")


def escribir_paso(paso, destino):
    carpeta = destino / paso.id
    carpeta.mkdir()
    if paso.tipo == "copiar":
        for entrada in paso.fuentes:
            with abrir_origen(entrada) as origen, (carpeta / entrada.ruta.name).open("xb") as salida:
                shutil.copyfileobj(origen, salida)
        return
    registros = []
    for entrada in paso.fuentes:
        comprobar(entrada, entrada.ruta.lstat())
        registro = {"nombre": entrada.ruta.name, "bytes": entrada.estado.st_size}
        if paso.tipo == "huellas":
            with abrir_origen(entrada) as origen:
                registro["sha256"] = hashlib.file_digest(origen, "sha256").hexdigest()
        registros.append(registro)
    with (carpeta / paso.informe).open("x", encoding="utf-8") as salida:
        json.dump(registros, salida, ensure_ascii=True, indent=2)
        salida.write("\n")


def aplicar(destino, pasos):
    # mkdir sin exist_ok reserva la salida incluso con dos ejecuciones simultáneas.
    destino.mkdir(mode=0o700)
    try:
        marca = destino / ".incompleto"
        marca.touch(exist_ok=False)
        for paso in pasos:
            escribir_paso(paso, destino)
        marca.unlink()
    except (OSError, ErrorArchivos, UnicodeError) as error:
        raise ErrorArchivos(f"Ejecución incompleta en {destino}. Los originales se conservan. "
                            f"Revisa o descarta esa salida antes de usarla. Detalle: {error}") from error


def imprimir_json(datos):
    typer.echo(json.dumps(datos, ensure_ascii=True, indent=2))


def registrar(app: typer.Typer):
    @app.command()
    def listar(carpeta: Path = typer.Argument(Path(".")), json_: bool = typer.Option(False, "--json")):
        """Lista el contenido inmediato de una carpeta, incluidos enlaces y carpetas."""
        with errores_cli():
            _, entradas = leer_carpeta(carpeta)
            if json_:
                imprimir_json([entrada.ficha() for entrada in entradas])
                return
            if not entradas:
                typer.echo("Carpeta vacía.")
                return
            typer.echo(f"{'TIPO':8} {'BYTES':>12}  {'MODIFICADO (UTC)':25}  NOMBRE")
            for entrada in entradas:
                ficha = entrada.ficha()
                nombre = json.dumps(ficha["nombre"], ensure_ascii=False)
                typer.echo(f"{ficha['tipo']:8} {ficha.get('bytes', '—'):>12}  {ficha['modificado']:25}  {nombre}")

    @app.command()
    def acciones(ctx: typer.Context, json_: bool = typer.Option(False, "--json")):
        """Muestra las acciones de archivos y los perfiles que las combinan."""
        with errores_cli():
            catalogo = cargar_catalogo(ctx.obj)
            if json_:
                imprimir_json(catalogo)
                return
            for accion in catalogo["acciones"]:
                typer.echo(f"{accion['id']}  {accion['descripcion']}")
            for perfil, miembros in catalogo["perfiles"].items():
                typer.echo(f"{perfil}  {', '.join(miembros)}")

    @app.command()
    def validar(ctx: typer.Context):
        """Comprueba la versión, los campos y las referencias del catálogo JSON."""
        with errores_cli():
            catalogo = cargar_catalogo(ctx.obj)
            typer.echo(f"Catálogo válido, versión 1. {len(catalogo['acciones'])} acciones y "
                       f"{len(catalogo['perfiles'])} perfiles.")

    @app.command()
    def ejecutar(ctx: typer.Context, nombre: str, carpeta: Path = typer.Argument(Path(".")),
                 simular: bool = typer.Option(False, "--simular", help="Muestra el plan sin escribir archivos."),
                 si: bool = typer.Option(False, "--si", help="Confirma la creación de la salida.")):
        """Ejecuta una acción, un perfil o varios IDs separados por comas."""
        with errores_cli():
            elegidas = seleccionar(cargar_catalogo(ctx.obj), nombre)
            base, entradas = leer_carpeta(carpeta)
            destino, pasos = planificar(base, entradas, elegidas)
            mostrar_plan(destino, pasos)
            if simular:
                typer.echo("Simulación completada.")
                return
            if not si and not typer.confirm("¿Crear esta salida y conservar los originales?", default=False):
                typer.echo("Cancelado.")
                return
            aplicar(destino, pasos)
            typer.echo(f"Salida creada en {destino}. Para deshacer la operación, descarta esa carpeta.")
