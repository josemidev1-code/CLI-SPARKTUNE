# Desarrollo de SparkTune

El CLI v2 usa Python 3.12, Typer y pathlib. Los textos y JSON se guardan en UTF-8. Trabaja con uv sync --locked y uv run pytest. Usa carpetas temporales en pruebas. Los comandos de lectura y simulación deben funcionar sin clave de IA ni cambios en el equipo. Revisa docs/RELEVO.md al continuar la migración.

El catálogo de archivos está en acciones.json. Los perfiles de preparación del PC están en src/sparktune/preparar.py. Los scripts .ps1 corresponden a la edición 1.x. Para las sesiones del alumno con OpenCode, el alumno revisa los diffs y hace los commits y el push.
