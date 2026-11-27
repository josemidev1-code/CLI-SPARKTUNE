import hashlib
import json
from pathlib import Path
from datetime import datetime

import os

import pytest
from typer.testing import CliRunner

from sparktune import ficheros
from sparktune.cli import app
from sparktune.config import Catalogo
from sparktune.errores import ErrorEjecucion
from sparktune.motor import Plan

runner = CliRunner()


def test_tabla_y_json_por_defecto(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    (tmp_path / "álbum.txt").write_bytes(b"demo")
    (tmp_path / "vacia").mkdir()
    salida = runner.invoke(app, ["listar", "--json"])
    assert salida.exit_code == 0, salida.output
    entradas = {fila["nombre"]: fila for fila in json.loads(salida.output)}
    assert entradas["álbum.txt"]["bytes"] == 4
    assert datetime.fromisoformat(entradas["álbum.txt"]["modificado"]).utcoffset().total_seconds() == 0
    assert entradas["vacia"]["tipo"] == "carpeta"
    tabla = runner.invoke(app, ["listar"])
    assert "MODIFICADO (UTC)" in tabla.output
    assert "álbum.txt" in tabla.output


def test_perfil_simulacion_y_ejecucion(tmp_path):
    originales = {"Foto.PNG": b"png", "análisis.log": b"log", "plan.json": b"{}", "otro.bin": b"x"}
    for nombre, contenido in originales.items():
        (tmp_path / nombre).write_bytes(contenido)
    (tmp_path / "ignorada").mkdir()
    (tmp_path / "ignorada" / "interna.log").touch()
    args = ["ejecutar", "preparar-entrega", str(tmp_path)]
    simulacion = runner.invoke(app, [*args, "--simular", "--si"])
    assert simulacion.exit_code == 0, simulacion.output
    assert {p.name for p in tmp_path.iterdir()} == set(originales) | {"ignorada"}
    cancelacion = runner.invoke(app, args, input="n\n")
    assert cancelacion.exit_code == 0
    assert "Cancelado" in cancelacion.output
    resultado = runner.invoke(app, [*args, "--si"])
    assert resultado.exit_code == 0, resultado.output
    assert simulacion.output.split("Simulación completada.")[0] == resultado.output.split("Salida creada en")[0]
    salida = tmp_path / "sparktune-salida"
    assert (salida / "reunir-capturas" / "Foto.PNG").read_bytes() == b"png"
    assert (salida / "reunir-informes" / "análisis.log").read_bytes() == b"log"
    assert (salida / "guardar-planes" / "plan.json").read_bytes() == b"{}"
    inventario = json.loads((salida / "inventariar" / "inventario.json").read_text())
    assert {f["nombre"]: f["bytes"] for f in inventario} == {n: len(c) for n, c in originales.items()}
    huellas = json.loads((salida / "calcular-huellas" / "sha256.json").read_text())
    assert {f["nombre"]: f["sha256"] for f in huellas} == {
        n: hashlib.sha256(c).hexdigest() for n, c in originales.items()
    }
    assert not (salida / ".incompleto").exists()
    assert {n: (tmp_path / n).read_bytes() for n in originales} == originales


def test_ejecuciones_repetidas_y_combinacion(tmp_path):
    (tmp_path / "log.txt").write_bytes(b"1")
    args = ["ejecutar", "reunir-informes,inventariar,reunir-informes", str(tmp_path), "--si"]
    assert runner.invoke(app, args).exit_code == 0
    (tmp_path / "log.txt").write_bytes(b"2")
    resultado = runner.invoke(app, args)
    assert resultado.exit_code == 0, resultado.output
    assert (tmp_path / "sparktune-salida" / "reunir-informes" / "log.txt").read_bytes() == b"1"
    assert (tmp_path / "sparktune-salida-2" / "reunir-informes" / "log.txt").read_bytes() == b"2"


def test_config_alternativa_y_local(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    catalogo = {
        "version": 1,
        "acciones": [{"id": "manuales", "tipo": "copiar", "extensiones": [".md"], "descripcion": "Copia manuales"}],
        "perfiles": {},
    }
    ruta = tmp_path / "mis-acciones.json"
    ruta.write_text(json.dumps(catalogo))
    (tmp_path / "acciones.json").write_text("JSON roto")
    for orden in (["validar"], ["acciones"], ["ejecutar", "manuales", "--simular"]):
        resultado = runner.invoke(app, orden)
        assert resultado.exit_code == 3
        assert "acciones.json" in resultado.stderr
        assert resultado.stdout == ""
    assert runner.invoke(app, ["--config", str(ruta), "validar"]).exit_code == 0
    listado = runner.invoke(app, ["--config", str(ruta), "acciones", "--json"])
    assert json.loads(listado.stdout) == catalogo
    (tmp_path / "README.md").write_text("manual")
    respuesta = runner.invoke(app, ["--config", str(ruta), "ejecutar", "manuales", "--si"])
    assert respuesta.exit_code == 0, respuesta.output
    assert (tmp_path / "sparktune-salida" / "manuales" / "README.md").read_text() == "manual"


@pytest.mark.parametrize(("ruta", "valor", "mensaje"), [
    (("version",), True, "version"),
    (("acciones",), {}, "acciones"),
    (("acciones", 0, "id"), "../fuera", "id"),
    (("acciones", 0, "id"), "con", "reservado"),
    (("acciones", 0, "descripcion"), None, "descripcion"),
    (("acciones", 0, "tipo"), "borrar", "tipo"),
    (("acciones", 0, "extensiones"), [], "extensiones"),
    (("acciones", 0, "extensiones"), [".pdf", ".pdf"], "extensiones"),
    (("acciones", 0, "extensiones"), [True], "extensiones"),
    (("acciones", 0, "extra"), "x", "extra"),
    (("perfiles",), [], "perfiles"),
    (("perfiles", "preparar-entrega"), ["inexistente"], "desconocida"),
    (("perfiles", "reunir-capturas"), ["inventariar"], "coincide"),
])
def test_errores_de_campos(tmp_path, ruta, valor, mensaje):
    catalogo = json.loads(Catalogo.ruta_por_defecto().read_text(encoding="utf-8"))
    objeto = catalogo
    for parte in ruta[:-1]:
        objeto = objeto[parte]
    objeto[ruta[-1]] = valor
    fichero = tmp_path / "prueba.json"
    fichero.write_text(json.dumps(catalogo))
    resultado = runner.invoke(app, ["--config", str(fichero), "validar"])
    assert resultado.exit_code == 3
    assert mensaje in resultado.stderr
    assert resultado.stdout == ""


def test_errores_de_uso_y_ruta(tmp_path):
    resultado = runner.invoke(app, ["ejecutar", "desconocida", str(tmp_path), "--si"])
    assert resultado.exit_code == 2
    assert "desconocid" in resultado.stderr
    for comando in (["listar", str(tmp_path / "ausente")], ["ejecutar", "inventariar", str(tmp_path / "ausente")]):
        resultado = runner.invoke(app, comando)
        assert resultado.exit_code == 1
        assert "ausente" in resultado.stderr
    resultado = runner.invoke(app, ["--config", str(tmp_path / "ausente"), "acciones"])
    assert resultado.exit_code == 3
    assert not list(tmp_path.iterdir())


def test_no_sigue_enlaces_y_reserva_otra_salida(tmp_path):
    proyecto = tmp_path / "proyecto"
    proyecto.mkdir()
    externo = tmp_path / "privado.txt"
    externo.write_bytes(b"privado")
    try:
        (proyecto / "enlace.txt").symlink_to(externo)
        (proyecto / "sparktune-salida").symlink_to(tmp_path / "ausente", target_is_directory=True)
        (tmp_path / "proyecto-enlazado").symlink_to(proyecto, target_is_directory=True)
    except OSError:
        pytest.skip("El sistema requiere permisos adicionales para crear enlaces.")
    ejecutado = runner.invoke(app, ["ejecutar", "preparar-entrega", str(proyecto), "--si"])
    assert ejecutado.exit_code == 0, ejecutado.output
    assert not list((proyecto / "sparktune-salida-2" / "reunir-informes").iterdir())
    assert not (tmp_path / "ausente").exists()
    rechazado = runner.invoke(app, ["ejecutar", "inventariar", str(tmp_path / "proyecto-enlazado"), "--si"])
    assert rechazado.exit_code == 1
    assert "enlace" in rechazado.stderr


def test_cambio_posterior_al_plan_y_carrera_destino(tmp_path):
    origen = tmp_path / "a.txt"
    origen.write_bytes(b"original")
    plan = Plan.preparar(tmp_path, Catalogo.desde_archivo().seleccionar("reunir-informes"))
    origen.write_bytes(b"otro contenido")
    with pytest.raises(ErrorEjecucion, match="incompleta"):
        plan.aplicar()
    assert (plan.destino / ".incompleto").exists()
    assert origen.read_bytes() == b"otro contenido"
    with pytest.raises(FileExistsError):
        plan.aplicar()
    assert (plan.destino / ".incompleto").exists()


def test_dos_nombres_no_portables_no_llegan_a_la_salida(tmp_path):
    ruta = tmp_path / "Foto.PNG"
    ruta.touch()
    # Fuerza ambas entradas del plan también en sistemas sin distinción de mayúsculas.
    entradas = [ficheros.Entrada(ruta, ruta.stat()), ficheros.Entrada(tmp_path / "foto.png", ruta.stat())]
    acciones = Catalogo.desde_archivo().seleccionar("reunir-capturas")
    with pytest.raises(ErrorEjecucion, match="colisión"):
        Plan.desde_entradas(tmp_path, entradas, acciones)
    assert not (tmp_path / "sparktune-salida").exists()


def test_firma_coincide_al_abrir_el_archivo(tmp_path):
    # Windows obtiene lstat y fstat con APIs distintas; un archivo intacto debe pasar la comprobación.
    ruta = tmp_path / "intacto.txt"
    ruta.write_bytes(b"demo")
    entrada = ficheros.Entrada(ruta, ruta.lstat())
    with entrada.abrir() as flujo:
        abierto = os.fstat(flujo.fileno())
        campos = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")
        detalle = {c: (getattr(entrada.estado, c), getattr(abierto, c)) for c in campos}
        assert ficheros.firma(abierto) == ficheros.firma(entrada.estado), detalle
        assert flujo.read() == b"demo"


def test_salida_redirigida_con_codificacion_antigua(tmp_path):
    # Windows usa cp1252 al redirigir la salida; el plan contiene «→» y nombres con tildes.
    import subprocess
    import sys

    (tmp_path / "diagnóstico.txt").write_text("ok", encoding="utf-8")
    entorno = dict(os.environ, PYTHONIOENCODING="cp1252")
    resultado = subprocess.run([sys.executable, "-m", "sparktune", "ejecutar", "reunir-informes",
                                str(tmp_path), "--simular"], capture_output=True, env=entorno)
    assert resultado.returncode == 0, resultado.stderr.decode("utf-8", "replace")
    assert "→".encode() in resultado.stdout and "diagnóstico".encode() in resultado.stdout


def test_tipo_nuevo_se_registra_sin_tocar_motor_ni_catalogo(tmp_path, monkeypatch):
    # Una subclase con «tipo» queda disponible para acciones.json; el motor no cambia.
    from sparktune.acciones import Accion

    monkeypatch.setattr(Accion, "_tipos", dict(Accion._tipos))

    class Contar(Accion):
        tipo = "contar"

        def describir(self, fuentes):
            return [f"  Contar {len(fuentes)} archivos"]

        def escribir(self, fuentes, carpeta):
            (carpeta / "total.txt").write_text(str(len(fuentes)), encoding="utf-8")

    datos = {"version": 1, "perfiles": {},
             "acciones": [{"id": "contar-todo", "descripcion": "Cuenta archivos", "tipo": "contar", "extensiones": []}]}
    (tmp_path / "a.txt").touch()
    plan = Plan.preparar(tmp_path, Catalogo.desde_datos(datos).seleccionar("contar-todo"))
    assert plan.lineas()[1:] == ["contar-todo (1 archivos)", "  Contar 1 archivos"]
    plan.aplicar()
    assert (plan.destino / "contar-todo" / "total.txt").read_text(encoding="utf-8") == "1"


def test_ruta_inexistente_da_mensaje_claro(tmp_path):
    resultado = runner.invoke(app, ["ejecutar", "inventariar", str(tmp_path / "no-existe"), "--simular"])
    assert resultado.exit_code == 1
    assert "No existe la carpeta" in resultado.stderr and "Errno" not in resultado.stderr


def test_acepta_enlaces_del_sistema_como_tmp(tmp_path):
    # En macOS /tmp es un enlace de root a /private/tmp; un usuario no puede crear uno así.
    sistema = Path("/tmp")
    if os.name == "nt" or not sistema.is_symlink() or sistema.lstat().st_uid != 0:
        pytest.skip("Este sistema no tiene /tmp como enlace de root.")
    import tempfile

    with tempfile.TemporaryDirectory(dir=sistema) as carpeta:
        (Path(carpeta) / "a.log").write_text("ok", encoding="utf-8")
        resultado = runner.invoke(app, ["ejecutar", "reunir-informes", carpeta, "--simular"])
    assert resultado.exit_code == 0, resultado.output
