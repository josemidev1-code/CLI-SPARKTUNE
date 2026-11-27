"""Planes de energía según el uso del equipo: recomendar, aplicar, cambiar y restaurar.

La IA solo elige un plan de este catálogo. Los valores que se escriben en Windows
los fija SparkTune, y restaurar vuelve al plan que estaba activo antes del primero.
"""

import json
import os
import platform
import re
import subprocess
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated
from uuid import uuid4

import psutil
import typer

from .dialogo import confirmar
from .errores import ErrorIA
from .preparar import contexto_equipo, resumen_equipo
from .proveedores import ProveedorGroq, texto_seguro

# Plan Equilibrado de Windows: SparkTune lo duplica y cambia solo los valores del plan.
EQUILIBRADO = "381b4222-f694-41f0-9685-ff5bb260df2e"
_GUID = re.compile(r"[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}")

# Alias de powercfg: no dependen del idioma de Windows.
AJUSTES = {
    "cpu_min": ("SUB_PROCESSOR", "PROCTHROTTLEMIN", "CPU mínima", "%"),
    "cpu_max": ("SUB_PROCESSOR", "PROCTHROTTLEMAX", "CPU máxima", "%"),
    "preferencia": ("SUB_PROCESSOR", "PERFEPP", "Preferencia de ahorro (0 rendimiento, 100 ahorro)", ""),
    "pantalla": ("SUB_VIDEO", "VIDEOIDLE", "Apagar pantalla tras", "s"),
    "suspension": ("SUB_SLEEP", "STANDBYIDLE", "Suspender tras", "s"),
}


@dataclass(frozen=True)
class PlanEnergia:
    nombre: str
    descripcion: str
    solo_portatil: bool
    enchufado: dict[str, int]
    bateria: dict[str, int]


PLANES = {
    "series-bateria": PlanEnergia(
        "SparkTune Series con batería",
        "Ver series, vídeos o películas con batería: CPU limitada al 50% y máximo ahorro.",
        True,
        {"cpu_min": 5, "cpu_max": 100, "preferencia": 50, "pantalla": 900, "suspension": 1800},
        {"cpu_min": 0, "cpu_max": 50, "preferencia": 90, "pantalla": 600, "suspension": 1200},
    ),
    "ofimatica-bateria": PlanEnergia(
        "SparkTune Ofimática con batería",
        "Documentos, navegador y clases con batería: CPU al 70% y pantalla que se apaga pronto.",
        True,
        {"cpu_min": 5, "cpu_max": 100, "preferencia": 50, "pantalla": 600, "suspension": 1800},
        {"cpu_min": 0, "cpu_max": 70, "preferencia": 80, "pantalla": 300, "suspension": 900},
    ),
    "programar": PlanEnergia(
        "SparkTune Programar",
        "Programar y compilar: toda la CPU enchufado y un 90% con batería, sin suspender a mitad de una compilación.",
        False,
        {"cpu_min": 5, "cpu_max": 100, "preferencia": 33, "pantalla": 900, "suspension": 3600},
        {"cpu_min": 5, "cpu_max": 90, "preferencia": 50, "pantalla": 600, "suspension": 1800},
    ),
    "equilibrado": PlanEnergia(
        "SparkTune Equilibrado",
        "Uso general: toda la CPU disponible y tiempos de pantalla y suspensión moderados.",
        False,
        {"cpu_min": 5, "cpu_max": 100, "preferencia": 33, "pantalla": 600, "suspension": 1800},
        {"cpu_min": 5, "cpu_max": 100, "preferencia": 50, "pantalla": 300, "suspension": 900},
    ),
    "maximo-portatil": PlanEnergia(
        "SparkTune Máximo portátil",
        "Exprimir el portátil para jugar o renderizar: CPU al máximo enchufado y con batería. "
        "Gasta más batería y genera más calor.",
        True,
        {"cpu_min": 50, "cpu_max": 100, "preferencia": 0, "pantalla": 1800, "suspension": 0},
        {"cpu_min": 20, "cpu_max": 100, "preferencia": 25, "pantalla": 600, "suspension": 1800},
    ),
}

VOCABULARIO = {
    "series-bateria": ("series", "serie", "peliculas", "pelicula", "netflix", "youtube", "video", "videos",
                       "streaming", "anime"),
    "ofimatica-bateria": ("ofimatica", "office", "word", "excel", "documentos", "navegar", "estudiar",
                          "clases", "apuntes", "correo"),
    "programar": ("programar", "programacion", "codigo", "compilar", "desarrollo", "desarrollar", "python"),
    "maximo-portatil": ("jugar", "juegos", "gaming", "videojuegos", "renderizar", "render", "exprimir",
                        "maximo", "rendimiento", "potencia"),
}


def planes_para(equipo: dict) -> dict[str, str]:
    """Planes que encajan con el equipo. En un sobremesa no se ofrecen los de portátil."""
    sobremesa = equipo.get("con_bateria") is False
    return {id_: plan.descripcion for id_, plan in PLANES.items() if not (sobremesa and plan.solo_portatil)}


