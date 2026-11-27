"""Proveedores de IA. La interfaz elige uno y recurre al local si el remoto falla."""

import http.client
import json
import os
import re
import unicodedata
from abc import ABC, abstractmethod
from contextlib import closing
from pathlib import Path

from .errores import ErrorIA

MODELO = "openai/gpt-oss-120b"

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


def texto_seguro(valor: object, limite: int = 600) -> str:
    """Texto del modelo listo para la terminal: sin secuencias ANSI ni caracteres de control."""
    if not isinstance(valor, str):
        return ""
    limpio = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", valor)
    limpio = "".join(c if c.isprintable() else " " for c in limpio)
    return " ".join(limpio.split())[:limite]


def contiene_datos_privados(objetivo: str) -> bool:
    """Rutas, credenciales o correos: la recomendación se calcula sin enviar el texto."""
    # Sin tildes ni mayúsculas, para reconocer también «contrasena» o «CONTRASEÑA».
    texto = "".join(c for c in unicodedata.normalize("NFKD", objetivo.casefold()) if not unicodedata.combining(c))
    return bool(re.search(
        r"[/\\@=]|\b(?:gsk_|sk-|gh[pousr]_|github_pat_|akia|eyj)|"
        r"\b(?:token|contrasena|pass(?:wd|word)?|pwd|pin|api[_ -]?key|clave)\b|[\w-]{32,}",
        texto,
    ))


class ProveedorIA(ABC):
    """Lo que la interfaz necesita de cualquier asesor, remoto o local."""

    nombre: str

    def __init__(self, perfiles: dict[str, str]):
        self._perfiles = perfiles

    @abstractmethod
    def recomendar(self, objetivo: str, equipo: dict) -> tuple[str, str]:
        """Devuelve (perfil, motivo). El perfil siempre es uno del catálogo."""

    @abstractmethod
    def explicar(self, perfil: str, equipo: dict) -> list[str]:
        """Líneas que relacionan el perfil con los recursos medidos del equipo."""


class ProveedorLocal(ProveedorIA):
    """Reglas sin red. Es la alternativa cuando Groq no está disponible."""

    nombre = "local"

    def recomendar(self, objetivo, equipo):
        palabras = unicodedata.normalize("NFKD", objetivo.casefold())
        palabras = "".join(c for c in palabras if not unicodedata.combining(c))
        mejor, coincidencias = "casa", []
        for perfil, vocabulario in VOCABULARIO.items():
            encontrados = [termino for termino in vocabulario if re.search(r"\b" + termino + r"\b", palabras)]
            if perfil in self._perfiles and len(encontrados) > len(coincidencias):
                mejor, coincidencias = perfil, encontrados
        descripcion = self._perfiles[mejor]
        if not coincidencias:
            return mejor, f"No he reconocido una actividad concreta; para un uso general, empieza por este perfil. {descripcion}"
        citadas = ", ".join(f"«{termino}»" for termino in coincidencias)
        return mejor, f"Mencionas {citadas}, y este perfil está pensado para eso: {descripcion}."

    def explicar(self, perfil, equipo):
        orientacion = [self._perfiles[perfil]]
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
            orientacion.append(f"Quedan {libre:g} GiB libres en el disco. Revisa el tamaño de las aplicaciones "
                               "y tus proyectos antes de instalar.")
        if equipo.get("enchufado") is False:
            orientacion.append("El equipo funciona con batería. Conéctalo a la corriente durante instalaciones largas.")
        if len(orientacion) == 1:
            orientacion.append("Revisa la lista de aplicaciones de la vista previa y el espacio que requieren en tu equipo.")
        return orientacion


