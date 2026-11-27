import json
import subprocess
from unittest.mock import Mock

import pytest
import typer
from typer.testing import CliRunner

from sparktune import preparar as p


@pytest.fixture
def invocar(monkeypatch):
    app = typer.Typer()
    p.registrar(app)
    equipo = dict(sistema="Windows", arquitectura="AMD64", nucleos_logicos=8,
                  ram_gib=16, disco_libre_gib=120, con_bateria=False, enchufado=None)
    monkeypatch.setattr(p, "contexto_equipo", lambda: equipo)
    monkeypatch.setattr(p, "_winget", lambda: "winget.exe")
    monkeypatch.setattr(p, "_transparencia_activa", lambda: False)

    def ejecutar(*args, respuestas=""):
        return CliRunner().invoke(app, list(args), input=respuestas)

    return ejecutar, equipo


def test_catalogo_y_perfil_desconocido(invocar):
    ejecutar, _ = invocar
    listado = ejecutar("perfiles")
    assert listado.exit_code == 0
    assert all(nombre in listado.output for nombre in ("android", "video-adobe", "ofimatica"))
    assert ejecutar("preparar", "git;whoami").exit_code != 0


@pytest.mark.parametrize(("sistema", "opciones"), [
    ("Darwin", []), ("Linux", []), ("Windows", ["--simular"]),
])
def test_plan_sin_cambios(monkeypatch, invocar, sistema, opciones):
    ejecutar, equipo = invocar
    equipo["sistema"] = sistema
    monkeypatch.setattr(p.subprocess, "run", lambda *a, **kw: pytest.fail("subproceso inesperado"))
    resultado = ejecutar("preparar", "video-adobe", *opciones)
    assert resultado.exit_code == 0
    assert all(s in resultado.output for s in ("Creative Cloud", "licencia", "Premiere", "After Effects"))


def test_plan_android_adaptativo(invocar):
    ejecutar, equipo = invocar
    equipo.update(ram_gib=8, disco_libre_gib=12)
    ligero = ejecutar("preparar", "android", "--simular").output
    assert "Google.AndroidStudio" in ligero and "teléfono" in ligero
    equipo.update(ram_gib=32, disco_libre_gib=96)
    holgado = ejecutar("preparar", "android", "--simular").output
    assert "Device Manager" in holgado and "virtualización" in holgado
    equipo.update(arquitectura="ARM64")
    assert "Google.AndroidStudio" not in ejecutar("preparar", "android", "--simular").output


def test_rechazar_todo_no_crea_punto(monkeypatch, invocar):
    ejecutar, _ = invocar
    monkeypatch.setattr(p.subprocess, "run", lambda *a, **kw: pytest.fail("subproceso inesperado"))
    resultado = ejecutar("preparar", "ofimatica", respuestas="\n" * 5)
    assert resultado.exit_code == 0 and "Sin cambios" in resultado.output


def test_un_punto_para_cambios_aceptados(monkeypatch, invocar):
    ejecutar, _ = invocar
    eventos = []
    monkeypatch.setattr(p, "_crear_punto", lambda: eventos.append("punto") or "SparkTune-Test")
    def proceso(argumentos, **kw):
        eventos.append(argumentos)
        return subprocess.CompletedProcess(argumentos, 0)
    monkeypatch.setattr(p.subprocess, "run", proceso)
    resultado = ejecutar("preparar", "ofimatica", respuestas="y\ny\nn\n")
    assert resultado.exit_code == 0, resultado.output
    assert eventos[0] == "punto"
    assert len(eventos) == 3
    for llamada, paquete in zip(eventos[1:], ["TheDocumentFoundation.LibreOffice", "Mozilla.Firefox"]):
        assert llamada[:2] == ["winget.exe", "install"]
        assert llamada[llamada.index("--id") + 1] == paquete
        assert llamada[llamada.index("--source") + 1] == "winget"
        assert "--exact" in llamada and "--no-upgrade" in llamada


def test_fallo_de_proteccion_impide_instalar(monkeypatch, invocar):
    ejecutar, _ = invocar
    monkeypatch.setattr(p, "_crear_punto", Mock(side_effect=RuntimeError("protección inactiva")))
    monkeypatch.setattr(p.subprocess, "run", lambda *a, **kw: pytest.fail("instalación inesperada"))
    resultado = ejecutar("preparar", "ofimatica", respuestas="y\n")
    assert resultado.exit_code == 1 and "protección inactiva" in resultado.output


