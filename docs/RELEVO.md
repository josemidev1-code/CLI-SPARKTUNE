# Entrega 2.1.0

La revisión final reúne el asistente, los planes de energía, los cambios de protección y 82 pruebas. El registro siguiente conserva los detalles y las limitaciones de las comprobaciones.

# Relevo vigente · rama codex/final

En Windows 11 (UTM) se instaló el wheel intermedio en un entorno temporal y se ejecutaron asesorar Android en modo local y energia aplicar programar --simular. Salida: docs/evidencias/windows-simulacion.txt. La recuperación ante disco lleno se añadió después y se probó mediante un fallo simulado.

Los PR 5 y 6 están fusionados y v2.0.1 publicada. La rama parte del merge f749abd, posterior a esa etiqueta. El relevo histórico de abajo describe etapas anteriores.

Se retomó la extracción del módulo equipo.py y el manejo de confirmaciones. Ahora las consultas asesorar, explicar y energia recomendar respetan --local antes del subcomando y la activación del plan exige un punto nuevo verificado. Si falla la escritura del historial de energía tras la activación, se intenta recuperar el plan anterior. Se añadieron cinco casos de regresión. macOS: 82 pruebas pasan, instalación/uso/desinstalación del wheel correctos y Gitleaks sin detecciones en 86 commits. Las pruebas del sistema energético usan dobles. Pendientes: verificar el cambio de plan y su recuperación en Windows con consentimiento en la consola, comprobar con batería física, revisar el diff con el alumno antes de publicar.

---

# Relevo · SparkTune · 27 de noviembre de 2026

Objetivo acordado: preparar equipos para necesidades reales, usar IA como asesor, poder simular y combinar acciones y confirmar cada cambio de sistema. La entrega requiere Python 3.12, Typer, uv y pruebas en los tres sistemas. El código PowerShell se conserva como edición 1.x.

Rúbrica: https://aulaenlanube.com/programacion-ia/cli/ (7 criterios: acciones 20, configuración externa 15, IA 15, robustez 15, diseño 10, pruebas 15, instalación y proceso 10).

## Estado

- **SparkTune 2.0.0 está publicado** (PR #3, merge `e88062b`, release [v2.0.0](https://github.com/josemidev1-code/CLI-SPARKTUNE/releases/tag/v2.0.0)).
- **El PR #4 se fusionó en `main`** con merge commit (`5fd8c47`) tras pasar las 10 comprobaciones de CI: instalador 1.x, filtro de privacidad, `*.sh` con LF y `net.doh`/`net.wsl-nat` en revisión.
- **La 2.0.1 se prepara en el PR #5** (rama `codex/2.0.1`): versión 2.0.1 en `pyproject.toml` y `uv.lock`, entrada en el CHANGELOG y las correcciones de la revisión. Al fusionarlo se crea la etiqueta `v2.0.1` sobre el merge commit y la release con las notas de la entrada 2.0.1.
- Identidad de git: desde la 2.0.1 los commits usan `josemidev1-code` con el correo noreply de GitHub, configurado solo en este repositorio. El historial anterior no se reescribe.
- 71 pruebas pytest en verde y las 8 pruebas `tests/*.ps1` en verde con `pwsh` en este Mac.
- Estructura: `cli.py` (interfaz), `config.py` (`Catalogo`), `acciones.py` (una clase por tipo), `motor.py` (`Plan`), `ficheros.py`, `esquema.py`, `errores.py`, `dialogo.py`, `proveedores.py` (Groq y local), `ia.py` y `preparar.py`.
- Comprobación manual: `docs/PRUEBA-WINDOWS.md` (17 casos, todavía sin ejecutar en un portátil).
- Edición 1.x: 52 de las 81 acciones quedan en revisión y no se ofrecen (`$script:STEnRevision` en `src/core/catalog.ps1`, detalle en `docs/REVISION.md`). Corregirlas es trabajo futuro.
- Estimación frente a la rúbrica: unos 92-94 de 100.

## Revisión del 27 de noviembre

Seis enfoques (código, seguridad, pruebas, documentación, entrega y PowerShell), cada hallazgo comprobado antes de aceptarlo. Los enfoques de código, pruebas y documentación se repitieron en la sesión de la 2.0.1.

Corregido en el PR #4: instalador 1.x, filtro de privacidad, `*.sh` con LF, cifra de commits de DEFENSA y `net.doh`/`net.wsl-nat` a revisión.

Corregido en el PR #5:

1. Identidad de git configurada antes del primer commit (correo noreply).
2. `.opencode/agents/revisor.md` pasa a `mode: all`. Según la documentación de OpenCode, `subagent` solo se ejecuta desde la herramienta `subagent`, y `all` sirve como agente principal o como subagente. No se pudo ejecutar `scripts/revisar.sh` porque OpenCode no está instalado en este Mac.
3. `docs/POWERSHELL.md` ya no anuncia el endurecimiento `sec.*` ni las acciones `priv.*`, y aclara que `red-privacidad` solo ofrece el informe de Defender y vaciar la caché DNS.
4. `tests/verify-windows.ps1` ya no aplica ni deshace `gpu.power-mode`, y el bloque manual ya no pide `net.wsl-nat`, `off.hibernation`, `sec.*` ni `priv.*`.
5. `tests/safety-tests.ps1` carga el catálogo real y comprueba que `net.doh` no se ofrece pero `undo` la sigue deshaciendo. Se comprobó que la prueba falla si `Invoke-STUndo` omite las acciones en revisión.

Revisión repetida de código, pruebas y documentación: sin errores graves. Queda un detalle menor sin corregir: si `ejecutar` o `preparar` no reciben respuesta (entrada cerrada o Ctrl+C), Click muestra «Aborted.» en inglés y sale con código 1. No escribe nada, así que es seguro.

## Pendiente, por orden

1. Fusionar el PR #5 con el CI en verde, crear la etiqueta `v2.0.1` y la release.
2. Ejecutar `docs/PRUEBA-WINDOWS.md` en el portátil y guardar la tabla de resultados. Si obliga a corregir algo, va en la siguiente versión.
3. Completar en `docs/prompts.md` las sesiones con ChatGPT y Codex (solo las conoce el alumno).
4. Opcional: mensaje en español cuando falta la respuesta a una confirmación.

## Por confirmar con el profesor

- Que acepta la versión Python con un extra solo para Windows.
- La fecha de entrega: la página indica el 20 de noviembre.
- `.env` está en `.gitignore` desde `856e745` (25 de noviembre), no desde el primer commit. Nunca se subió ningún `.env` ni ninguna clave.

## Reglas de trabajo

- Cada cambio va en una rama desde `main` y entra con un PR. Commits pequeños que dejen las pruebas en verde por sí solos. Cada commit, push, PR, fusión o release, con la aprobación del alumno, que tiene que poder explicar cada cambio.
- Antes de fusionar, el CI del PR debe estar en verde. Se fusiona con merge commit para conservar el historial.
- Desarrollo: `uv sync --locked` y `uv run pytest`. En este Mac, `uv` no está en el PATH: usa `.venv/bin/python -m pytest`. Las pruebas de la 1.x se ejecutan con `pwsh -NoProfile -File tests/<archivo>.ps1`.
