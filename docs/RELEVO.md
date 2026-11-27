# Relevo · SparkTune · 27 de noviembre de 2026

Objetivo acordado: preparar equipos para necesidades reales, usar IA como asesor, poder simular y combinar acciones y confirmar cada cambio de sistema. La entrega requiere Python 3.12, Typer, uv y pruebas en los tres sistemas. El código PowerShell se conserva como edición 1.x.

Rúbrica: https://aulaenlanube.com/programacion-ia/cli/ (7 criterios: acciones 20, configuración externa 15, IA 15, robustez 15, diseño 10, pruebas 15, instalación y proceso 10).

## Estado

- **SparkTune 2.0.0 está publicado.** El PR #3 se fusionó en `main` con merge commit (`e88062b`), y la release [v2.0.0](https://github.com/josemidev1-code/CLI-SPARKTUNE/releases/tag/v2.0.0) apunta a ese commit.
- **La instalación del README funciona desde `main`.** Se comprobó instalando desde la URL de GitHub en un entorno limpio y ejecutando `version`, `--help`, `validar`, `acciones` y `ejecutar` desde otra carpeta. Hace falta Git.
- Los cambios posteriores a la release (PR #4) están en `main` y figuran en `CHANGELOG.md` como «Sin publicar»:
  - El instalador 1.x vuelve a funcionar.
  - El filtro de privacidad de la IA detecta más formas de escribir datos privados.
  - Los scripts `.sh` usan LF.
  - `net.doh` y `net.wsl-nat` pasan a revisión.
- 71 pruebas pytest en verde en Ubuntu, Windows y macOS, y las 8 pruebas `tests/*.ps1` en verde con `pwsh` en este Mac.
- Estructura: `cli.py` (interfaz), `config.py` (`Catalogo`), `acciones.py` (una clase por tipo), `motor.py` (`Plan`), `ficheros.py`, `esquema.py`, `errores.py`, `dialogo.py`, `proveedores.py` (Groq y local), `ia.py` y `preparar.py`.
- Documentación para la defensa:
  - `docs/DEFENSA.md`: evidencia de cada criterio, demostración en cinco minutos, qué comprueba cada una de las 71 pruebas, preguntas probables y puntos débiles.
  - `docs/PRUEBA-WINDOWS.md`: guion de 17 casos para un portátil real. Todavía no se ha ejecutado.
- Edición 1.x: 52 de las 81 acciones quedan en revisión y no se ofrecen, porque no restauraban el estado anterior real. La lista es `$script:STEnRevision` en `src/core/catalog.ps1` y el detalle está en `docs/REVISION.md`. Corregirlas es trabajo futuro, no un requisito de la entrega.
- Estimación frente a la rúbrica: unos 92-94 de 100.

## Revisión del 27 de noviembre

Se lanzó una revisión con seis enfoques: código, seguridad, pruebas, documentación, entrega y PowerShell. Cada hallazgo pasaba después por un verificador escéptico. Terminaron los enfoques de seguridad, entrega y PowerShell. Los de **código, pruebas y documentación no habían terminado** al cerrar la sesión: hay que repetirlos. Si terminaron después, sus resultados están en `~/.claude/projects/-Users-josemidev1-Documents-ChatGPT-SparkTune-CLI-CLI-SPARKTUNE/7c8c2768-05b4-4d02-a653-41216a650243/subagents/workflows/wf_8e098163-5b6/journal.jsonl`.

Corregido en esta sesión: el instalador 1.x, el filtro de privacidad, `*.sh` con LF, la cifra de commits de DEFENSA y `net.doh` y `net.wsl-nat` a revisión.

Pendiente, sin verificar todavía por un segundo revisor salvo donde se indica:

1. **Identidad de git (confirmado).** Casi todos los commits de la 2.0.0 tienen como autor un nombre y un correo que git genera a partir del usuario y del nombre del equipo, porque no tiene `user.name` ni `user.email` configurados. Ese correo ya está publicado. Compruébalo con `git log --format='%an <%ae>' | sort | uniq -c`. Antes del siguiente commit, el alumno configura su identidad, por ejemplo con su correo noreply de GitHub. No conviene reescribir el historial de `main`.
2. `scripts/revisar.sh` ejecuta `opencode run --agent revisor`, pero `.opencode/agents/revisor.md` declara `mode: subagent`, que según la documentación de OpenCode no puede ser el agente principal. Posible corrección: `mode: all`.
3. `docs/POWERSHELL.md` (líneas 252, 258 y 276) sigue anunciando funciones que ahora están en revisión: el endurecimiento `sec.*` y las acciones `priv.*` del perfil `red-privacidad`.
4. `tests/verify-windows.ps1` (líneas 89 y 102) pide aplicar desde el asistente `gpu.power-mode` y acciones `sec.*`/`priv.*`, que ya no se ofrecen.
5. Ninguna prueba comprueba que `undo` siga deshaciendo una acción en revisión aplicada con una versión anterior. Habría que añadir un caso a `tests/safety-tests.ps1`.

## Pendiente, por orden

1. Repetir la revisión de código, pruebas y documentación y verificar y corregir los puntos 2 a 5 de la revisión, cada uno con su prueba si es código.
2. Publicar los cambios «Sin publicar» como 2.0.1: fecha en el CHANGELOG, etiqueta `v2.0.1` y release.
3. Ejecutar `docs/PRUEBA-WINDOWS.md` en el portátil y guardar la tabla de resultados. Si obliga a corregir algo, va en la siguiente versión.
4. Completar en `docs/prompts.md` las sesiones con ChatGPT y Codex (solo las conoce el alumno).

## Por confirmar con el profesor

- Que acepta la versión Python con un extra solo para Windows.
- La fecha de entrega: la página indica el 20 de noviembre.
- `.env` está en `.gitignore` desde `856e745` (25 de noviembre), no desde el primer commit. Nunca se subió ningún `.env` ni ninguna clave.

## Reglas de trabajo

- Cada cambio va en una rama desde `main` y entra con un PR. Commits pequeños que dejen las pruebas en verde por sí solos. Cada commit, push, PR, fusión o release, con la aprobación del alumno, que tiene que poder explicar cada cambio.
- Antes de fusionar, el CI del PR debe estar en verde. Se fusiona con merge commit para conservar el historial.
- Desarrollo: `uv sync --locked` y `uv run pytest`. En este Mac, `uv` no está en el PATH: usa `.venv/bin/python -m pytest`. Las pruebas de la 1.x se ejecutan con `pwsh -NoProfile -File tests/<archivo>.ps1`.
