"""Preguntas al usuario en la terminal."""

import typer

_SI = {"s", "sí", "si", "y", "yes"}
_NO = {"n", "no"}


def confirmar(pregunta: str) -> bool:
    """Pregunta [s/N]. Enter equivale a no; cualquier otra respuesta se vuelve a pedir."""
    while True:
        respuesta = typer.prompt(f"{pregunta} [s/N]", default="n", show_default=False).strip().casefold()
        if respuesta in _SI:
            return True
        if respuesta in _NO:
            return False
        typer.echo("Responde s o n.")
