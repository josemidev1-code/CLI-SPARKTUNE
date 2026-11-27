import io
import json
from pathlib import Path

import pytest
import typer
from typer.testing import CliRunner


@pytest.fixture
def cli(monkeypatch, tmp_path):
    from sparktune import ia, proveedores

    monkeypatch.chdir(tmp_path)
    monkeypatch.delenv("GROQ_API_KEY", raising=False)
    monkeypatch.setattr(ia, "contexto_equipo", lambda: {
        "sistema": "Windows", "arquitectura": "AMD64", "ram_gib": 8.0,
        "nucleos_logicos": 4, "disco_libre_gib": 40.0, "con_bateria": True,
        "enchufado": False,
    })

    from sparktune import preparar
    monkeypatch.setattr(preparar, "_transparencia_activa", lambda: False)

    def red_inesperada(*args, **kwargs):
        pytest.fail("Se intentó contactar con Groq en modo local")

    monkeypatch.setattr(proveedores.http.client, "HTTPSConnection", red_inesperada)
    app = typer.Typer()
    ia.registrar(app)
    return lambda *args: CliRunner().invoke(app, list(args))


def simular_groq(monkeypatch, contenido=None, estado=200):
    from sparktune import ia, proveedores

    peticiones = []

    class Conexion:
        def __init__(self, host, timeout):
            assert host == "api.groq.com" and 0 < timeout <= 30

        def request(self, metodo, ruta, body, headers):
            assert (metodo, ruta) == ("POST", "/openai/v1/chat/completions")
            peticiones.append((json.loads(body), headers))

        def getresponse(self):
            if estado == 0:
                raise TimeoutError
            respuesta = {"choices": [{"finish_reason": "stop", "message": {
                "content": json.dumps(contenido)
            }}]}
            res = io.BytesIO(json.dumps(respuesta).encode())
            res.status = estado
            return res

        def close(self):
            pass

    monkeypatch.setattr(proveedores.http.client, "HTTPSConnection", Conexion)
    return peticiones


def test_asesor_local_elige_perfil_sin_leer_env_implicito(cli):
    Path(".env").write_text("GROQ_API_KEY=clave-ignorada", encoding="utf-8")
    salida = cli("asesorar", "Quiero programar aplicaciones Android")
    assert salida.exit_code == 0, salida.output
    assert "preparar android --simular" in salida.output
    assert "local" in salida.output.lower()


def test_explicacion_local_interpreta_equipo(cli, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "clave-falsa")
    salida = cli("explicar", "video-adobe", "--local")
    assert salida.exit_code == 0, salida.output
    assert "8" in salida.output and "RAM" in salida.output
    assert "batería" in salida.output and "baja resolución" in salida.output


def test_perfil_invalido_no_hace_consulta(cli):
    salida = cli("explicar", "perfil-inventado")
    assert salida.exit_code != 0 and "perfiles" in salida.output


def test_asesor_groq_procesa_solo_perfil_del_catalogo(cli, monkeypatch, tmp_path):
    archivo = tmp_path / "privado.env"
    archivo.write_text('GROQ_API_KEY="gsk_ejemplo"\n', encoding="utf-8")
    peticiones = simular_groq(monkeypatch, {"perfil": "desarrollo", "motivo": "Encaja con Git\x1b[2J y tu editor."})
    salida = cli("asesorar", "Quiero gestionar versiones", "--env-file", str(archivo))
    assert salida.exit_code == 0, salida.output
    assert "preparar desarrollo --simular" in salida.output
    assert "Encaja con Git" in salida.output and "\x1b" not in salida.output
    cuerpo, cabeceras = peticiones[0]
    assert cuerpo["model"] == "openai/gpt-oss-120b"
    assert cabeceras["Authorization"] == "Bearer gsk_ejemplo"
    assert "gsk_ejemplo" not in str(cuerpo) and str(tmp_path) not in str(cuerpo)


@pytest.mark.parametrize("respuesta", [{"perfil": "falso", "motivo": "Inválido"}, {"perfil": "android"}])
def test_datos_invalidos_del_modelo_recuperan_recomendacion_local(cli, monkeypatch, respuesta):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_ejemplo")
    simular_groq(monkeypatch, respuesta)
    salida = cli("asesorar", "Desarrollar en Kotlin")
    assert salida.exit_code == 0 and "preparar android --simular" in salida.output
    assert "local" in salida.output.lower() and "Inválido" not in salida.output


