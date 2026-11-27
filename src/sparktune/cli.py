"""Interfaz de línea de órdenes. Traduce los errores previsibles a mensajes y códigos de salida."""

import json
import os
import shutil
import sys
from importlib.metadata import version as installed_version
from pathlib import Path
from typing import Annotated

import typer

from . import energia, ia, preparar
from .asistente import asistente
from .config import Catalogo
from .dialogo import confirmar, errores_cli
from .ficheros import leer_carpeta
from .motor import Plan

app = typer.Typer(
    add_completion=False, pretty_exceptions_enable=False,
    help="Prepara tu PC según el uso que le vas a dar. Ejecuta sparktune sin nada más para abrir el asistente.",
)


@app.callback(invoke_without_command=True)
def inicio(ctx: typer.Context, config: Annotated[Path | None, typer.Option(
    "--config", help="Ruta a tu catálogo JSON de acciones de archivos."
)] = None, local: Annotated[bool, typer.Option(
    "--local", help="El asistente usa reglas locales sin conectar a Groq."
)] = False, env_file: Annotated[Path | None, typer.Option(
    "--env-file", help="Archivo privado con GROQ_API_KEY para el asistente."
)] = None):
    usar_utf8()
    ctx.obj = config.expanduser() if config else None
    if ctx.invoked_subcommand is None:
        asistente(env_file, local)


def usar_utf8():
    """Escribe en UTF-8 aunque Windows redirija la salida con una codificación antigua."""
    for flujo in (sys.stdout, sys.stderr):
        if callable(getattr(flujo, "reconfigure", None)):
            flujo.reconfigure(encoding="utf-8")


def imprimir_json(datos):
    typer.echo(json.dumps(datos, ensure_ascii=True, indent=2))


@app.command()
def version():
    """Muestra la versión instalada."""
    typer.echo(installed_version("sparktune"))


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
        catalogo = Catalogo.desde_archivo(ctx.obj)
        if json_:
            imprimir_json(catalogo.datos)
            return
        for accion in catalogo.acciones:
            typer.echo(f"{accion.id}  {accion.descripcion}")
        for perfil, miembros in catalogo.perfiles.items():
            typer.echo(f"{perfil}  {', '.join(miembros)}")


@app.command()
def validar(ctx: typer.Context):
    """Comprueba la versión, los campos y las referencias del catálogo JSON."""
    with errores_cli():
        catalogo = Catalogo.desde_archivo(ctx.obj)
        typer.echo(f"Catálogo válido, versión {Catalogo.VERSION}. {len(catalogo.acciones)} acciones y "
                   f"{len(catalogo.perfiles)} perfiles.")


@app.command()
def ejecutar(ctx: typer.Context, nombre: str, carpeta: Path = typer.Argument(Path(".")),
             simular: bool = typer.Option(False, "--simular", help="Muestra el plan sin escribir archivos."),
             si: bool = typer.Option(False, "--si", help="Confirma la creación de la salida.")):
    """Ejecuta una acción, un perfil o varios IDs separados por comas."""
    with errores_cli():
        plan = Plan.preparar(carpeta, Catalogo.desde_archivo(ctx.obj).seleccionar(nombre))
        for linea in plan.lineas():
            typer.echo(linea)
        if simular:
            typer.echo("Simulación completada.")
            return
        if not si and not confirmar("¿Crear esta salida y conservar los originales?"):
            typer.echo("Cancelado.")
            return
        plan.aplicar()
        typer.echo(f"Salida creada en {plan.destino}. Para deshacer la operación, descarta esa carpeta.")


@app.command()
def limpiar(
    carpeta: Path = typer.Argument(Path("."), help="Carpeta cuyos archivos quieres revisar."),
    abrir: bool = typer.Option(False, "--abrir-almacenamiento", help="Abre el panel de almacenamiento de Windows."),
):
    """Muestra el espacio libre y los archivos grandes antes de elegir qué limpiar."""
    with errores_cli():
        base, entradas = leer_carpeta(carpeta)
        disco = shutil.disk_usage(base)
        typer.echo(f"Espacio libre en el volumen: {_gib(disco.free)} de {_gib(disco.total)}.")
        archivos = sorted((e for e in entradas if e.tipo == "archivo"), key=lambda e: e.estado.st_size, reverse=True)
        typer.echo(f"Archivos de esta carpeta por tamaño (hasta diez de {len(archivos)}):")
        for entrada in archivos[:10]:
            typer.echo(f"  {entrada.estado.st_size:>12} bytes  {entrada.ruta.name!r}")
        typer.echo("Revisa primero los tamaños mayores. Conserva una copia antes de borrar archivos personales.")
        if sys.platform == "win32":
            typer.echo("Para revisar temporales de Windows, abre Configuración > Sistema > Almacenamiento.")
            if abrir and confirmar("¿Abrir Almacenamiento para que elijas los temporales?"):
                os.startfile("ms-settings:storagesense")
        elif abrir:
            typer.echo("El panel de Almacenamiento solo está disponible en Windows.", err=True)
            raise typer.Exit(2)


def _gib(cantidad: int) -> str:
    return f"{cantidad / 1024**3:.1f} GiB"


preparar.registrar(app)
ia.registrar(app)
energia.registrar(app)
