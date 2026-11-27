"""Punto de entrada de SparkTune."""
from importlib.metadata import version as installed_version
from pathlib import Path
from typing import Annotated

import typer

from . import archivos, limpieza, preparar

app = typer.Typer(
    no_args_is_help=True, add_completion=False, pretty_exceptions_enable=False,
    help="Prepara tu PC según tus intereses. Empieza con perfiles o describe tu objetivo con asesorar.",
)


@app.callback()
def inicio(ctx: typer.Context, config: Annotated[Path | None, typer.Option(
    "--config", help="Ruta a tu catálogo JSON de acciones de archivos."
)] = None):
    ctx.obj = config.expanduser() if config else None


@app.command()
def version():
    """Muestra la versión instalada."""
    typer.echo(installed_version("sparktune"))


archivos.registrar(app)
limpieza.registrar(app)
preparar.registrar(app)
