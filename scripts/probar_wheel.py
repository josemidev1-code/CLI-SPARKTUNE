"""Prueba la distribución instalada desde un directorio limpio en los tres SO."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory


def main():
    wheel, = (Path(__file__).resolve().parents[1] / "dist").glob("*.whl")
    uv = shutil.which("uv")
    with TemporaryDirectory() as temp:
        base = Path(temp).resolve()
        env = dict(os.environ, UV_TOOL_DIR=str(base / "tools"), UV_TOOL_BIN_DIR=str(base / "bin"))

        def run(*args):
            return subprocess.run(args, check=True, cwd=base, env=env, stdout=subprocess.PIPE).stdout

        run(uv, "tool", "install", "--python", sys.executable, str(wheel))
        cli = base / "bin" / ("sparktune.exe" if os.name == "nt" else "sparktune")
        run(cli, "--help")
        print("Versión instalada:", run(cli, "version").decode().strip())
        catalogo = json.loads(run(cli, "acciones", "--json"))
        assert len(catalogo["acciones"]) >= 5
        run(cli, "validar")
        run(cli, "preparar", "android", "--simular")
        muestra = base / "Pruebas con espacios"
        muestra.mkdir()
        (muestra / "diagnóstico.txt").write_text("Todo correcto", encoding="utf-8")
        run(cli, "ejecutar", "preparar-entrega", muestra, "--simular")
        assert len(list(muestra.iterdir())) == 1
        run(cli, "ejecutar", "preparar-entrega", muestra, "--si")
        assert (muestra / "sparktune-salida/reunir-informes/diagnóstico.txt").read_text(encoding="utf-8") == "Todo correcto"
        run(uv, "tool", "uninstall", "sparktune")
        assert not cli.exists()
        print("Ayuda, catálogo, plan, simulación, aplicación y desinstalación correctos.")


if __name__ == "__main__":
    main()
