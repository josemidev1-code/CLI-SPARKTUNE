"""Preparación de entornos de trabajo con un catálogo cerrado para Windows."""

import json
import os
import platform
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated
from uuid import uuid4

import psutil
import typer

from .dialogo import confirmar


@dataclass(frozen=True)
class Perfil:
    descripcion: str
    paquetes: tuple[str, ...]
    guia: str


PERFILES = {
    "android": Perfil(
        "Desarrollo de aplicaciones móviles Android",
        ("Git.Git", "Google.AndroidStudio"),
        "Revisa los requisitos de tu versión en https://developer.android.com/studio/install",
    ),
    "desarrollo": Perfil(
        "Programación con un editor, Git y Python",
        ("Git.Git", "Microsoft.VisualStudioCode", "Python.Python.3.12"),
        "Abre tu proyecto en VS Code, crea el entorno con py -3.12 -m venv .venv "
        "y elige ese intérprete en el editor.",
    ),
    "video-adobe": Perfil(
        "Montaje con Adobe Premiere Pro y composición con After Effects",
        ("Adobe.CreativeCloud", "VideoLAN.VLC"),
        "Abre Creative Cloud e inicia sesión con tu Adobe ID. En Aplicaciones comprueba que "
        "tu licencia, suscripción o prueba incluye Premiere Pro y After Effects. Instala "
        "ambas desde allí. Para verificar el flujo, importa un clip en Premiere, crea una "
        "composición en After Effects y exporta diez segundos de prueba.",
    ),
    "video-libre": Perfil(
        "Montaje de vídeo y edición de sonido con herramientas libres",
        ("KDE.Kdenlive", "Audacity.Audacity", "VideoLAN.VLC"),
        "En Kdenlive ajusta el proyecto a la frecuencia del clip, añade una pista de audio "
        "y comprueba una exportación corta en VLC.",
    ),
    "ofimatica": Perfil(
        "Documentos, hojas de cálculo y trabajo en el navegador",
        ("TheDocumentFoundation.LibreOffice", "Mozilla.Firefox"),
        "En Writer crea un documento de prueba y expórtalo a PDF. Si compartes archivos "
        "de Office, abre una copia de un DOCX o XLSX y revisa fuentes, tablas y fórmulas.",
    ),
    "estudios": Perfil(
        "Apuntes y trabajos académicos",
        ("Obsidian.Obsidian", "TheDocumentFoundation.LibreOffice"),
        "Crea una bóveda local en Obsidian y enlaza una nota de clase con su asignatura. "
        "Utiliza Writer para entregar el trabajo en PDF.",
    ),
    "teletrabajo": Perfil(
        "Videollamadas y documentos compartidos",
        ("Zoom.Zoom", "TheDocumentFoundation.LibreOffice"),
        "Haz una llamada de prueba, comprueba micrófono y cámara y comparte una ventana "
        "antes de tu primera reunión.",
    ),
    "diseno": Perfil(
        "Diseño vectorial e ilustración",
        ("Inkscape.Inkscape", "GIMP.GIMP"),
        "Dibuja en Inkscape, guarda el original SVG y exporta una copia PNG para "
        "comprobar en GIMP las dimensiones finales.",
    ),
    "streaming": Perfil(
        "Emisiones y grabaciones de pantalla",
        ("OBSProject.OBSStudio", "Audacity.Audacity"),
        "En OBS ejecuta el asistente de configuración automática. Graba un minuto y "
        "revisa el audio y los fotogramas perdidos en Estadísticas.",
    ),
    "gaming": Perfil(
        "Juegos de PC y biblioteca de Steam",
        ("Valve.Steam",),
        "Ajusta la resolución dentro del juego y mide los FPS durante la misma escena "
        "antes y después de cambiar la calidad gráfica.",
    ),
    "datos": Perfil(
        "Análisis de datos con Python y bases de datos",
        ("Python.Python.3.12", "Microsoft.VisualStudioCode", "dbeaver.DBeaver"),
        "Crea un entorno virtual para el proyecto y abre una copia del conjunto de datos. "
        "Usa en DBeaver una conexión de solo lectura para explorar tus tablas.",
    ),
    "ingenieria": Perfil(
        "Dibujo técnico, CAD y cartografía",
        ("FreeCAD.FreeCAD", "OSGeo.QGIS"),
        "Define las unidades del proyecto en FreeCAD y el sistema de coordenadas en QGIS "
        "antes de importar planos o capas.",
    ),
    "casa": Perfil(
        "Navegación, archivos multimedia y tareas cotidianas",
        ("Mozilla.Firefox", "VideoLAN.VLC", "TheDocumentFoundation.LibreOffice"),
        "Abre un vídeo en VLC y un documento en Writer. Si compartes el ordenador, "
        "crea perfiles de navegador distintos para los miembros de la familia.",
    ),
}
PERFIL_DESCRIPCIONES: dict[str, str] = {id_: p.descripcion for id_, p in PERFILES.items()}

