"""Asistente que se abre al ejecutar sparktune sin órdenes. Pensado para cualquiera de la familia.

Pregunta qué vas a hacer con el ordenador, explica qué cambiaría y por qué, y lo aplica
solo si dices que sí. La IA recomienda; los cambios salen siempre de los catálogos de SparkTune.
"""

import re
import unicodedata

import typer

from . import energia, preparar
from .dialogo import confirmar
from .errores import ErrorIA
from .proveedores import VOCABULARIO, ProveedorGroq, texto_seguro

BIENVENIDA = (
    "Hola, soy SparkTune. Te ayudo a preparar el ordenador para lo que vas a hacer con él.\n"
    "Te haré una pregunta, te explicaré qué cambiaría y por qué, y solo lo cambiaré si me dices que sí.\n"
    "Todo lo que cambie se puede deshacer."
)
PREGUNTA = "¿Qué vas a hacer con el ordenador? Por ejemplo: ver series, jugar, hacer deberes o programar"


def perfil_apps(uso: str) -> str | None:
    """Perfil de aplicaciones que encaja con el uso, si el texto lo menciona claramente."""
    texto = "".join(c for c in unicodedata.normalize("NFKD", uso.casefold()) if not unicodedata.combining(c))
    mejor, aciertos = None, 0
    for perfil, palabras in VOCABULARIO.items():
        n = sum(1 for p in palabras if re.search(rf"\b{p}\b", texto))
        if perfil != "casa" and perfil in preparar.PERFILES and n > aciertos:
            mejor, aciertos = perfil, n
    return mejor


def _groq(env_file):
    try:
        return ProveedorGroq.desde_entorno({}, env_file)
    except ErrorIA:
        return None


def _saludo(groq) -> str:
    if groq is None:
        return BIENVENIDA
    try:
        respuesta = groq.consultar(
            "Saluda en tres frases cortas y cercanas, para alguien sin conocimientos técnicos. Explica que "
            "SparkTune elige un plan de energía según el uso del ordenador, puede instalar programas para "
            "un uso concreto y siempre pide permiso antes de cambiar nada. Devuelve la clave mensaje.",
            {"peticion": "bienvenida"})
        return texto_seguro(respuesta.get("mensaje"), 600) or BIENVENIDA
    except ErrorIA:
        return BIENVENIDA


def asistente(env_file=None, local: bool = False) -> None:
    groq = None if local else _groq(env_file)
    typer.echo(_saludo(groq))
    typer.echo("")
    uso = typer.prompt(PREGUNTA).strip()
    if not texto_seguro(uso) or len(uso) > 1200:
        typer.echo("No he entendido la respuesta. Vuelve a abrir sparktune y cuéntamelo con otras palabras.")
        return

    equipo = preparar.contexto_equipo()
    plan_id, motivo = energia.recomendar_local(uso, equipo)
    if groq is not None:
        try:
            groq_planes = ProveedorGroq.desde_entorno(energia.planes_para(equipo), env_file)
            plan_id, motivo = groq_planes.recomendar(uso, equipo)
        except ErrorIA as error:
            typer.echo(f"({error} Uso mis reglas locales.)")

    typer.echo("")
    typer.echo(f"Tu ordenador: {preparar.resumen_equipo(equipo)}")
    typer.echo(f"Te recomiendo el plan de energía «{energia.PLANES[plan_id].nombre}».")
    typer.echo(f"Por qué: {motivo}")
    typer.echo("Esto es lo que cambiaría:")
    for linea in energia.lineas_plan(plan_id)[2:]:
        typer.echo(linea)
    typer.echo("Para deshacerlo después: sparktune energia restaurar")

    apps = perfil_apps(uso)
    if apps:
        typer.echo(f"También puedo instalar programas para «{preparar.PERFIL_DESCRIPCIONES[apps]}»: "
                   + ", ".join(preparar.PERFILES[apps].paquetes) + ".")

    pesados = energia.procesos_pesados(3)
    if pesados:
        typer.echo("Consejo: estas apps abiertas gastan mucha memoria. Ciérralas si no las usas: "
                   + ", ".join(nombre for nombre, _ in pesados) + ".")

    typer.echo("")
    if not energia._es_windows():
        typer.echo("Esto es una vista previa: los cambios solo se pueden aplicar en Windows.")
        return
    if confirmar("¿Cambio el plan de energía?"):
        energia.activar(plan_id)
    if apps and confirmar("¿Quieres ver e instalar los programas uno a uno?"):
        preparar.preparar(apps, simular=False)
    typer.echo("Listo. Cuando vayas a usar el ordenador para otra cosa, vuelve a abrir sparktune.")
