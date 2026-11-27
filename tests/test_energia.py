import json
import re

import pytest
from typer.testing import CliRunner

from sparktune import asistente, energia, preparar
from sparktune.cli import app

runner = CliRunner()
PORTATIL = {"sistema": "Windows", "arquitectura": "AMD64", "ram_gib": 16.0, "nucleos_logicos": 8,
            "disco_libre_gib": 200.0, "con_bateria": True, "enchufado": False}
ORIGINAL = "11111111-2222-3333-4444-555555555555"


@pytest.fixture
def windows(monkeypatch, tmp_path):
    """Windows simulado: powercfg guarda las órdenes y el estado va a una carpeta temporal."""
    monkeypatch.setenv("SPARKTUNE_HOME", str(tmp_path))
    monkeypatch.delenv("GROQ_API_KEY", raising=False)
    monkeypatch.setattr(energia, "_es_windows", lambda: True)
    monkeypatch.setattr(energia, "contexto_equipo", lambda: PORTATIL)
    monkeypatch.setattr(asistente.preparar, "contexto_equipo", lambda: PORTATIL)
    monkeypatch.setattr(energia, "procesos_pesados", lambda limite=5: [("Steam", 900)])
    ordenes = []

    def powercfg(*argumentos):
        ordenes.append(argumentos)
        return f"GUID del plan de energía: {ORIGINAL}  (Equilibrado)" if argumentos[0] == "/getactivescheme" else ""

    monkeypatch.setattr(energia, "_powercfg", powercfg)
    return ordenes


def test_recomendacion_local_segun_uso_y_equipo():
    assert energia.recomendar_local("Quiero ver series con batería", PORTATIL)[0] == "series-bateria"
    assert energia.recomendar_local("exprimir el portátil para jugar", PORTATIL)[0] == "maximo-portatil"
    sobremesa = {**PORTATIL, "con_bateria": False}
    assert energia.recomendar_local("ver series", sobremesa)[0] == "equilibrado"
    assert "series-bateria" not in energia.planes_para(sobremesa)


def test_simular_no_toca_el_equipo(windows):
    salida = runner.invoke(app, ["energia", "aplicar", "series-bateria", "--simular"])
    assert salida.exit_code == 0, salida.output
    assert "CPU máxima: enchufado 100% · batería 50%" in salida.output
    assert windows == []


def test_aplicar_cambiar_y_restaurar(windows, tmp_path):
    assert runner.invoke(app, ["energia", "aplicar", "ofimatica-bateria", "--si"]).exit_code == 0
    primero = json.loads((tmp_path / "energia.json").read_text(encoding="utf-8"))
    assert primero["original"] == ORIGINAL and primero["plan"] == "ofimatica-bateria"
    assert ("/setdcvalueindex", primero["sparktune"], "SUB_PROCESSOR", "PROCTHROTTLEMAX", "70") in windows
    assert windows[-1] == ("/setactive", primero["sparktune"])

    # Al cambiar de uso se conserva el plan original y se borra el anterior de SparkTune.
    windows.clear()
    assert runner.invoke(app, ["energia", "aplicar", "maximo-portatil", "--si"]).exit_code == 0
    segundo = json.loads((tmp_path / "energia.json").read_text(encoding="utf-8"))
    assert segundo["original"] == ORIGINAL and ("/getactivescheme",) not in windows
    assert windows[-1] == ("/delete", primero["sparktune"])

    windows.clear()
    salida = runner.invoke(app, ["energia", "restaurar", "--si"])
    assert salida.exit_code == 0 and "restaurado" in salida.output
    assert windows == [("/setactive", ORIGINAL), ("/delete", segundo["sparktune"])]
    assert not (tmp_path / "energia.json").exists()


def test_fallo_a_medias_borra_el_plan_nuevo(windows, monkeypatch, tmp_path):
    original = energia._powercfg

    def falla(*argumentos):
        if argumentos[0] == "/setactive":
            raise RuntimeError("acceso denegado")
        return original(*argumentos)

    monkeypatch.setattr(energia, "_powercfg", falla)
    salida = runner.invoke(app, ["energia", "aplicar", "programar", "--si"])
    assert salida.exit_code == 1 and "No se aplicó" in salida.output
    nuevo = next(o[2] for o in windows if o[0] == "/duplicatescheme")
    assert windows[-1] == ("/delete", nuevo)
    assert not (tmp_path / "energia.json").exists()


def test_groq_solo_elige_un_plan_del_catalogo(windows, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_prueba")
    respuestas = iter([{"perfil": "borrar-windows", "motivo": "x"}])
    monkeypatch.setattr(energia.ProveedorGroq, "_consultar", lambda self, i, d: next(respuestas))
    salida = runner.invoke(app, ["energia", "recomendar", "ver series"])
    assert salida.exit_code == 0, salida.output
    assert "Plan recomendado local: series-bateria" in salida.output


def test_asistente_explica_y_aplica_solo_si_dices_que_si(windows, monkeypatch):
    monkeypatch.setattr(preparar, "preparar", lambda *a, **k: pytest.fail("No se pidió instalar apps"))
    salida = runner.invoke(app, ["--local"], input="ver series con batería\nn\n")
    assert salida.exit_code == 0, salida.output
    assert "Hola, soy SparkTune" in salida.output and "Series con batería" in salida.output
    assert windows == []  # Dijo que no: nada cambia.

    salida = runner.invoke(app, ["--local"], input="quiero programar en python\ns\nn\n")
    assert salida.exit_code == 0, salida.output
    assert "Git.Git" in salida.output and any(o[0] == "/setactive" for o in windows)
    assert re.search(r"Plan activo: SparkTune Programar", salida.output)