_GIB = 1024**3
_CLAVE_TEMA = r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
_RECUPERAR_TEMA = "Puedes reactivarlos en Configuración > Personalización > Colores."


def contexto_equipo() -> dict:
    """Datos agregados para preparar el plan, sin identificadores de usuario o máquina."""
    sistema = platform.system()
    unidad = os.environ.get("SystemDrive", "C:") + "\\" if sistema == "Windows" else "/"
    try:
        espacio = round(shutil.disk_usage(unidad).free / _GIB, 1)
    except OSError:
        espacio = None
    try:
        ram = round(psutil.virtual_memory().total / _GIB, 1)
    except (OSError, psutil.Error, NotImplementedError):
        ram = None
    try:
        bateria = psutil.sensors_battery()
        con_bateria = bateria is not None
        enchufado = bateria.power_plugged if bateria else None
    except (OSError, psutil.Error, NotImplementedError):
        con_bateria = enchufado = None
    return {
        "sistema": sistema, "arquitectura": platform.machine(), "nucleos_logicos": os.cpu_count(),
        "ram_gib": ram, "disco_libre_gib": espacio, "con_bateria": con_bateria, "enchufado": enchufado,
    }


def _plan(perfil: str, equipo: dict) -> tuple[list[str], list[str]]:
    paquetes = list(PERFILES[perfil].paquetes)
    pasos = [PERFILES[perfil].guia]
    ram, disco = equipo["ram_gib"], equipo["disco_libre_gib"]
    if perfil == "android":
        arch_incompatible = (equipo["sistema"] == "Windows"
                             and equipo["arquitectura"].lower() not in {"amd64", "x86_64"})
        if arch_incompatible or (ram is not None and ram < 8) or (disco is not None and disco < 8):
            paquetes.remove("Google.AndroidStudio")
            pasos.append("Para este equipo, utiliza Android Studio en la nube o un equipo de desarrollo "
                         "remoto. La instalación local para Windows requiere x64, 8 GiB de RAM y "
                         "espacio para el IDE y el SDK.")
        else:
            pasos.append("Abre Android Studio y completa el asistente. En SDK Manager instala "
                         "la plataforma de tu proyecto y Android SDK Platform-Tools.")
            if ram is not None and ram >= 16 and disco is not None and disco >= 16:
                pasos.append("Comprueba la virtualización en Administrador de tareas > Rendimiento "
                             "antes de crear un emulador en Device Manager. Inicia una app de prueba con Run.")
            else:
                pasos.append("Prueba la app en un teléfono Android por USB para ahorrar memoria y disco. "
                             "Activa la depuración USB, autoriza este ordenador y elige el teléfono en Run.")
    if perfil in {"video-adobe", "video-libre"}:
        if ram is None or ram < 32:
            pasos.append("Crea proxies de baja resolución para montar el vídeo y usa los originales "
                         "al exportar. Compara la fluidez en el mismo tramo de la línea de tiempo.")
        else:
            pasos.append("Prueba un tramo con el metraje original. Si pierde fotogramas, "
                         "activa proxies y repite el mismo tramo.")
        if perfil == "video-adobe":
            pasos.append("Comprueba CPU, GPU y versión de Windows en los requisitos de cada app "
                         "antes de activar una prueba. Selecciona para la caché de medios un SSD con espacio.")
    if disco is not None and disco < 20:
        pasos.append(f"Quedan {disco:g} GiB en la unidad del sistema. Revisa Almacenamiento antes de "
                     "descargar componentes y guarda medios o cachés en otra unidad si dispones de ella.")
    if equipo["enchufado"] is False:
        pasos.append("El equipo funciona con batería. Conéctalo a la corriente antes de compilar, "
                     "exportar vídeo o iniciar instalaciones largas.")
    return paquetes, pasos


@dataclass(frozen=True)
class Cambio:
    """Un cambio que SparkTune puede aplicar y la forma de deshacerlo."""

    descripcion: str
    deshacer: str


RESTAURAR = ("Para volver al estado anterior de una vez, abre Restaurar sistema (rstrui.exe) y elige el "
             "punto SparkTune. Windows quita los programas y controladores instalados después de ese "
             "punto y no toca tus documentos.")


def deshacer_paquete(paquete: str) -> str:
    if paquete == "Adobe.CreativeCloud":
        return ("Desinstala primero Premiere Pro y After Effects desde Creative Cloud y después "
                "ejecuta winget uninstall --id Adobe.CreativeCloud --exact.")
    return f"winget uninstall --id {paquete} --exact"


