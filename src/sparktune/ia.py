"""Orientación sobre perfiles, con Groq o con reglas locales."""
import http.client
import json
import os
import re
import unicodedata
from contextlib import closing
from pathlib import Path
from typing import Annotated

import typer

from .preparar import PERFIL_DESCRIPCIONES, contexto_equipo


MODELO = "openai/gpt-oss-120b"
ArchivoEnv = Annotated[Path | None, typer.Option(
    "--env-file", help="Archivo privado con GROQ_API_KEY. La variable de entorno tiene prioridad."
)]
SoloLocal = Annotated[bool, typer.Option("--local", help="Usa las recomendaciones locales sin conectar a Groq.")]

# Vocabulario de tareas que no aparece necesariamente en el nombre del perfil.
VOCABULARIO = {
    "android": ("android", "kotlin", "adb", "jetpack", "emulador", "movil", "moviles",
                "aplicaciones moviles", "apps moviles"),
    "video-adobe": ("adobe", "premiere", "after effects", "video adobe", "creative cloud"),
    "video-libre": ("video", "videos", "kdenlive", "montaje", "blender", "edicion audiovisual"),
    "diseno": ("diseno", "ilustracion", "dibujar", "photoshop", "inkscape", "gimp"),
    "streaming": ("streaming", "emitir", "twitch", "obs", "directos"),
    "gaming": ("gaming", "juegos", "jugar", "steam", "videojuegos"),
    "datos": ("datos", "estadistica", "jupyter", "pandas", "sql"),
    "ingenieria": ("ingenieria", "cad", "freecad", "matlab"),
    "teletrabajo": ("teletrabajo", "videollamadas", "reuniones", "zoom", "teams"),
    "estudios": ("estudios", "estudiar", "apuntes", "clases", "universidad"),
    "desarrollo": ("desarrollo", "desarrollar", "programar", "programacion", "codigo", "git", "python"),
    "ofimatica": ("ofimatica", "office", "oficina", "hojas de calculo", "excel", "documentos"),
    "casa": ("casa", "hogar", "navegar", "familia"),
}


class ErrorGroq(Exception):
    """Mensaje breve que se puede mostrar sin incluir datos de la petición."""


def _clave(archivo: Path | None) -> str:
    valor = os.environ.get("GROQ_API_KEY", "").strip()
    if not valor and archivo is not None:
        try:
            for linea in archivo.expanduser().read_text(encoding="utf-8-sig").splitlines():
                nombre, separador, contenido = linea.partition("=")
                if separador and nombre.strip() == "GROQ_API_KEY":
                    valor = contenido.strip().strip("\"'")
                    break
        except (OSError, UnicodeError):
            raise ErrorGroq("No se pudo leer el archivo indicado en --env-file.") from None
    if not valor:
        raise ErrorGroq("Configura GROQ_API_KEY en tu sesión o pasa un archivo privado con --env-file.")
    if not valor.isascii() or not valor.isprintable() or any(c.isspace() for c in valor):
        raise ErrorGroq("Revisa el formato de la clave GROQ_API_KEY.")
    return valor