@pytest.mark.parametrize("objetivo", [r"programar en C:\Users\ana\privado", "programar con gsk_secreta"])
def test_objetivos_con_datos_privados_se_tratan_localmente(cli, monkeypatch, objetivo):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_ejemplo")
    salida = cli("asesorar", objetivo)
    assert salida.exit_code == 0 and "local" in salida.output.lower()
    assert objetivo not in salida.output


def test_explicar_groq_presenta_prioridad_y_primer_paso(cli, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_ejemplo")
    peticiones = simular_groq(monkeypatch, {"prioridad": "Reserva RAM para el emulador.", "primer_paso": "Cierra pestañas antes de abrirlo."})
    salida = cli("explicar", "android")
    assert salida.exit_code == 0 and "Reserva RAM" in salida.output and "Cierra pestañas" in salida.output
    assert "ram_gib" in str(peticiones[0][0])


@pytest.mark.parametrize("estado, indicio", [(401, "clave"), (429, "límite"), (0, "conexión")])
def test_comprobar_distingue_fallos_sin_revelar_clave(cli, monkeypatch, estado, indicio):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_ejemplo")
    simular_groq(monkeypatch, estado=estado)
    salida = cli("comprobar-ia")
    assert salida.exit_code == 1 and indicio in salida.output.lower()
    assert "gsk_ejemplo" not in salida.output


def test_comprobar_verifica_el_modelo(cli, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_ejemplo")
    simular_groq(monkeypatch, {"estado": "ok"})
    salida = cli("comprobar-ia")
    assert salida.exit_code == 0 and "openai/gpt-oss-120b" in salida.output


def test_selecciona_edicion_adobe_frente_a_video_generico(cli):
    salida = cli("asesorar", "Editar vídeos con Adobe", "--local")
    assert "preparar video-adobe --simular" in salida.output


def test_orientacion_android_con_poca_ram_es_especifica(cli):
    salida = cli("explicar", "android", "--local")
    assert "emulador" in salida.output and "teléfono" in salida.output


def test_objetivo_no_se_recorta_a_mitad(cli, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_ejemplo")
    peticiones = simular_groq(monkeypatch, {"perfil": "android", "motivo": "Encaja bien."})
    final = "Me interesa Android."
    objetivo = "Quiero probar entornos de trabajo. " * 20 + final
    salida = cli("asesorar", objetivo)
    assert salida.exit_code == 0
    assert final in str(peticiones[0][0])


def test_consulta_no_envia_clave_literal_fuera_de_cabecera(cli, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "privada1234")
    salida = cli("asesorar", "Programar con privada1234")
    assert salida.exit_code == 0 and "local" in salida.output.lower()


def test_desarrollo_movil_sin_mencionar_android(cli):
    salida = cli("asesorar", "Quiero programar aplicaciones móviles", "--local")
    assert salida.exit_code == 0 and "preparar android --simular" in salida.output


def test_propuesta_dice_que_cambia_por_que_y_como_revertir(cli):
    salida = cli("asesorar", "Quiero programar en Kotlin para Android", "--local").output
    assert "Por qué encaja con tu uso: Mencionas «android», «kotlin»" in salida
    assert "Con tu equipo: Windows AMD64 · 8 GiB de RAM" in salida
    assert "Instalar Git.Git con WinGet" in salida
    assert "Cómo revertirlo: winget uninstall --id Git.Git --exact" in salida
    assert "Restaurar sistema" in salida and "Todavía no se ha aplicado nada" in salida


def test_el_modelo_no_decide_cambios_ni_reversion(cli, monkeypatch):
    # El modelo solo aporta el motivo: paquetes y reversión salen del catálogo de SparkTune.
    monkeypatch.setenv("GROQ_API_KEY", "gsk_ejemplo")
    simular_groq(monkeypatch, {"perfil": "ofimatica", "motivo": "Encaja con tus documentos.",
                               "paquetes": ["Malware.Falso"], "deshacer": "format C:"})
    salida = cli("asesorar", "Escribir documentos").output
    assert "Recomendación de Groq · ofimatica" in salida and "Encaja con tus documentos." in salida
    assert "Malware.Falso" not in salida and "format C:" not in salida
    revertir = [linea.strip() for linea in salida.splitlines() if "Cómo revertirlo" in linea]
    assert revertir == ["Cómo revertirlo: winget uninstall --id TheDocumentFoundation.LibreOffice --exact",
                        "Cómo revertirlo: winget uninstall --id Mozilla.Firefox --exact"]
