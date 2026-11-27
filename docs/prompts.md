# Prompts clave

Este documento recoge los prompts que definen el comportamiento de SparkTune y los que guiaron su desarrollo con agentes de IA.

## 1. Prompts del producto (capa de IA)

SparkTune envía a Groq (`openai/gpt-oss-120b`) un mensaje de sistema y los datos en JSON. El código está en `src/sparktune/proveedores.py`. Todos los mensajes de sistema empiezan por «Responde en español y en JSON.»

| Orden | Instrucción enviada | Datos enviados | Qué acepta SparkTune |
| --- | --- | --- | --- |
| `asesorar` | «Elige un solo ID de perfiles para el objetivo del usuario. Devuelve las claves perfil y motivo. Redacta una frase breve sobre el encaje, sin órdenes de terminal.» | Objetivo (máx. 1200 caracteres), perfiles del catálogo y resumen del equipo | Un `perfil` que exista en el catálogo y un `motivo` no vacío. Si no, usa la recomendación local. |
| `explicar` | «Interpreta los recursos medidos para el perfil elegido. Devuelve prioridad y primer_paso, una frase concreta por campo. Evita inventar mediciones o proponer órdenes de terminal.» | Perfil, su descripción y resumen del equipo | `prioridad` y `primer_paso` no vacíos. |
| `comprobar-ia` | «Devuelve {"estado":"ok"}.» | `{"peticion": "comprobar conexión"}` | `estado` igual a `ok`. |

Decisiones de diseño de estos prompts:

- **Respuesta en JSON con claves fijas** (`response_format: json_object`): SparkTune comprueba cada campo en lugar de interpretar texto libre.
- **El modelo solo elige entre opciones del catálogo.** Nunca devuelve paquetes ni órdenes que se ejecuten, así que una respuesta inventada no puede instalar nada.
- **Qué cambia y cómo se revierte no lo escribe el modelo.** SparkTune añade a cada propuesta la lista de cambios y su reversión a partir de su propio catálogo (`preparar.propuesta()`). Si el modelo añade campos como `paquetes` o `deshacer`, se ignoran (lo comprueba `test_el_modelo_no_decide_cambios_ni_reversion`).
- **Datos mínimos:** el resumen del equipo incluye sistema, arquitectura, núcleos, RAM, disco libre y batería, sin nombres de usuario, del equipo ni rutas. Si el objetivo parece contener una ruta, un correo o una clave, no se envía y se responde en local.
- **Texto saneado:** se eliminan secuencias ANSI y caracteres de control antes de mostrar la respuesta.

## 2. Prompts del agente en el repositorio

- `AGENTS.md`: reglas generales del proyecto para cualquier agente.
- `.opencode/commands/nueva-accion.md`: diseña una acción con el alumno, que escribe o aprueba la entrada JSON.
- `.opencode/agents/revisor.md`: agente de solo lectura, usable como principal o como subagente, que busca pérdida de datos, sobrescrituras, escrituras durante la simulación, secretos y cambios de Windows sin confirmación.
- `.opencode/skills/acciones-json/SKILL.md`: lista de comprobaciones al añadir o revisar acciones.

## 3. Sesiones de desarrollo

### Sesión con Claude Code · 27 de noviembre de 2026

Prompt de arranque (resumen del encargo):

> Continúa SparkTune, mi CLI para Windows evaluado con la rúbrica de aulaenlanube. Lee primero la rúbrica y el repositorio, conserva el trabajo existente y dame un plan priorizado para aprobarlo antes de cambiar código. Explícame cada cambio, porque tendré que defenderlo. Prioridades: pruebas reales en Windows, punto de restauración y reversión, comparación con WinGet real, una IA que diga qué cambia, por qué y cómo se revierte, revisión de seguridad de las acciones antiguas y contraste con la rúbrica criterio por criterio.

Flujo seguido: plan → aprobación del alumno → cambios → pruebas → commit. Cada paso se aprobó en el chat («Sí, empieza», «Sí, haz push», «Sí, abre el PR», «Sí, sigue»). En esta sesión el agente hizo los commits y los push con aprobación explícita del alumno en cada caso, una excepción a la regla de `AGENTS.md`.

Resultados principales:

- Se guardó en commits la versión 2 en Python, que estaba sin commitear.
- El CI en Windows detectó dos fallos que en macOS no se veían: la comprobación de archivos intactos (`lstat` frente a `fstat`) y la salida redirigida en `cp1252`. Ambos se corrigieron con una prueba que los reproduce.
- Se separó el código en clases y módulos (interfaz, catálogo, acciones, motor, errores y proveedores de IA).

### Sesiones anteriores con ChatGPT y Codex

*Completa esta sección con los prompts clave que usaste en esas sesiones y con lo que aceptaste o rechazaste de cada respuesta.*