def sugerir_transparencia(equipo: dict) -> bool:
    """Con batería o con poca RAM se propone quitar la transparencia, si está activa."""
    ram = equipo["ram_gib"]
    optimizar = equipo["enchufado"] is False or (ram is not None and ram <= 8)
    return equipo["sistema"] == "Windows" and optimizar and _transparencia_activa()


def propuesta(perfil: str, equipo: dict) -> tuple[list[Cambio], list[str]]:
    """Cambios del perfil con su reversión y pasos adaptados al equipo, sin aplicar nada."""
    paquetes, pasos = _plan(perfil, equipo)
    cambios = [Cambio(f"Instalar {paquete} con WinGet", deshacer_paquete(paquete)) for paquete in paquetes]
    if sugerir_transparencia(equipo):
        cambios.append(Cambio("Desactivar los efectos de transparencia de esta cuenta", _RECUPERAR_TEMA))
    return cambios, pasos


def resumen_equipo(equipo: dict) -> str:
    ram, disco = equipo["ram_gib"], equipo["disco_libre_gib"]
    partes = [f"{equipo['sistema']} {equipo['arquitectura']}",
              f"{ram:g} GiB de RAM" if ram is not None else "RAM desconocida",
              f"{disco:g} GiB libres" if disco is not None else "espacio libre desconocido"]
    if equipo["con_bateria"]:
        # psutil devuelve None si Windows no informa del cargador: no se da por enchufado.
        carga = {True: "enchufado", False: "desenchufado"}.get(equipo["enchufado"], "estado de carga desconocido")
        partes.append(f"con batería, {carga}")
    elif equipo["con_bateria"] is False:
        partes.append("sin batería")
    return " · ".join(partes)


def _transparencia_activa() -> bool:
    try:
        import winreg
    except ImportError:  # Fuera de Windows no existe el registro.
        return False

    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _CLAVE_TEMA) as clave:
            valor, tipo = winreg.QueryValueEx(clave, "EnableTransparency")
            return tipo == winreg.REG_DWORD and valor == 1
    except OSError:
        return False


def _desactivar_transparencia() -> None:
    import winreg

    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _CLAVE_TEMA, 0,
                        winreg.KEY_READ | winreg.KEY_SET_VALUE) as clave:
        valor, tipo = winreg.QueryValueEx(clave, "EnableTransparency")
        if tipo != winreg.REG_DWORD or valor != 1:
            raise RuntimeError("La preferencia de transparencia cambió desde la vista previa.")
        winreg.SetValueEx(clave, "EnableTransparency", 0, winreg.REG_DWORD, 0)
        if winreg.QueryValueEx(clave, "EnableTransparency") != (0, winreg.REG_DWORD):
            raise RuntimeError("Windows no confirmó el ajuste de transparencia.")


def _winget() -> str | None:
    # La ruta del alias evita buscar ejecutables en la carpeta de trabajo.
    local = os.environ.get("LOCALAPPDATA")
    if local:
        alias = Path(local, "Microsoft", "WindowsApps", "winget.exe")
        if alias.exists():
            return str(alias)
    return None


