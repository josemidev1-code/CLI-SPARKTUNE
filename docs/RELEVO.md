# Relevo · SparkTune Python · 27 de noviembre de 2026

Objetivo acordado: preparar equipos para necesidades reales, usar IA como asesor, poder simular y combinar acciones y confirmar cada cambio de sistema. La entrega requiere Python 3.12, Typer, uv y pruebas en los tres sistemas. El código PowerShell se conserva como edición 1.x.

Rúbrica: https://aulaenlanube.com/programacion-ia/cli/ (7 criterios: acciones 20, configuración externa 15, IA 15, robustez 15, diseño 10, pruebas 15, instalación y proceso 10).

## Estado

- Rama `codex/sparktune-python` y PR en borrador #3 hacia `main` (https://github.com/josemidev1-code/CLI-SPARKTUNE/pull/3). Todo está commiteado y subido.
- 68 pruebas pytest en verde en Ubuntu, Windows y macOS. El CI también instala el paquete desde una carpeta limpia.
- La prueba real de PowerShell en un runner Windows desechable pasa: los 7 planes de energía (valores CA/CC y restauración del plan original) y aplicar y deshacer los ajustes de `setup`.
- Estructura: `cli.py` (interfaz), `config.py` (`Catalogo`), `acciones.py` (una clase por tipo), `motor.py` (`Plan`), `ficheros.py`, `esquema.py`, `errores.py`, `dialogo.py`, `proveedores.py` (Groq y local), `ia.py` y `preparar.py`.
- Hecho en esta sesión: rescate del trabajo sin commitear; correcciones para Windows (firma `lstat`/`fstat`, salida en `cp1252`, `PERFEPP` oculto, que ahora se lee con `powercfg /qh`); diseño en clases; robustez (ruta inexistente, enlaces de root como `/tmp` y confirmación `[s/N]`); `.gitattributes`; ADR 0003; `docs/prompts.md`; propuestas de IA con qué cambia, por qué encaja y cómo se revierte, generadas desde el catálogo y no desde el modelo; reversión cuando `preparar` falla a medias.
- `docs/DEFENSA.md`: evidencia de cada criterio de la rúbrica, demostración en cinco minutos, qué comprueba cada una de las 68 pruebas, preguntas probables y puntos débiles conocidos.
- Seguridad de la 1.x: 50 acciones que no guardaban el estado anterior real quedan en revisión y no se ofrecen (`$script:STEnRevision` en `src/core/catalog.ps1`; detalle en `docs/REVISION.md`). Corregirlas es trabajo futuro, no un requisito de la entrega. PowerShell 7 está instalado en este Mac (`pwsh`), así que las pruebas `tests/*.ps1` se pueden ejecutar en local.
- `docs/PRUEBA-WINDOWS.md`: guion para un portátil físico. Cubre el punto de restauración (incluidos el límite de 24 h, la consola sin administrador y la Protección del sistema desactivada), WinGet real (aplicación ya instalada, fallo de red y Creative Cloud), la transparencia y la autonomía con `powercfg /batteryreport`, con una tabla de resultados. Lo revisaron cuatro revisores independientes contra el código y la documentación de Microsoft. Todavía no se ha ejecutado en un equipo real.
- Corregidos dos errores de `preparar` encontrados al escribir el guion, cada uno con su prueba:
  - Una aplicación que ya estaba instalada ya no aparece en «Cambios aplicados y cómo deshacerlos»: `_instalar` devuelve si de verdad instaló.
  - Si psutil no sabe si el portátil está enchufado, se muestra «estado de carga desconocido» en lugar de «enchufado».
- Estimación frente a la rúbrica: unos 92-94 de 100.

## Pendiente, por orden

1. Ejecutar `docs/PRUEBA-WINDOWS.md` en el portátil y guardar la tabla de resultados.
2. Completar en `docs/prompts.md` las sesiones anteriores con ChatGPT y Codex (solo las conoce el alumno).
3. Al final: entrada 2.0.0 en `CHANGELOG.md`, fusionar el PR #3, etiqueta `v2.0.0` y release. Es imprescindible para la puerta de entrada: `main` no tiene `pyproject.toml`, así que hasta que se fusione la orden de instalación del README falla. Mientras tanto, se instala desde la rama con `@codex/sparktune-python`.

## Por confirmar con el profesor

- Que acepta la versión Python con un extra solo para Windows.
- La fecha de entrega: la página indica el 20 de noviembre.
- `.env` está en `.gitignore` desde `856e745` (25 de noviembre), no desde el primer commit. Nunca se subió ningún `.env` ni ninguna clave.

## Reglas de trabajo

- Commits pequeños que dejen las pruebas en verde por sí solos. Cada commit, push o PR, con la aprobación del alumno.
- Desarrollo: `uv sync --locked`, `uv run pytest`. En este Mac se usa `.venv/bin/python -m pytest` porque `uv` no está en el PATH.