def _consultar(archivo: Path | None, instrucciones: str, datos: dict) -> dict:
    clave = _clave(archivo)
    if clave in datos.get("objetivo", ""):
        raise ErrorGroq("El objetivo incluye la clave y se ha procesado en el equipo.")
    cuerpo = {
        "model": MODELO, "reasoning_effort": "low", "max_completion_tokens": 1200,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": "Responde en español y en JSON. " + instrucciones},
            {"role": "user", "content": json.dumps(datos, ensure_ascii=False)},
        ],
    }
    try:
        # El destino es fijo. HTTPSConnection no reenvía cabeceras en redirecciones.
        with closing(http.client.HTTPSConnection("api.groq.com", timeout=20)) as conexion:
            conexion.request("POST", "/openai/v1/chat/completions", json.dumps(cuerpo).encode(),
                             {"Authorization": f"Bearer {clave}", "Content-Type": "application/json"})
            with closing(conexion.getresponse()) as respuesta:
                if respuesta.status in (401, 403):
                    raise ErrorGroq("Groq rechazó la clave o el acceso al modelo.")
                if respuesta.status == 429:
                    raise ErrorGroq("Groq alcanzó un límite de solicitudes. Vuelve a intentarlo más tarde.")
                if respuesta.status != 200:
                    raise ErrorGroq(f"Groq devolvió el estado HTTP {respuesta.status}.")
                contenido = respuesta.read(65_537)
        if len(contenido) > 65_536:
            raise ValueError
        opcion = json.loads(contenido)["choices"][0]
        if opcion["finish_reason"] != "stop":
            raise ValueError
        resultado = json.loads(opcion["message"]["content"])
        if not isinstance(resultado, dict):
            raise ValueError
        return resultado
    except (ValueError, IndexError, KeyError, TypeError, RecursionError):
        raise ErrorGroq("Groq devolvió una respuesta incompleta o con formato inesperado.") from None
    except (OSError, http.client.HTTPException):
        raise ErrorGroq("Falló la conexión con Groq. Comprueba la red y vuelve a intentarlo.") from None


def _texto(valor: object, limite: int = 600) -> str:
    if not isinstance(valor, str):
        return ""
    # Quita secuencias ANSI y caracteres de control antes de presentar texto.
    limpio = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", valor)
    limpio = "".join(c if c.isprintable() else " " for c in limpio)
    return " ".join(limpio.split())[:limite]


def _perfil_local(objetivo: str) -> tuple[str, str]:
    palabras = unicodedata.normalize("NFKD", objetivo.casefold())
    palabras = "".join(c for c in palabras if not unicodedata.combining(c))
    mejor, puntuacion = "casa", 0
    for perfil, vocabulario in VOCABULARIO.items():
        puntos = sum(1 for termino in vocabulario if re.search(r"\b" + termino + r"\b", palabras))
        if perfil in PERFIL_DESCRIPCIONES and puntos > puntuacion:
            mejor, puntuacion = perfil, puntos
    motivo = PERFIL_DESCRIPCIONES[mejor]
    if not puntuacion:
        motivo = f"Para un uso general, empieza por este perfil. {motivo}"
    return mejor, motivo


def _contiene_datos_privados(objetivo: str) -> bool:
    # Si el objetivo parece contener una ruta, una credencial o un correo,
    # la recomendación se calcula localmente sin enviar fragmentos del texto.
    return bool(re.search(
        r"[/\\@=]|\b(?:gsk_|sk-|gh[pousr]_|github_pat_|AKIA|eyJ)|"
        r"\b(?:token|contraseña|password|api[_ -]?key|clave)\b|[\w-]{32,}",
        objetivo, re.IGNORECASE,
    ))


def asesorar(objetivo: Annotated[str, typer.Argument(help="Describe qué quieres hacer con el equipo.")],
             local: SoloLocal = False, env_file: ArchivoEnv = None):
    """Elige un perfil según tu objetivo y explica el motivo."""
    if not _texto(objetivo) or len(objetivo) > 1200:
        raise typer.BadParameter("Escribe un objetivo de entre 1 y 1200 caracteres.")
    perfil, motivo = _perfil_local(objetivo)
    fuente = "Recomendación local"
    if not local:
        try:
            if _contiene_datos_privados(objetivo):
                raise ErrorGroq("El objetivo parece incluir datos privados y se ha procesado en el equipo.")
            resultado = _consultar(env_file,
                "Elige un solo ID de perfiles para el objetivo del usuario. Devuelve las claves "
                "perfil y motivo. Redacta una frase breve sobre el encaje, sin órdenes de terminal.",
                {"objetivo": _texto(objetivo, 1200), "perfiles": PERFIL_DESCRIPCIONES, "equipo": contexto_equipo()})
            elegido, razon = resultado.get("perfil"), _texto(resultado.get("motivo"))
            if not isinstance(elegido, str) or elegido not in PERFIL_DESCRIPCIONES or not razon:
                raise ErrorGroq("La respuesta de Groq no identifica un perfil válido con motivo.")
            perfil, motivo, fuente = elegido, razon, "Recomendación de Groq"
        except ErrorGroq as error:
            typer.echo(str(error), err=True)
    typer.echo(f"{fuente} · {perfil}\n{motivo}\nPara ver el plan, ejecuta sparktune preparar {perfil} --simular")