def _powershell(script: str) -> str:
    exe = Path(os.environ["SystemRoot"], "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
    resultado = subprocess.run(
        [str(exe), "-NoLogo", "-NoProfile", "-NonInteractive", "-Command",
         "$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [Text.UTF8Encoding]::new(); " + script],
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180,
    )
    if resultado.returncode:
        raise RuntimeError(resultado.stderr.strip() or f"PowerShell terminó con código {resultado.returncode}.")
    return resultado.stdout.strip()


def _puntos() -> list[dict]:
    salida = _powershell(
        "$p = @(Get-ComputerRestorePoint | Select-Object SequenceNumber, Description); "
        "ConvertTo-Json -Compress -InputObject $p"
    )
    try:
        puntos = json.loads(salida)
        if isinstance(puntos, list) and all(
            isinstance(p, dict) and type(p.get("SequenceNumber")) is int and
            isinstance(p.get("Description"), str) for p in puntos
        ):
            return puntos
    except ValueError:
        pass
    raise RuntimeError("Windows devolvió una lista de puntos de restauración ilegible.")


def _crear_punto() -> str:
    nombre = f"SparkTune-{uuid4()}"
    anteriores = {p["SequenceNumber"] for p in _puntos()}
    _powershell(f"Checkpoint-Computer -Description '{nombre}' -RestorePointType MODIFY_SETTINGS")
    for intento in range(10):
        if intento:
            time.sleep(2)
        if any(p["Description"] == nombre and p["SequenceNumber"] not in anteriores for p in _puntos()):
            return nombre
    raise RuntimeError("No se pudo verificar un punto de restauración nuevo. Comprueba Protección del "
                       "sistema, los permisos de administrador y el límite de creación de Windows (24 horas).")


def _instalar(winget: str, paquete: str) -> bool:
    """True si SparkTune lo ha instalado; False si ya estaba instalado y no se ha tocado."""
    filtro = ["--id", paquete, "--exact", "--source", "winget"]
    codigo = subprocess.run([winget, "install", *filtro, "--no-upgrade"]).returncode
    if codigo == 0:
        return True
    # WinGet puede usar HRESULT de 32 bits con o sin signo al omitir un paquete instalado.
    if (codigo & 0xFFFFFFFF) in {0x8A15002B, 0x8A150061, 0x8A15010D}:
        if subprocess.run([winget, "list", *filtro, "--disable-interactivity"]).returncode == 0:
            typer.echo(f"{paquete} ya estaba instalado.")
            return False
    raise RuntimeError(f"WinGet terminó con código 0x{codigo & 0xFFFFFFFF:08X} para {paquete}.")


def perfiles() -> None:
    """Lista los perfiles de preparación disponibles."""
    for nombre, descripcion in PERFIL_DESCRIPCIONES.items():
        typer.echo(f"{nombre:<13} {descripcion}")


def preparar(
    perfil: Annotated[str, typer.Argument(help="Identificador mostrado por el comando perfiles.")],
    simular: Annotated[bool, typer.Option("--simular", help="Muestra el plan sin aplicar cambios.")] = False,
) -> None:
    """Prepara el equipo para un perfil y pide permiso para cada cambio."""
    if perfil not in PERFILES:
        raise typer.BadParameter("Perfil desconocido. Consulta los disponibles con sparktune perfiles.")
    equipo = contexto_equipo()
    paquetes, pasos = _plan(perfil, equipo)
    windows = equipo["sistema"] == "Windows"
    transparencia = sugerir_transparencia(equipo)
    typer.echo(f"Plan para {PERFIL_DESCRIPCIONES[perfil]} ({perfil})")
    typer.echo(f"Equipo observado: {resumen_equipo(equipo)}")
    typer.echo("Instalaciones disponibles en Windows (WinGet):")
    for paquete in paquetes:
        typer.echo(f"  • {paquete}\n    Para deshacerlo: {deshacer_paquete(paquete)}")
    if transparencia:
        typer.echo("Ajuste opcional para esta cuenta: desactivar los efectos de transparencia "
                   "del escritorio. " + _RECUPERAR_TEMA)
    typer.echo("Cada cambio se confirma por separado y antes del primero se crea un punto de restauración. "
               + RESTAURAR)
    typer.echo("Pasos para completar y comprobar tu entorno:")
    for paso in pasos:
        typer.echo(f"  • {paso}")
    if simular or not windows:
        typer.echo("Simulación terminada." if simular else "Vista previa. Las instalaciones requieren Windows.")
        return

    winget = _winget()
    if not winget:
        typer.echo("Falta WinGet. Instala o actualiza Instalador de aplicaciones desde Microsoft Store.",
                   err=True)
        raise typer.Exit(1)
    typer.echo("Al aceptar el primer cambio también autorizas crear un punto de restauración. "
               "Windows requiere una consola de administrador y Protección del sistema activa.")
    protegido = False
    aplicados: list[str] = []
    try:
        for paquete in paquetes:
            if not confirmar(f"¿Instalar {paquete}?"):
                continue
            if not protegido:
                typer.echo(f"Punto verificado: {_crear_punto()}")
                protegido = True
            # Solo se ofrece deshacer lo que SparkTune instaló; nunca un programa que ya existía.
            if _instalar(winget, paquete):
                aplicados.append(deshacer_paquete(paquete))
                typer.echo(f"Disponible: {paquete}")
        if transparencia and confirmar("¿Desactivar los efectos de transparencia para esta cuenta?"):
            if not protegido:
                typer.echo(f"Punto verificado: {_crear_punto()}")
                protegido = True
            _desactivar_transparencia()
            aplicados.append(_RECUPERAR_TEMA)
            typer.echo("Efectos de transparencia desactivados. " + _RECUPERAR_TEMA)
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        typer.echo(f"Preparación detenida. {exc}", err=True)
        _mostrar_reversion(aplicados, protegido)
        raise typer.Exit(1) from exc
    typer.echo("Preparación terminada." if protegido else "Sin cambios.")
    _mostrar_reversion(aplicados, protegido)


def _mostrar_reversion(aplicados: list[str], protegido: bool) -> None:
    """Tras un lote completo o a medias, dice cómo deshacer lo que sí se aplicó."""
    if aplicados:
        typer.echo("Cambios aplicados y cómo deshacerlos uno a uno:")
        for paso in aplicados:
            typer.echo(f"  • {paso}")
    if protegido:
        typer.echo(RESTAURAR)


def registrar(app: typer.Typer) -> None:
    app.command()(perfiles)
    app.command()(preparar)