class ProveedorGroq(ProveedorIA):
    """Groq con un modelo fijo. Solo devuelve datos; nunca ejecuta órdenes del modelo."""

    nombre = "Groq"

    def __init__(self, perfiles: dict[str, str], clave: str):
        super().__init__(perfiles)
        self.__clave = clave

    @staticmethod
    def desde_entorno(perfiles: dict[str, str], archivo: Path | None = None) -> "ProveedorGroq":
        """Fábrica: lee GROQ_API_KEY del entorno o, si no está, del archivo de --env-file."""
        valor = os.environ.get("GROQ_API_KEY", "").strip()
        if not valor and archivo is not None:
            try:
                for linea in archivo.expanduser().read_text(encoding="utf-8-sig").splitlines():
                    nombre, separador, contenido = linea.partition("=")
                    if separador and nombre.strip() == "GROQ_API_KEY":
                        valor = contenido.strip().strip("\"'")
                        break
            except (OSError, UnicodeError):
                raise ErrorIA("No se pudo leer el archivo indicado en --env-file.") from None
        if not valor:
            raise ErrorIA("Configura GROQ_API_KEY en tu sesión o pasa un archivo privado con --env-file.")
        if not valor.isascii() or not valor.isprintable() or any(c.isspace() for c in valor):
            raise ErrorIA("Revisa el formato de la clave GROQ_API_KEY.")
        return ProveedorGroq(perfiles, valor)

    def _consultar(self, instrucciones: str, datos: dict) -> dict:
        if self.__clave in datos.get("objetivo", ""):
            raise ErrorIA("El objetivo incluye la clave y se ha procesado en el equipo.")
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
                                 {"Authorization": f"Bearer {self.__clave}", "Content-Type": "application/json"})
                with closing(conexion.getresponse()) as respuesta:
                    if respuesta.status in (401, 403):
                        raise ErrorIA("Groq rechazó la clave o el acceso al modelo.")
                    if respuesta.status == 429:
                        raise ErrorIA("Groq alcanzó un límite de solicitudes. Vuelve a intentarlo más tarde.")
                    if respuesta.status != 200:
                        raise ErrorIA(f"Groq devolvió el estado HTTP {respuesta.status}.")
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
            raise ErrorIA("Groq devolvió una respuesta incompleta o con formato inesperado.") from None
        except (OSError, http.client.HTTPException):
            raise ErrorIA("Falló la conexión con Groq. Comprueba la red y vuelve a intentarlo.") from None

    def recomendar(self, objetivo, equipo):
        if contiene_datos_privados(objetivo):
            raise ErrorIA("El objetivo parece incluir datos privados y se ha procesado en el equipo.")
        resultado = self._consultar(
            "Elige un solo ID de perfiles para el objetivo del usuario. Devuelve las claves "
            "perfil y motivo. Redacta una frase breve sobre el encaje, sin órdenes de terminal.",
            {"objetivo": texto_seguro(objetivo, 1200), "perfiles": self._perfiles, "equipo": equipo})
        elegido, motivo = resultado.get("perfil"), texto_seguro(resultado.get("motivo"))
        # Solo se acepta un perfil del catálogo: el modelo no puede inventar instalaciones.
        if not isinstance(elegido, str) or elegido not in self._perfiles or not motivo:
            raise ErrorIA("La respuesta de Groq no identifica un perfil válido con motivo.")
        return elegido, motivo

    def explicar(self, perfil, equipo):
        resultado = self._consultar(
            "Interpreta los recursos medidos para el perfil elegido. Devuelve prioridad y primer_paso, "
            "una frase concreta por campo. Evita inventar mediciones o proponer órdenes de terminal.",
            {"perfil": perfil, "actividad": self._perfiles[perfil], "equipo": equipo})
        prioridad, paso = texto_seguro(resultado.get("prioridad")), texto_seguro(resultado.get("primer_paso"))
        if not prioridad or not paso:
            raise ErrorIA("Groq devolvió una explicación incompleta.")
        return [f"Prioridad: {prioridad}", f"Primer paso: {paso}"]

    def comprobar(self) -> None:
        """Consulta mínima para verificar la clave y el modelo."""
        if self._consultar('Devuelve {"estado":"ok"}.', {"peticion": "comprobar conexión"}).get("estado") != "ok":
            raise ErrorIA("Groq devolvió una verificación inesperada.")