@pytest.mark.parametrize("puntos", [
    [{"SequenceNumber": 17, "Description": "SparkTune-identificador"}],
    [{"SequenceNumber": 20, "Description": "Windows Update"}],
    [{"SequenceNumber": 21, "Description": "SparkTune-identificador"}],
])
def test_verificar_secuencia_y_descripcion(monkeypatch, puntos):
    previo = [{"SequenceNumber": 17, "Description": "antiguo"}]
    monkeypatch.setattr(p, "uuid4", lambda: "identificador")
    consultas = iter([previo, puntos])
    monkeypatch.setattr(p, "_puntos", lambda: next(consultas, puntos))
    monkeypatch.setattr(p, "_powershell", lambda script: "")
    monkeypatch.setattr(p.time, "sleep", lambda s: None)
    if puntos[0]["SequenceNumber"] == 21:
        assert p._crear_punto() == "SparkTune-identificador"
    else:
        with pytest.raises(RuntimeError, match="verificar"):
            p._crear_punto()


def test_error_instalando_interrumpe_lote(monkeypatch, invocar):
    ejecutar, _ = invocar
    monkeypatch.setattr(p, "_crear_punto", lambda: "SparkTune-Test")
    proceso = Mock(return_value=subprocess.CompletedProcess([], 7))
    monkeypatch.setattr(p.subprocess, "run", proceso)
    resultado = ejecutar("preparar", "ofimatica", respuestas="y\ny\ny\n")
    assert resultado.exit_code == 1 and "LibreOffice" in resultado.output
    assert proceso.call_count == 1


def test_ajuste_condicional_tambien_necesita_punto(monkeypatch, invocar):
    ejecutar, equipo = invocar
    equipo.update(con_bateria=True, enchufado=False)
    monkeypatch.setattr(p, "_transparencia_activa", lambda: True)
    eventos = []
    monkeypatch.setattr(p, "_crear_punto", lambda: eventos.append("punto") or "SparkTune-Test")
    monkeypatch.setattr(p, "_desactivar_transparencia", lambda: eventos.append("transparencia"))
    resultado = ejecutar("preparar", "ofimatica", respuestas="n\nn\ny\n")
    assert resultado.exit_code == 0
    assert eventos == ["punto", "transparencia"]
    assert "Personalización" in resultado.output


def test_contexto_no_incluye_datos_personales():
    contexto = p.contexto_equipo()
    assert set(contexto) == {"sistema", "arquitectura", "nucleos_logicos", "ram_gib",
                             "disco_libre_gib", "con_bateria", "enchufado"}
    assert json.loads(json.dumps(contexto)) == contexto


def test_fallo_a_medias_explica_como_revertir_lo_aplicado(monkeypatch, invocar):
    ejecutar, _ = invocar
    monkeypatch.setattr(p, "_crear_punto", lambda: "SparkTune-Test")
    codigos = iter([0, 7])
    monkeypatch.setattr(p.subprocess, "run", lambda *a, **kw: subprocess.CompletedProcess([], next(codigos)))
    resultado = ejecutar("preparar", "ofimatica", respuestas="s\ns\n")
    assert resultado.exit_code == 1
    despues = resultado.output.split("Preparación detenida")[1]
    assert "winget uninstall --id TheDocumentFoundation.LibreOffice --exact" in despues
    assert "Mozilla.Firefox --exact" not in despues
    assert "Restaurar sistema" in despues


def test_aplicacion_ya_instalada_no_se_ofrece_deshacer(monkeypatch, invocar):
    # Si se siguiera la lista de reversión, se desinstalaría un programa que el usuario ya tenía.
    ejecutar, _ = invocar
    monkeypatch.setattr(p, "_crear_punto", lambda: "SparkTune-Test")

    def proceso(argumentos, **kw):
        ya_instalado = 0x8A150061 if argumentos[1] == "install" else 0  # «winget list» lo encuentra
        return subprocess.CompletedProcess(argumentos, ya_instalado)

    monkeypatch.setattr(p.subprocess, "run", proceso)
    resultado = ejecutar("preparar", "ofimatica", respuestas="n\ns\n")
    assert resultado.exit_code == 0, resultado.output
    despues = resultado.output.split("Mozilla.Firefox ya estaba instalado.")[1]
    assert "Mozilla.Firefox" not in despues
    assert "Cambios aplicados" not in despues


def test_estado_de_carga_desconocido_no_se_muestra_como_enchufado():
    # psutil devuelve power_plugged=None cuando Windows no informa del cargador.
    equipo = dict(sistema="Windows", arquitectura="AMD64", ram_gib=8, disco_libre_gib=40,
                  con_bateria=True, enchufado=None)
    resumen = p.resumen_equipo(equipo)
    assert "enchufado" not in resumen
    assert "con batería, estado de carga desconocido" in resumen


def test_vista_previa_incluye_como_deshacer(invocar):
    ejecutar, _ = invocar
    salida = ejecutar("preparar", "gaming", "--simular").output
    assert "Para deshacerlo: winget uninstall --id Valve.Steam --exact" in salida
    assert "Restaurar sistema" in salida and "Simulación terminada." in salida
