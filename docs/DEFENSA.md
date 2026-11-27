# Defensa de SparkTune 2

Este documento reúne la evidencia de cada criterio de la rúbrica y explica qué comprueba cada prueba. Está pensado para preparar la defensa: para cada afirmación indica dónde está en el código, cómo enseñarla en directo y qué prueba la respalda.

Los criterios se basan en un resumen de la rúbrica (https://aulaenlanube.com/programacion-ia/cli/). Antes de la defensa, compara los textos con la página.

Estado verificado el 27 de noviembre de 2026: `pytest` muestra 71 pruebas en verde en local, y en el PR #3 pasaron todos los trabajos de GitHub Actions (pytest en Ubuntu, Windows y macOS, y los trabajos de PowerShell) antes de fusionarlo en `main`. La versión publicada es la release `v2.0.0`.

## Puerta de entrada

Si falla alguna de estas condiciones, el proyecto no se evalúa.

| Condición | Estado | Evidencia |
| --- | --- | --- |
| Se instala siguiendo el README y `--help` funciona | Cumple | El PR #3 está fusionado, así que `main` contiene el paquete y `uv tool install git+https://github.com/josemidev1-code/CLI-SPARKTUNE` instala la versión 2.0.0. Hace falta Git, como indica el README. El CI lo comprueba en los tres sistemas con [scripts/probar_wheel.py](../scripts/probar_wheel.py): construye el paquete, lo instala en una carpeta limpia y ejecuta `--help`. |
| Al menos 3 acciones propias en `acciones.json` | Cumple | Hay 5 acciones y 1 perfil en [acciones.json](../acciones.json). |
| Ninguna clave en el repositorio ni en su historial | Cumple | `git log -p --all \| grep -E "gsk_[A-Za-z0-9]{20,}\|sk-[A-Za-z0-9]{20,}"` no encuentra nada, y `git log --all -- .env` está vacío. Las claves de las pruebas (`gsk_ejemplo`) son falsas. |
| Al menos 10 commits | Cumple | `main` tiene más de 70 commits. Compruébalo con `git rev-list --count main`. |

## Demostración en cinco minutos

Ejecútala en una carpeta temporal con algunos archivos (`a.png`, `informe.log`, `plan.json`):

```console
sparktune --help
sparktune validar
sparktune acciones
sparktune ejecutar preparar-entrega . --simular      # muestra el plan sin escribir nada
sparktune ejecutar reunir-informes,inventariar .     # pide [s/N]; Enter cancela
sparktune ejecutar preparar-entrega . --si           # crea sparktune-salida/
sparktune ejecutar preparar-entrega . --si           # crea sparktune-salida-2/ y no toca la anterior
sparktune ejecutar inexistente .; echo $?            # 2: acción desconocida
sparktune listar ./no-existe; echo $?                # 1: mensaje claro, sin traza
sparktune asesorar "Quiero programar apps Android" --local
sparktune explicar video-adobe --local
sparktune preparar android --simular
```

Para enseñar la validación, copia `acciones.json`, cambia un `tipo` por `borrar` y ejecuta `sparktune --config copia.json validar`: el código de salida es 3 y el mensaje indica `acciones[0].tipo`.

---

## C1 · Acciones predefinidas (20 %)

**Qué pide el nivel Excelente:** 5 o más acciones propias útiles, combinables, con salida clara y sin efectos sorpresa. Simulación previa o confirmación antes de escribir.

**Evidencia**

- Cinco acciones propias en [acciones.json](../acciones.json): `reunir-capturas`, `reunir-informes`, `guardar-planes` (tipo `copiar`), `inventariar` (tipo `inventario`) y `calcular-huellas` (tipo `huellas`). El perfil `preparar-entrega` las combina todas.
- Se combinan por perfil o con comas, y una acción repetida se ejecuta solo una vez: `Catalogo.seleccionar()` en [config.py:90](../src/sparktune/config.py).
- Salida clara: antes de ejecutar se muestra el plan (`Salida prevista: …`, y cada archivo con su destino). Las mismas líneas salen en la simulación y en la ejecución porque las produce el mismo método, `Plan.lineas()` en [motor.py:56](../src/sparktune/motor.py).
- Sin efectos sorpresa:
  - Los originales nunca se modifican. Todo se escribe en una carpeta nueva, `sparktune-salida`, o `-2`, `-3`… si ya existe ([motor.py:49](../src/sparktune/motor.py)).
  - Los archivos se abren con el modo `"xb"`, que falla si el destino ya existe, así que nunca se sobrescribe ([acciones.py:112](../src/sparktune/acciones.py)).
  - `--simular` no escribe nada. Sin `--si`, el programa pregunta `[s/N]` y Enter equivale a no ([dialogo.py](../src/sparktune/dialogo.py)).
  - Para deshacer, basta con borrar la carpeta de salida, como indica el propio mensaje final.
- Además, `preparar` ofrece 13 perfiles de Windows (WinGet y un ajuste de transparencia). Cada cambio se confirma por separado y, antes del primero, se crea un punto de restauración ([preparar.py:325](../src/sparktune/preparar.py)).

**Pruebas que lo respaldan:** `test_perfil_simulacion_y_ejecucion`, `test_ejecuciones_repetidas_y_combinacion`, `test_confirmacion_en_espanol` y todas las de `test_preparar.py`.

## C2 · Configuración externa (15 %)

**Qué pide el nivel Excelente:** el esquema está documentado, el JSON se valida antes de ejecutar indicando qué campo falla, añadir una acción no exige tocar el código y hay un ADR.

**Evidencia**

- Esquema documentado en el [README](../README.md#esquema-de-accionesjson), con una tabla de campos y reglas.
- Validación completa antes de ejecutar nada: `Catalogo.desde_archivo()` → `desde_datos()` → `Accion.desde_config()` ([config.py:44](../src/sparktune/config.py), [acciones.py:47](../src/sparktune/acciones.py)). Se comprueba lo siguiente:
  - Faltan o sobran campos ([esquema.py:11](../src/sparktune/esquema.py)).
  - Claves JSON repetidas: un gancho de `json.loads` impide que la segunda sobrescriba en silencio a la primera ([esquema.py:32](../src/sparktune/esquema.py)).
  - IDs portables: no pueden contener `../` ni ser un nombre reservado de Windows como `con`, porque se usan como nombres de carpeta.
  - Tipos válidos y extensiones con formato correcto y sin duplicados.
  - Perfiles que solo contienen acciones existentes y que no comparten nombre con una acción.
- Cada mensaje dice qué campo falla, por ejemplo `Falta el campo acciones[2].tipo.`. El código de salida es 3 y no se ejecuta nada.
- `--config` permite usar otro catálogo. Orden de búsqueda: la ruta de `--config`, `./acciones.json` y el catálogo empaquetado ([config.py:34](../src/sparktune/config.py)).
- **Añadir una acción no exige tocar el código:** `test_config_alternativa_y_local` crea la acción `manuales`, que solo existe en un JSON, y la ejecuta.
- Añadir un *tipo* nuevo (otra operación) sí requiere código: una subclase de `Accion`, que se registra sola gracias a `__init_subclass__` ([acciones.py:32](../src/sparktune/acciones.py)). Es una decisión deliberada: el JSON elige *qué* archivos procesar, pero no puede definir operaciones arbitrarias sobre el disco.
- El ADR es [docs/adr/0003-configuracion-externa.md](adr/0003-configuracion-externa.md). La rúbrica lo llama `0001`, pero aquí el 0001 ya era el ADR de la edición PowerShell, que tomó la misma decisión para los ajustes de Windows.

**Pruebas:** `test_config_alternativa_y_local`, los 13 casos de `test_errores_de_campos` y `test_tipo_nuevo_se_registra_sin_tocar_motor_ni_catalogo`.

## C3 · Capa de IA, secretos y modo sin red (15 %)

**Qué pide el nivel Excelente:** al menos 2 acciones de IA útiles, ninguna clave en el historial y, sin red, la CLI lo explica y sigue con las acciones sin IA.

**Evidencia**

- Hay tres órdenes de IA en [ia.py](../src/sparktune/ia.py):
  - `asesorar` elige un perfil según el objetivo descrito.
  - `explicar` relaciona un perfil con la RAM, el disco y la batería medidos.
  - `comprobar-ia` verifica la clave y el modelo.
- Proveedor: Groq con el modelo fijo `openai/gpt-oss-120b` ([proveedores.py:114](../src/sparktune/proveedores.py)).
- La clave se lee de la variable `GROQ_API_KEY` o de un archivo indicado explícitamente con `--env-file`. **No se lee ningún `.env` de forma implícita**, para que una carpeta ajena no pueda colar una clave. Existe [.env.example](../.env.example), y `.env` y `.env.*` están en `.gitignore`.
- Sin red, sin clave o con una respuesta inválida, el programa muestra el motivo en stderr y responde con `ProveedorLocal`, que usa reglas sin red ([ia.py:18](../src/sparktune/ia.py) y 39-43). `--local` evita la red por completo. Las acciones de archivos y `preparar` no dependen de la IA.
- Seguridad de la capa:
  - El modelo solo puede elegir un perfil del catálogo y redactar un motivo. Los paquetes y la forma de revertirlos salen siempre de `preparar.propuesta()`, nunca del modelo.
  - El texto del modelo se limpia de secuencias ANSI y caracteres de control (`texto_seguro`).
  - Si el objetivo parece contener una ruta, un correo o una clave, no se envía a Groq (`contiene_datos_privados`).
  - La clave se guarda como `self.__clave`, con nombre privado, y solo viaja en la cabecera `Authorization`.
- Los prompts y sus decisiones de diseño están en [docs/prompts.md](prompts.md).

**Punto débil, explícalo con sinceridad:** `.env` está en `.gitignore` desde el commit `856e745` (25 de noviembre), no desde el primer commit. Nunca se subió ningún `.env` ni ninguna clave, como muestra la orden de la puerta de entrada.

**Pruebas:** las 20 de `test_ia.py`.

## C4 · Robustez (15 %)

**Qué pide el nivel Excelente:** excepciones propias, ningún traceback ante errores previsibles, nunca se pierde un fichero por un fallo a medias y se usan aserciones en desarrollo.

**Evidencia**

- Excepciones propias en [errores.py](../src/sparktune/errores.py), cada una con su código de salida:

  | Excepción | Código | Cuándo se lanza |
  | --- | --- | --- |
  | `ConfigError` | 3 | El catálogo no es válido. |
  | `AccionNoValida` | 2 | Se pide una acción o un perfil desconocidos. |
  | `ErrorEjecucion` | 1 | La carpeta no sirve o un archivo cambió. |
  | `ErrorIA` | 1 | El proveedor de IA no está disponible o responde algo inutilizable. |

- Ningún traceback: `errores_cli()` convierte `ErrorSparkTune`, `OSError` y `UnicodeError` en `Error: …` en stderr y en el código de salida que corresponde ([cli.py:42](../src/sparktune/cli.py)). Typer tiene desactivadas las trazas decoradas (`pretty_exceptions_enable=False`).
- Nunca se pierde un fichero:
  - Los originales solo se leen.
  - Cada archivo se abre sin seguir enlaces (`O_NOFOLLOW`), y se comprueba que es el mismo que se vio en el plan antes de leerlo, al abrirlo y al terminar ([ficheros.py:59-73](../src/sparktune/ficheros.py)).
  - Si algo falla a medias, la salida queda marcada con `.incompleto` y el mensaje dice que los originales se conservan ([motor.py:59](../src/sparktune/motor.py)).
  - `mkdir` sin `exist_ok` reserva la salida, de modo que dos ejecuciones simultáneas no escriben en la misma carpeta.
- Entradas raras:
  - Rutas con enlaces o `..`, que se rechazan (excepto los enlaces de root del sistema, como `/tmp` en macOS).
  - Nombres que chocarían en Windows o macOS, como `Foto.PNG` y `foto.png`, y nombres no portables.
  - Salida redirigida con `cp1252` en Windows.
  - Respuestas de confirmación inesperadas, que se vuelven a pedir.
  - Objetivos de IA demasiado largos.
- En `preparar`, si una instalación falla a medias, el programa se detiene e indica cómo deshacer solo lo que sí se aplicó ([preparar.py:379](../src/sparktune/preparar.py)).
- Aserciones en desarrollo: [config.py:19-20](../src/sparktune/config.py) y [motor.py:40](../src/sparktune/motor.py). Comprueban invariantes que ya garantizan las fábricas. Las entradas del usuario no se validan con `assert`, porque `python -O` desactiva las aserciones: para eso está `ConfigError`.

**Pruebas:** `test_errores_de_uso_y_ruta`, `test_no_sigue_enlaces_y_reserva_otra_salida`, `test_cambio_posterior_al_plan_y_carrera_destino`, `test_dos_nombres_no_portables_no_llegan_a_la_salida`, `test_ruta_inexistente_da_mensaje_claro`, `test_salida_redirigida_con_codificacion_antigua`, `test_error_instalando_interrumpe_lote` y `test_fallo_a_medias_explica_como_revertir_lo_aplicado`.

## C5 · Diseño en clases y módulos (10 %)

**Qué pide el nivel Excelente:** responsabilidades separadas (interfaz, motor, acciones, proveedor de IA), visibilidad cuidada y métodos estáticos con sentido, como las fábricas.

**Evidencia** (la tabla completa de módulos está en el [README](../README.md#estructura)):

- Interfaz: `cli.py` e `ia.py`. Son las órdenes de Typer y lo único que escribe en pantalla en la parte de archivos.
- Configuración: `config.py` (`Catalogo`) y `esquema.py`.
- Acciones: `acciones.py`, con la clase abstracta `Accion` y las subclases `Copiar` y `AccionInforme`, de la que heredan `Inventario` y `Huellas`.
- Motor: `motor.py` (`Plan`, `Paso`) y `ficheros.py` (`Entrada`).
- Proveedor de IA: `proveedores.py`, con la clase abstracta `ProveedorIA` y las implementaciones `ProveedorGroq` y `ProveedorLocal`. La interfaz trabaja con `ProveedorIA` y cambia de uno a otro sin condiciones especiales.
- Fábricas estáticas: `Catalogo.desde_archivo()`, `Catalogo.desde_datos()`, `Accion.desde_config()`, `Plan.preparar()`, `Plan.desde_entradas()` y `ProveedorGroq.desde_entorno()`.
- Visibilidad:
  - `_acciones` y `_perfiles` son internos, y las propiedades devuelven copias.
  - `__clave` usa el *name mangling* de Python, así que no se puede leer como `proveedor.clave`.
  - `Plan`, `Paso` y `Entrada` son dataclasses inmutables (`frozen=True`).
- Extensibilidad: un tipo nuevo es una subclase con `tipo`, `describir()` y `escribir()`. El motor no cambia.

**Punto débil:** [preparar.py](../src/sparktune/preparar.py) (399 líneas) usa funciones, no clases, y mezcla la salida en pantalla con la lógica de WinGet y el punto de restauración. Además, sus perfiles están en Python y no en JSON. Lo segundo es deliberado: las instalaciones forman un catálogo cerrado y revisado en el código, para que nadie pueda añadir paquetes sin una revisión. Lo primero es una mejora posible.

## C6 · Pruebas y calidad (15 %)

**Qué pide el nivel Excelente:** el camino feliz y al menos 3 casos feos, ejecutados en GitHub Actions y auditados por el alumno, que sabe explicar cada aserción.

**Evidencia**

- 71 pruebas `pytest` en tres archivos (30 + 23 + 18). Todas usan `tmp_path` o simulan WinGet, PowerShell y Groq, así que no tocan el equipo ni la red.
- Hay decenas de casos feos: los 13 errores de esquema, enlaces, carreras, colisiones, codificación, HTTP 401/429, timeout, respuestas inventadas del modelo, instalaciones fallidas…
- [.github/workflows/python.yml](../.github/workflows/python.yml) ejecuta `uv sync --locked` y `pytest` en Ubuntu, Windows y macOS. Después construye el wheel y lo instala en una carpeta limpia con [scripts/probar_wheel.py](../scripts/probar_wheel.py), que prueba la ayuda, el catálogo, la simulación, la ejecución y la desinstalación.
- [.github/workflows/ci.yml](../.github/workflows/ci.yml) mantiene las pruebas de la edición PowerShell 1.x, incluida una integración real con `powercfg` en un runner Windows desechable.
- La auditoría es la sección «Qué comprueba cada prueba» de este documento.

## C7 · Instalación, documentación y proceso (10 %)

**Qué pide el nivel Excelente:** se instala con una orden siguiendo el README, hay una release etiquetada con changelog y un historial de ramas y PR legible.

**Evidencia**

- Una orden: `uv tool install git+https://github.com/josemidev1-code/CLI-SPARKTUNE`. El comando `sparktune` queda disponible en cualquier carpeta, porque es el punto de entrada `[project.scripts]` de [pyproject.toml](../pyproject.toml).
- [CHANGELOG.md](../CHANGELOG.md) con formato Keep a Changelog, y etiquetas `v1.1.0`…`v1.8.0` de la edición 1.x.
- Proceso: PR #3 desde una rama, commits pequeños y legibles, [AGENTS.md](../AGENTS.md), [opencode.json](../opencode.json) (no deja leer `.env` ni hacer `git push`), y `.opencode/` con un agente revisor de solo lectura (`mode: all`, para que `scripts/revisar.sh` pueda lanzarlo como agente principal), el comando `/nueva-accion` y la skill `acciones-json`. También [scripts/revisar.sh](../scripts/revisar.sh), [docs/prompts.md](prompts.md) y los ADR.

- Release [SparkTune 2.0.0](https://github.com/josemidev1-code/CLI-SPARKTUNE/releases/tag/v2.0.0): la etiqueta `v2.0.0` apunta al merge commit del PR #3 y sus notas son la entrada 2.0.0 del CHANGELOG.
- El PR #3 se fusionó con merge commit, así que `main` conserva cada commit pequeño de la rama y se puede enseñar el historial cambio a cambio.

**Pendiente antes de entregar** (en [RELEVO.md](RELEVO.md)): completar las sesiones con ChatGPT y Codex en `docs/prompts.md`.

---

## Qué comprueba cada prueba

Para ejecutar una sola prueba: `uv run pytest -q tests/test_archivos.py::test_perfil_simulacion_y_ejecucion`, o `.venv/bin/python -m pytest` si `uv` no está en el PATH.

Estas son las herramientas de pytest que aparecen en las pruebas:

- `tmp_path` es una carpeta temporal nueva para cada prueba.
- `monkeypatch` sustituye una función o una variable de entorno durante la prueba y la restaura al terminar.
- `CliRunner` de Typer ejecuta la CLI dentro del proceso y captura `stdout`, `stderr` y el código de salida.
- `parametrize` repite la misma prueba con varios datos: cada combinación cuenta como una prueba.

### tests/test_archivos.py · 30 pruebas

Prueban el catálogo, el motor y las acciones de archivos.

**`test_tabla_y_json_por_defecto`** (línea 20). Crea `álbum.txt` (4 bytes) y una carpeta vacía, y ejecuta `listar` sin ruta.
- `exit_code == 0` y el JSON se puede leer: sin argumento, `listar` usa la carpeta actual.
- `bytes == 4`: el tamaño es el real.
- `utcoffset() == 0`: las fechas se dan en UTC con formato ISO, así que no dependen de la zona horaria del equipo.
- `tipo == "carpeta"`: se distinguen las carpetas de los archivos.
- La tabla tiene la cabecera `MODIFICADO (UTC)` y muestra el nombre con tilde, así que el UTF-8 se conserva.

**`test_perfil_simulacion_y_ejecucion`** (línea 35). Es el camino feliz completo del perfil `preparar-entrega`, con cuatro archivos y una subcarpeta.
- Tras `--simular`, la carpeta contiene exactamente lo mismo que antes: la simulación no escribe nada.
- Responder `n` termina con código 0 y `Cancelado`. Cancelar no es un error.
- La parte del plan es idéntica en la simulación y en la ejecución: lo que se ve es lo que se hace.
- Cada copia tiene el contenido exacto. `Foto.PNG` entra en `reunir-capturas` aunque la extensión esté en mayúsculas.
- `inventario.json` y `sha256.json` contienen exactamente los cuatro archivos, con su tamaño y una huella que coincide con la de `hashlib`. La subcarpeta `ignorada` no entra: solo se procesa el nivel inmediato.
- No queda `.incompleto` y los originales no han cambiado.

**`test_ejecuciones_repetidas_y_combinacion`** (línea 65). Ejecuta `reunir-informes,inventariar,reunir-informes` dos veces.
- La primera termina con código 0 aunque `reunir-informes` aparece dos veces. Si se ejecutara dos veces, el segundo `mkdir` fallaría, así que esto demuestra que las acciones repetidas se eliminan.
- La segunda ejecución crea `sparktune-salida-2` con el contenido nuevo, y la primera salida conserva el antiguo: nunca se sobrescribe.

**`test_config_alternativa_y_local`** (línea 76).
- Hay un `./acciones.json` roto en la carpeta actual. `validar`, `acciones` y `ejecutar` terminan con código 3, nombran el archivo en stderr y dejan stdout vacío. El catálogo local tiene prioridad y, si no es válido, no se ejecuta nada.
- Con `--config` y otro JSON, `validar` termina con código 0 y `acciones --json` devuelve exactamente ese catálogo.
- La acción `manuales`, definida solo en el JSON, copia `README.md`. Añadir una acción no exige tocar el código.

**`test_errores_de_campos`** (línea 115; 13 casos). Parte del catálogo real, estropea un solo campo y comprueba tres cosas: el código es 3, stderr nombra el campo y stdout está vacío.

| Campo estropeado | Por qué debe fallar |
| --- | --- |
| `version: true` | En Python, `True` es un `int`. Por eso se comprueba con `type() is int`. |
| `acciones: {}` | Debe ser una lista no vacía. |
| `id: "../fuera"` | Saldría de la carpeta de salida (*path traversal*). |
| `id: "con"` | Es un nombre reservado de Windows y no se puede crear una carpeta así. |
| `descripcion: null` | Es obligatoria y debe ser texto visible. |
| `tipo: "borrar"` | Solo existen los tipos registrados. |
| `extensiones: []` | `copiar` necesita al menos una extensión. |
| `extensiones: [".pdf", ".pdf"]` | Hay duplicados. |
| `extensiones: [true]` | No es texto. |
| campo `extra` | No se aceptan campos desconocidos, para detectar errores de escritura. |
| `perfiles: []` | Debe ser un objeto. |
| un perfil con `inexistente` | La acción no existe. |
| un perfil llamado `reunir-capturas` | Coincide con una acción, y `ejecutar reunir-capturas` sería ambiguo. |

**`test_errores_de_uso_y_ruta`** (línea 129).
- Una acción desconocida da el código 2 y un mensaje con «desconocid».
- Una ruta inexistente en `listar` y en `ejecutar` da el código 1 y nombra la ruta en stderr.
- `--config` con un archivo inexistente da el código 3.
- `tmp_path` sigue vacía: ningún error crea archivos.

**`test_no_sigue_enlaces_y_reserva_otra_salida`** (línea 142). Se omite si el sistema no permite crear enlaces.
- `enlace.txt` apunta a un archivo privado fuera del proyecto. La carpeta `reunir-informes` queda vacía: no se sigue el enlace.
- `sparktune-salida` es un enlace roto. Se usa `-2` y el destino del enlace no se crea, así que no se escribe a través del enlace.
- Si la propia carpeta de trabajo es un enlace, se rechaza con el código 1 y un mensaje con «enlace».

**`test_cambio_posterior_al_plan_y_carrera_destino`** (línea 162). Usa la API directamente.
- Se prepara el plan y después cambia el archivo. `aplicar()` lanza `ErrorEjecucion` con «incompleta», porque el archivo ya no coincide con la vista previa.
- Queda `.incompleto` y el original conserva su contenido nuevo: no se borra ni se restaura.
- Un segundo `aplicar()` del mismo plan lanza `FileExistsError`. La salida ya está reservada y dos ejecuciones nunca se mezclan.

**`test_dos_nombres_no_portables_no_llegan_a_la_salida`** (línea 176). Introduce `Foto.PNG` y `foto.png` a la vez (en macOS y Windows sería el mismo archivo).
- Se lanza `ErrorEjecucion` con «colisión» y no se crea `sparktune-salida`: el error se detecta al preparar el plan, antes de escribir.

**`test_firma_coincide_al_abrir_el_archivo`** (línea 187). Es una regresión de Windows: `lstat` y `fstat` devuelven el identificador del archivo con anchuras distintas.
- La firma de un archivo intacto coincide al abrirlo y la lectura devuelve su contenido. Sin la corrección, todas las copias fallaban en Windows.

**`test_salida_redirigida_con_codificacion_antigua`** (línea 200). Ejecuta el programa en un proceso aparte con `PYTHONIOENCODING=cp1252`, como al redirigir la salida en Windows.
- Termina con código 0 y stdout contiene «→» y «diagnóstico» en UTF-8. `usar_utf8()` evita un `UnicodeEncodeError`.

**`test_tipo_nuevo_se_registra_sin_tocar_motor_ni_catalogo`** (línea 213).
- Define en la propia prueba una subclase `Contar` con `tipo = "contar"`. La usa un catálogo, el plan muestra sus líneas y `aplicar()` escribe `total.txt` con `1`.
- `monkeypatch` copia el registro `_tipos` para que `contar` no se quede registrado en otras pruebas.

**`test_ruta_inexistente_da_mensaje_claro`** (línea 237).
- El mensaje es `No existe la carpeta` y no contiene `Errno`: es un mensaje para personas, no el error del sistema operativo.

**`test_acepta_enlaces_del_sistema_como_tmp`** (línea 243). Solo se ejecuta en macOS, donde `/tmp` es un enlace de root.
- Una carpeta bajo `/tmp` funciona. Sin esta excepción, la protección contra enlaces bloquearía un uso normal. Un usuario sin privilegios no puede crear enlaces de root.

**`test_confirmacion_en_espanol`** (línea 257; 4 casos).
- `s` y `sí` crean la salida. Enter no la crea, porque el valor por defecto es no. `quizá` hace que se vuelva a preguntar, y la respuesta `n` siguiente cancela.
- La pregunta muestra `[s/N]`. La mayúscula indica la respuesta por defecto.

### tests/test_ia.py · 23 pruebas

Preparación común (fixture `cli`):
- Ejecuta en una carpeta temporal y quita `GROQ_API_KEY`.
- Fija el equipo: Windows, 8 GiB de RAM, con batería y desenchufado.
- **Sustituye la conexión HTTPS por una función que hace fallar la prueba.** Cualquier prueba que no prepare un Groq simulado demuestra así que no se ha intentado usar la red.

`simular_groq` crea un servidor falso. Comprueba que el destino es `api.groq.com`, que el tiempo de espera no pasa de 30 s y que la ruta es `POST /openai/v1/chat/completions`. Además, guarda cada petición para inspeccionarla. Con el estado 0 simula un timeout.

**`test_asesor_local_elige_perfil_sin_leer_env_implicito`** (línea 64). Hay un `.env` con una clave en la carpeta actual.
- La recomendación es local y sugiere `preparar android --simular`. El `.env` no se lee solo, y como no hay clave no se intenta la red: si se intentara, fallaría la prueba.

**`test_explicacion_local_interpreta_equipo`** (línea 72). Hay una clave, pero se usa `--local`.
- No se conecta. La explicación menciona los 8 GiB de RAM, la batería y la edición en baja resolución: interpreta el equipo medido.

**`test_perfil_invalido_no_hace_consulta`** (línea 80).
- Un perfil inventado termina con un código distinto de 0 y remite a `perfiles`. No se consulta a Groq.

**`test_asesor_groq_procesa_solo_perfil_del_catalogo`** (línea 85). La clave está entre comillas en un archivo indicado con `--env-file`, y la respuesta incluye la secuencia ANSI `\x1b[2J`, que borraría la pantalla.
- Se recomienda el perfil que eligió el modelo.
- El motivo aparece sin `\x1b`, porque `texto_seguro` limpia la respuesta.
- La petición usa `openai/gpt-oss-120b` y la cabecera `Bearer gsk_ejemplo`, con las comillas quitadas.
- **Ni la clave ni la ruta del archivo aparecen en el cuerpo enviado.**

**`test_datos_invalidos_del_modelo_recuperan_recomendacion_local`** (línea 100; 2 casos). El modelo devuelve un perfil inventado o no devuelve motivo.
- Se muestra la recomendación local, con `android`, y nunca el texto «Inválido» del modelo.

**`test_objetivos_con_datos_privados_se_tratan_localmente`** (línea 111; 5 casos). El objetivo contiene la ruta `C:\Users\ana\privado`, un token `gsk_secreta`, «contrasena» sin tilde, «pwd» o un «PIN». Antes de buscar, el texto se pasa a minúsculas y se le quitan las tildes, así que «CONTRASEÑA» y «contrasena» se detectan igual.
- Se responde en local y el objetivo no se repite en la salida. Groq no está simulado, así que la prueba también demuestra que no se envió nada.

**`test_explicar_groq_presenta_prioridad_y_primer_paso`** (línea 118).
- Se muestran la prioridad y el primer paso, y la petición incluye `ram_gib`: el modelo recibe los recursos medidos.

**`test_comprobar_distingue_fallos_sin_revelar_clave`** (línea 127; 3 casos).
- Un 401 habla de la clave, un 429 del límite y un timeout de la conexión. Todos terminan con el código 1 y ninguno muestra la clave.

**`test_comprobar_verifica_el_modelo`** (línea 135).
- Con la respuesta `{"estado": "ok"}`, termina con código 0 y muestra el nombre del modelo.

**`test_selecciona_edicion_adobe_frente_a_video_generico`** (línea 142). En «Editar vídeos con Adobe», «adobe» coincide con `video-adobe` y «videos» (sin tilde tras normalizar) con `video-libre`: es un empate de 1 a 1.
- Gana `video-adobe` porque solo una coincidencia mayor desplaza a la anterior, y `video-adobe` va antes en el vocabulario. Es intencionado: la mención de una marca concreta debe ganar al término genérico.

**`test_orientacion_android_con_poca_ram_es_especifica`** (línea 147).
- Con 8 GiB, el consejo para Android propone probar la app en un teléfono en lugar del emulador. No es un consejo genérico.

**`test_objetivo_no_se_recorta_a_mitad`** (línea 152). El objetivo tiene unos 720 caracteres.
- La frase final llega a la petición. El límite para el objetivo es de 1200 caracteres, no los 600 que `texto_seguro` usa por defecto.

**`test_consulta_no_envia_clave_literal_fuera_de_cabecera`** (línea 162). El objetivo contiene la clave configurada, `privada1234`, que no tiene forma de token.
- Se responde en local. La segunda barrera de `_consultar` detecta la clave literal antes de enviar nada, y Groq no está simulado.

**`test_desarrollo_movil_sin_mencionar_android`** (línea 168). El objetivo es «aplicaciones móviles».
- Se recomienda `android`, porque coinciden «moviles» y «aplicaciones moviles» (2 términos), mientras que «programar» solo da 1 a `desarrollo`.

**`test_propuesta_dice_que_cambia_por_que_y_como_revertir`** (línea 173).
- La salida contiene el porqué (las palabras citadas), el equipo, cada instalación con su orden `winget uninstall` exacta, el punto de restauración y la frase «Todavía no se ha aplicado nada».

**`test_el_modelo_no_decide_cambios_ni_reversion`** (línea 182). El modelo devuelve además `paquetes: ["Malware.Falso"]` y `deshacer: "format C:"`.
- Se muestran el perfil y el motivo del modelo, pero ni `Malware.Falso` ni `format C:`.
- Las líneas «Cómo revertirlo» son exactamente las dos del catálogo, las de LibreOffice y Firefox. **El modelo solo elige; SparkTune decide qué se instala.**

### tests/test_preparar.py · 18 pruebas

Preparación común (fixture `invocar`): equipo Windows AMD64 con 16 GiB de RAM, 120 GiB libres y sin batería. Además, simula WinGet y desactiva la comprobación de transparencia. Ninguna prueba instala nada ni crea puntos de restauración reales.

**`test_catalogo_y_perfil_desconocido`** (línea 28).
- `perfiles` lista `android`, `video-adobe` y `ofimatica`.
- `preparar "git;whoami"` se rechaza: un intento de inyección no es un perfil.

**`test_plan_sin_cambios`** (línea 39; 3 casos). En macOS y Linux sin opciones, y en Windows con `--simular`.
- `subprocess.run` está sustituido por un fallo, así que **no se ejecuta ningún proceso**. La salida explica Creative Cloud, la licencia, Premiere y After Effects. Así se cumple la regla de AGENTS.md: leer y simular no cambia el equipo.

**`test_plan_android_adaptativo`** (línea 48).
- Con 8 GiB de RAM y 12 GiB libres, se instala Android Studio (el mínimo es 8 y 8) y se recomienda un teléfono en lugar del emulador.
- Con 32 GiB y 96 GiB, se proponen Device Manager y comprobar la virtualización.
- Con ARM64, Android Studio no se incluye, porque la instalación local para Windows requiere x64.

**`test_rechazar_todo_no_crea_punto`** (línea 60).
- Si se responde Enter a todo, se muestra «Sin cambios» y no se ejecuta ningún proceso, ni siquiera el punto de restauración.

**`test_un_punto_para_cambios_aceptados`** (línea 67). Se aceptan las dos instalaciones de `ofimatica`.
- El primer evento es `punto` y hay 3 eventos en total: **un solo punto antes del primer cambio** y dos instalaciones.
- Cada llamada es `winget install --id <paquete> --exact --source winget --no-upgrade`. `--exact` evita instalar otro paquete con un nombre parecido, `--source winget` evita la tienda y `--no-upgrade` no actualiza lo que ya está instalado.

**`test_fallo_de_proteccion_impide_instalar`** (línea 86).
- Si no se puede crear el punto, termina con el código 1, muestra el motivo y no se instala nada.

**`test_verificar_secuencia_y_descripcion`** (línea 99; 3 casos). Prueba `_crear_punto()` con PowerShell simulado.
- Si el único punto es el que ya existía (secuencia 17), no se acepta.
- Si hay un punto nuevo con otra descripción, por ejemplo de Windows Update, tampoco.
- Solo se acepta un punto con una secuencia nueva y la descripción `SparkTune-<uuid>`.
- Windows puede no crear el punto sin avisar, por ejemplo por el límite de 24 horas, y SparkTune no debe dar por hecho que existe.

**`test_error_instalando_interrumpe_lote`** (línea 113). WinGet devuelve 7.
- Termina con el código 1, nombra LibreOffice y solo hay una llamada: Firefox no se intenta después de un fallo.

**`test_ajuste_condicional_tambien_necesita_punto`** (línea 123). Con batería y desenchufado, se ofrece desactivar la transparencia. Se rechazan las instalaciones y se acepta el ajuste.
- Los eventos son, en orden, `punto` y `transparencia`: un ajuste del registro también va precedido del punto. La salida explica cómo revertirlo en Personalización.

**`test_contexto_no_incluye_datos_personales`** (línea 136). Usa el equipo real que ejecuta la prueba.
- Las claves son exactamente sistema, arquitectura, núcleos, RAM, disco, batería y enchufado. No hay usuario, nombre de equipo ni rutas, y el resultado se puede convertir a JSON. Esto es lo que se envía a Groq.

**`test_fallo_a_medias_explica_como_revertir_lo_aplicado`** (línea 143). LibreOffice se instala y Firefox falla.
- Después de «Preparación detenida», el programa indica cómo desinstalar LibreOffice, no menciona Firefox y recuerda Restaurar sistema.

**`test_aplicacion_ya_instalada_no_se_ofrece_deshacer`** (línea 156). WinGet responde que Firefox ya está instalado (`0x8A150061`) y `winget list` lo confirma.
- Después de «Mozilla.Firefox ya estaba instalado.», Firefox no vuelve a aparecer y no hay lista «Cambios aplicados». Si la hubiera, quien la siguiera desinstalaría un programa que ya tenía.
- Antes de la corrección, `_instalar` no distinguía entre instalar y encontrar el programa ya instalado. Ahora devuelve `True` o `False`, y solo lo instalado entra en la lista para deshacer.

**`test_estado_de_carga_desconocido_no_se_muestra_como_enchufado`** (línea 173). Comprueba `resumen_equipo` con batería y `enchufado=None`, que es lo que devuelve psutil cuando Windows no informa del cargador.
- El resumen dice «con batería, estado de carga desconocido» y no «enchufado». Antes, cualquier valor distinto de `False` se mostraba como «enchufado».

**`test_vista_previa_incluye_como_deshacer`** (línea 182).
- `preparar gaming --simular` muestra cómo desinstalar Steam, el aviso de Restaurar sistema y «Simulación terminada».

---

## Preguntas probables

**¿Por qué no se usa la IA para decidir qué instalar?** Un modelo puede inventar paquetes o recibir instrucciones ocultas en el objetivo. El modelo solo elige un ID que tiene que estar en el catálogo, y las órdenes salen siempre del código de SparkTune. Lo demuestra `test_el_modelo_no_decide_cambios_ni_reversion`.

**¿Qué pasa si no hay red?** `asesorar` y `explicar` muestran el motivo en stderr y responden con `ProveedorLocal`, con el código 0. `comprobar-ia` termina con el código 1, porque su única tarea es comprobar la conexión. Las acciones de archivos y `preparar --simular` no usan la red.

**¿Por qué no se lee el `.env` automáticamente?** Si se ejecuta SparkTune en la carpeta de otra persona, su `.env` podría enviar las consultas a otra cuenta. Por eso solo se usa la variable de entorno o un archivo indicado expresamente con `--env-file`.

**¿Cómo se garantiza que nunca se pierde un archivo?** Los originales solo se abren en modo lectura, la salida va a una carpeta nueva, `"xb"` no sobrescribe y una ejecución fallida queda marcada con `.incompleto`. Además, se comprueba que cada archivo no ha cambiado desde el plan.

**¿Por qué hay aserciones si ya se valida?** Las aserciones documentan invariantes internos, cosas que no pueden ocurrir si las fábricas funcionan, y fallan durante el desarrollo si alguien rompe el código. Lo que escribe el usuario se valida con excepciones, porque `python -O` desactiva las aserciones.

**¿Por qué Python si la 1.x era PowerShell?** La rúbrica pide Python, Typer y uv, y la parte de archivos y de IA sirve en los tres sistemas. Lo que solo existe en Windows (WinGet, el registro y los puntos de restauración) se aísla en `preparar.py`. Está explicado en el [ADR 0002](adr/0002-python-y-proveedor-ia.md).

**¿Cómo se añade una acción?** Con una entrada nueva en `acciones.json` de un tipo existente, y después `sparktune validar`. Un tipo nuevo requiere una subclase de `Accion`, como en `test_tipo_nuevo_se_registra_sin_tocar_motor_ni_catalogo`.

## Puntos débiles conocidos

Conviene saberlos antes de que te pregunten por ellos:

1. `.env` no estaba en `.gitignore` en el primer commit, aunque nunca se subió ninguna clave.
2. `preparar.py` no está organizado en clases y mezcla la salida en pantalla con la lógica.
3. No hay una prueba específica de `asesorar` con un fallo de red. Ese camino sí está cubierto con datos inválidos del modelo y en `comprobar-ia` con timeout, y el código que lo trata es el mismo (`except ErrorIA`). El caso 1.5 del guion de Windows lo comprueba a mano.
4. Las pruebas de Windows usan simulaciones. El guion para un portátil físico está en [PRUEBA-WINDOWS.md](PRUEBA-WINDOWS.md), pero todavía no se ha ejecutado: es el pendiente 1 de RELEVO.
5. En la edición 1.x, 52 acciones no guardaban el estado anterior real. Ahora están en revisión y no se ofrecen, pero no se han corregido ([REVISION.md](REVISION.md)). Si preguntan: se dejan en el catálogo para que quien las aplicó con una versión anterior pueda seguir deshaciéndolas, `tests/safety-tests.ps1` comprueba que `undo` sigue deshaciendo una de ellas, y `tests/run-tests.ps1` impide ofrecer una acción reversible nueva que no guarde su estado.
6. Al escribir el guion de Windows aparecieron dos errores de `preparar`, ya corregidos con su prueba: una aplicación que ya estaba instalada aparecía en «Cambios aplicados y cómo deshacerlos», y un estado de carga desconocido se mostraba como «enchufado». Si preguntan, es un buen ejemplo de por qué hace falta probar en un equipo real además de con dobles.