def _explicacion_local(perfil: str, equipo: dict) -> list[str]:
    orientacion = [PERFIL_DESCRIPCIONES[perfil]]
    ram = equipo.get("ram_gib")
    if ram is not None:
        consejo = "Prueba tu carga habitual y observa el uso de memoria."
        if ram <= 8:
            consejo = {
                "android": "Prueba la aplicación en un teléfono físico para liberar la RAM que consumiría el emulador.",
                "video-adobe": "Edita con copias de baja resolución y usa los originales al exportar.",
                "video-libre": "Activa los clips proxy en el editor para trabajar con copias de menor resolución.",
                "datos": "Prueba primero una muestra del conjunto de datos y comprueba cuánto ocupa al cargarla.",
                "gaming": "Cierra el navegador y los programas en segundo plano antes de abrir el juego.",
            }.get(perfil, "Cierra otras aplicaciones pesadas antes de empezar.")
        orientacion.append(f"El equipo tiene {ram:g} GiB de RAM instalada. {consejo}")
    libre = equipo.get("disco_libre_gib")
    if libre is not None:
        orientacion.append(f"Quedan {libre:g} GiB libres en el disco. Revisa el tamaño de las aplicaciones y tus proyectos antes de instalar.")
    if equipo.get("enchufado") is False:
        orientacion.append("El equipo funciona con batería. Conéctalo a la corriente durante instalaciones largas.")
    if len(orientacion) == 1:
        orientacion.append("Revisa la lista de aplicaciones de la vista previa y el espacio que requieren en tu equipo.")
    return orientacion


def explicar(perfil: Annotated[str, typer.Argument(help="Identificador que aparece en sparktune perfiles.")],
             local: SoloLocal = False, env_file: ArchivoEnv = None):
    """Interpreta los recursos del equipo para trabajar con un perfil elegido."""
    if perfil not in PERFIL_DESCRIPCIONES:
        raise typer.BadParameter("Perfil desconocido. Consulta sparktune perfiles.")
    equipo = contexto_equipo()
    lineas = _explicacion_local(perfil, equipo)
    fuente = "Explicación local"
    if not local:
        try:
            resultado = _consultar(env_file,
                "Interpreta los recursos medidos para el perfil elegido. Devuelve prioridad y primer_paso, "
                "una frase concreta por campo. Evita inventar mediciones o proponer órdenes de terminal.",
                {"perfil": perfil, "actividad": PERFIL_DESCRIPCIONES[perfil], "equipo": equipo})
            prioridad, paso = _texto(resultado.get("prioridad")), _texto(resultado.get("primer_paso"))
            if not prioridad or not paso:
                raise ErrorGroq("Groq devolvió una explicación incompleta.")
            lineas = [f"Prioridad: {prioridad}", f"Primer paso: {paso}"]
            fuente = "Explicación de Groq"
        except ErrorGroq as error:
            typer.echo(str(error), err=True)
    typer.echo(f"{fuente} · {perfil}")
    for linea in lineas:
        typer.echo(linea)
    typer.echo(f"Para ver el plan, ejecuta sparktune preparar {perfil} --simular")


def comprobar_ia(env_file: ArchivoEnv = None):
    """Verifica con una consulta mínima que Groq puede responder con el modelo."""
    try:
        resultado = _consultar(env_file, 'Devuelve {"estado":"ok"}.', {"peticion": "comprobar conexión"})
        if resultado.get("estado") != "ok":
            raise ErrorGroq("Groq devolvió una verificación inesperada.")
    except ErrorGroq as error:
        typer.echo(str(error), err=True)
        raise typer.Exit(1) from None
    typer.echo(f"Conexión verificada con Groq · {MODELO}")


def registrar(app: typer.Typer):
    app.command()(asesorar)
    app.command()(explicar)
    app.command("comprobar-ia")(comprobar_ia)
