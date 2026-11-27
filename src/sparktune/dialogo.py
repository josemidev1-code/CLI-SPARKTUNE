"""Conversación con el usuario en la terminal: preguntas, errores y opciones comunes."""

from contextlib import contextmanager
from pathlib import Path

import typer

from .errores import ErrorSparkTune, describir

_SI = {"s", "sí", "si", "y", "yes"}
_NO = {"n", "no"}


def confirmar(pregunta: str) -> bool:
    """Pregunta [s/N]. Enter equivale a no; cualquier otra respuesta se vuelve a pedir.

    Sin respuesta (entrada cerrada o Ctrl+C) se toma como «no»: nunca se cambia nada por defecto.
    """
    while True:
        try:
            respuesta = typer.prompt(f"{pregunta} [s/N]", default="n", show_default=False).strip().casefold()
        except typer.Abort:
            typer.echo("")
            typer.echo("Sin respuesta: lo tomo como «no». Para confirmar sin preguntar, usa --si donde exista.",
                       err=True)
            return False
        if respuesta in _SI:
            return True
        if respuesta in _NO:
            return False
        typer.echo("Responde s o n.")


@contextmanager
def errores_cli():
    """Ningún error previsible termina en traza: mensaje en stderr y código de salida propio."""
    try:
        yield
    except ErrorSparkTune as error:
        typer.echo(f"Error: {error}", err=True)
        raise typer.Exit(error.codigo_salida) from error
    except (OSError, UnicodeError) as error:
        typer.echo(f"Error: {describir(error)}", err=True)
        raise typer.Exit(1) from error


def opciones_ia(ctx: typer.Context, local: bool, env_file: Path | None) -> tuple[bool, Path | None]:
    """Combina --local y --env-file de la orden con los mismos indicados antes de ella (sparktune --local …)."""
    raiz = ctx.find_root().params
    return local or bool(raiz.get("local")), env_file or raiz.get("env_file")
