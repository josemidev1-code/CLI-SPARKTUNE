"""Ayuda a elegir qué revisar cuando falta espacio."""
import os
import shutil
import sys
from pathlib import Path

import typer

from .archivos import errores_cli, leer_carpeta


def gib(cantidad):
    return f"{cantidad / 1024**3:.1f} GiB"


def registrar(app: typer.Typer):
    @app.command()
    def limpiar(
        carpeta: Path = typer.Argument(Path("."), help="Carpeta cuyos archivos quieres revisar."),
        abrir: bool = typer.Option(False, "--abrir-almacenamiento", help="Abre el panel de almacenamiento de Windows."),
    ):
        """Muestra el espacio libre y los archivos grandes antes de elegir qué limpiar."""
        with errores_cli():
            base, entradas = leer_carpeta(carpeta)
            disco = shutil.disk_usage(base)
            typer.echo(f"Espacio libre en el volumen: {gib(disco.free)} de {gib(disco.total)}.")
            archivos = sorted((e for e in entradas if e.tipo == "archivo"),
                              key=lambda e: e.estado.st_size, reverse=True)
            typer.echo(f"Archivos de esta carpeta por tamaño (hasta diez de {len(archivos)}):")
            for entrada in archivos[:10]:
                typer.echo(f"  {entrada.estado.st_size:>12} bytes  {entrada.ruta.name!r}")
            typer.echo("Revisa primero los tamaños mayores. Conserva una copia antes de borrar archivos personales.")
            if sys.platform == "win32":
                typer.echo("Para revisar temporales de Windows, abre Configuración > Sistema > Almacenamiento.")
                if abrir and typer.confirm("¿Abrir Almacenamiento para que elijas los temporales?", default=False):
                    os.startfile("ms-settings:storagesense")
            elif abrir:
                typer.echo("El panel de Almacenamiento solo está disponible en Windows.", err=True)
                raise typer.Exit(2)