def recomendar_local(uso: str, equipo: dict) -> tuple[str, str]:
    texto = "".join(c for c in unicodedata.normalize("NFKD", uso.casefold()) if not unicodedata.combining(c))
    disponibles = planes_para(equipo)
    mejor, encontrados = "equilibrado", []
    for plan, palabras in VOCABULARIO.items():
        coinciden = [p for p in palabras if re.search(rf"\b{p}\b", texto)]
        if plan in disponibles and len(coinciden) > len(encontrados):
            mejor, encontrados = plan, coinciden
    if not encontrados:
        return mejor, "No he reconocido un uso concreto, así que propongo un plan equilibrado."
    citadas = ", ".join(f"«{p}»" for p in encontrados)
    return mejor, f"Mencionas {citadas}: {PLANES[mejor].descripcion}"


def procesos_pesados(limite: int = 5) -> list[tuple[str, int]]:
    """Las apps abiertas que más memoria usan, para que el usuario decida si cerrarlas."""
    procesos = []
    for proceso in psutil.process_iter(["name", "memory_info"]):
        try:
            nombre, memoria = proceso.info["name"], proceso.info["memory_info"]
        except (psutil.Error, KeyError):
            continue
        if nombre and memoria:
            procesos.append((nombre, memoria.rss // 1024**2))
    return sorted(procesos, key=lambda p: p[1], reverse=True)[:limite]


def lineas_plan(plan_id: str) -> list[str]:
    plan = PLANES[plan_id]
    lineas = [f"{plan.nombre} ({plan_id})", f"  {plan.descripcion}"]
    for clave, (_, _, etiqueta, unidad) in AJUSTES.items():
        ac, dc = plan.enchufado[clave], plan.bateria[clave]
        formato = (lambda v: "nunca" if v == 0 else f"{v // 60} min") if unidad == "s" else (lambda v: f"{v}{unidad}")
        lineas.append(f"  {etiqueta}: enchufado {formato(ac)} · batería {formato(dc)}")
    return lineas


# ---------- Windows ----------

def _es_windows() -> bool:
    return platform.system() == "Windows"


def _powercfg(*argumentos: str) -> str:
    # Ruta completa: no se busca powercfg en la carpeta de trabajo.
    exe = Path(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "powercfg.exe")
    resultado = subprocess.run([str(exe), *argumentos], capture_output=True, text=True,
                               errors="replace", timeout=60)
    if resultado.returncode:
        detalle = (resultado.stderr or resultado.stdout).strip()
        raise RuntimeError(f"powercfg {argumentos[0]} falló. {detalle}")
    return resultado.stdout


def _borrar(guid: str) -> None:
    """Borra un plan de SparkTune. Si ya no existe (lo borró el usuario), no es un error."""
    try:
        _powercfg("/delete", guid)
    except RuntimeError:
        pass


def _activo() -> str:
    encontrado = _GUID.search(_powercfg("/getactivescheme"))
    if not encontrado:
        raise RuntimeError("No se pudo leer el plan de energía activo.")
    return encontrado.group(0).lower()


def ruta_estado() -> Path:
    base = os.environ.get("SPARKTUNE_HOME")
    return Path(base) if base else Path.home() / ".sparktune"


def _leer_estado() -> dict | None:
    archivo = ruta_estado() / "energia.json"
    try:
        datos = json.loads(archivo.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, ValueError):
        raise RuntimeError(f"No se pudo leer {archivo}. Revísalo antes de continuar.") from None
    if not (isinstance(datos, dict) and all(isinstance(datos.get(k), str) and _GUID.fullmatch(datos[k])
                                            for k in ("original", "sparktune"))):
        raise RuntimeError(f"{archivo} no tiene el formato esperado. Revísalo antes de continuar.")
    return datos


def _guardar_estado(datos: dict) -> None:
    carpeta = ruta_estado()
    carpeta.mkdir(parents=True, exist_ok=True)
    temporal = carpeta / f"energia.{uuid4().hex}.tmp"
    temporal.write_text(json.dumps(datos, indent=2) + "\n", encoding="utf-8")
    temporal.replace(carpeta / "energia.json")


def aplicar_plan(plan_id: str) -> str:
    """Crea el plan, lo activa y recuerda el plan original. Devuelve el GUID nuevo."""
    plan = PLANES[plan_id]
    estado = _leer_estado()
    original = estado["original"] if estado else _activo()
    nuevo = str(uuid4())
    _powercfg("/duplicatescheme", EQUILIBRADO, nuevo)
    try:
        _powercfg("/changename", nuevo, plan.nombre, plan.descripcion)
        for clave, (grupo, ajuste, _, _) in AJUSTES.items():
            _powercfg("/setacvalueindex", nuevo, grupo, ajuste, str(plan.enchufado[clave]))
            _powercfg("/setdcvalueindex", nuevo, grupo, ajuste, str(plan.bateria[clave]))
        _powercfg("/setactive", nuevo)
    except (RuntimeError, OSError, subprocess.TimeoutExpired):
        _borrar(nuevo)  # El plan a medias no se queda en el equipo.
        raise
    _guardar_estado({"original": original, "sparktune": nuevo, "plan": plan_id})
    if estado:
        # Al cambiar de uso se sustituye el plan anterior de SparkTune.
        _borrar(estado["sparktune"])
    return nuevo


def restaurar_plan() -> bool:
    estado = _leer_estado()
    if not estado:
        return False
    _powercfg("/setactive", estado["original"])
    _borrar(estado["sparktune"])
    (ruta_estado() / "energia.json").unlink()
    return True


# ---------- Órdenes ----------

energia = typer.Typer(help="Elige un plan de energía según el uso que vas a dar al equipo.", no_args_is_help=True)


@energia.command("planes")
def planes():
    """Lista los planes de energía de SparkTune y sus valores."""
    for plan_id in PLANES:
        for linea in lineas_plan(plan_id):
            typer.echo(linea)


@energia.command("recomendar")
def recomendar(
    uso: Annotated[str, typer.Argument(help="Qué vas a hacer, por ejemplo «ver series con batería».")],
    local: Annotated[bool, typer.Option("--local", help="Usa las reglas locales sin conectar a Groq.")] = False,
    env_file: Annotated[Path | None, typer.Option("--env-file", help="Archivo privado con GROQ_API_KEY.")] = None,
):
    """Recomienda un plan de energía para tu uso y explica por qué."""
    if not texto_seguro(uso) or len(uso) > 1200:
        raise typer.BadParameter("Describe el uso en 1 a 1200 caracteres.")
    equipo = contexto_equipo()
    plan_id, motivo = recomendar_local(uso, equipo)
    origen = "local"
    if not local:
        try:
            plan_id, motivo = ProveedorGroq.desde_entorno(planes_para(equipo), env_file).recomendar(uso, equipo)
            origen = "de Groq"
        except ErrorIA as error:
            typer.echo(f"{error} Se usa la recomendación local.", err=True)
    typer.echo(f"Equipo: {resumen_equipo(equipo)}")
    typer.echo(f"Plan recomendado {origen}: {plan_id}")
    typer.echo(f"Por qué: {motivo}")
    for linea in lineas_plan(plan_id):
        typer.echo(linea)
    pesados = procesos_pesados()
    if pesados:
        typer.echo("Apps abiertas que más memoria usan (ciérralas si no las necesitas; SparkTune no las cierra):")
        for nombre, megas in pesados:
            typer.echo(f"  • {nombre}: {megas} MB")
    typer.echo(f"Todavía no se ha cambiado nada. Para aplicarlo: sparktune energia aplicar {plan_id}")


@energia.command("aplicar")
def aplicar(
    plan_id: Annotated[str, typer.Argument(metavar="PLAN", help="Identificador de sparktune energia planes.")],
    simular: Annotated[bool, typer.Option("--simular", help="Muestra los cambios sin aplicarlos.")] = False,
    si: Annotated[bool, typer.Option("--si", help="Confirma el cambio sin preguntar.")] = False,
):
    """Crea y activa el plan. Si ya había uno de SparkTune, lo sustituye."""
    if plan_id not in PLANES:
        raise typer.BadParameter("Plan desconocido. Consulta sparktune energia planes.")
    for linea in lineas_plan(plan_id):
        typer.echo(linea)
    typer.echo("Para volver a tu plan anterior: sparktune energia restaurar")
    if simular or not _es_windows():
        typer.echo("Simulación terminada." if simular else "Vista previa. Los planes de energía requieren Windows.")
        return
    if not si and not confirmar(f"¿Activar el plan {PLANES[plan_id].nombre}?"):
        typer.echo("Cancelado.")
        return
    activar(plan_id)


def activar(plan_id: str) -> None:
    """Aplica el plan e informa del resultado; si falla, sale con código 1 sin dejar el plan a medias."""
    try:
        aplicar_plan(plan_id)
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        typer.echo(f"No se aplicó el plan. {error}", err=True)
        raise typer.Exit(1) from error
    typer.echo(f"Plan activo: {PLANES[plan_id].nombre}. Cuando cambies de uso, aplica otro o restaura el tuyo.")


@energia.command("restaurar")
def restaurar(si: Annotated[bool, typer.Option("--si", help="Confirma sin preguntar.")] = False):
    """Vuelve al plan que tenías antes de SparkTune y borra el de SparkTune."""
    if not _es_windows():
        typer.echo("Los planes de energía requieren Windows. No hay nada que restaurar.")
        return
    if not si and not confirmar("¿Volver a tu plan de energía anterior?"):
        typer.echo("Cancelado.")
        return
    try:
        restaurado = restaurar_plan()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        typer.echo(f"No se pudo restaurar. {error}", err=True)
        raise typer.Exit(1) from error
    typer.echo("Plan anterior restaurado." if restaurado else "No hay ningún plan de SparkTune que restaurar.")


def registrar(app: typer.Typer) -> None:
    app.add_typer(energia, name="energia")
