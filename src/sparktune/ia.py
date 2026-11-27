"""Órdenes de orientación: asesorar, explicar y comprobar-ia."""

from pathlib import Path
from typing import Annotated

import typer

from .errores import ErrorIA
from .preparar import PERFIL_DESCRIPCIONES, contexto_equipo
from .proveedores import MODELO, ProveedorGroq, ProveedorIA, ProveedorLocal, texto_seguro

ArchivoEnv = Annotated[Path | None, typer.Option(
    "--env-file", help="Archivo privado con GROQ_API_KEY. La variable de entorno tiene prioridad."
)]
SoloLocal = Annotated[bool, typer.Option("--local", help="Usa las recomendaciones locales sin conectar a Groq.")]


def _remoto(local: bool, env_file: Path | None) -> ProveedorIA | None:
    """Groq si se puede usar; si no, explica el motivo y devuelve None para seguir en local."""
    if local:
        return None
    try:
        return ProveedorGroq.desde_entorno(PERFIL_DESCRIPCIONES, env_file)
    except ErrorIA as error:
        typer.echo(str(error), err=True)
        return None


def asesorar(objetivo: Annotated[str, typer.Argument(help="Describe qué quieres hacer con el equipo.")],
             local: SoloLocal = False, env_file: ArchivoEnv = None):
    """Elige un perfil según tu objetivo y explica el motivo."""
    if not texto_seguro(objetivo) or len(objetivo) > 1200:
        raise typer.BadParameter("Escribe un objetivo de entre 1 y 1200 caracteres.")
    equipo = contexto_equipo()
    proveedor: ProveedorIA = ProveedorLocal(PERFIL_DESCRIPCIONES)
    perfil, motivo = proveedor.recomendar(objetivo, equipo)
    remoto = _remoto(local, env_file)
    if remoto is not None:
        try:
            perfil, motivo = remoto.recomendar(objetivo, equipo)
            proveedor = remoto
        except ErrorIA as error:
            typer.echo(str(error), err=True)
    typer.echo(f"Recomendación {_origen(proveedor)} · {perfil}\n{motivo}\n"
               f"Para ver el plan, ejecuta sparktune preparar {perfil} --simular")


def explicar(perfil: Annotated[str, typer.Argument(help="Identificador que aparece en sparktune perfiles.")],
             local: SoloLocal = False, env_file: ArchivoEnv = None):
    """Interpreta los recursos del equipo para trabajar con un perfil elegido."""
    if perfil not in PERFIL_DESCRIPCIONES:
        raise typer.BadParameter("Perfil desconocido. Consulta sparktune perfiles.")
    equipo = contexto_equipo()
    proveedor: ProveedorIA = ProveedorLocal(PERFIL_DESCRIPCIONES)
    lineas = proveedor.explicar(perfil, equipo)
    remoto = _remoto(local, env_file)
    if remoto is not None:
        try:
            lineas = remoto.explicar(perfil, equipo)
            proveedor = remoto
        except ErrorIA as error:
            typer.echo(str(error), err=True)
    typer.echo(f"Explicación {_origen(proveedor)} · {perfil}")
    for linea in lineas:
        typer.echo(linea)
    typer.echo(f"Para ver el plan, ejecuta sparktune preparar {perfil} --simular")


def comprobar_ia(env_file: ArchivoEnv = None):
    """Verifica con una consulta mínima que Groq puede responder con el modelo."""
    try:
        ProveedorGroq.desde_entorno(PERFIL_DESCRIPCIONES, env_file).comprobar()
    except ErrorIA as error:
        typer.echo(str(error), err=True)
        raise typer.Exit(error.codigo_salida) from None
    typer.echo(f"Conexión verificada con Groq · {MODELO}")


def _origen(proveedor: ProveedorIA) -> str:
    return "local" if isinstance(proveedor, ProveedorLocal) else f"de {proveedor.nombre}"


def registrar(app: typer.Typer):
    app.command()(asesorar)
    app.command()(explicar)
    app.command("comprobar-ia")(comprobar_ia)
