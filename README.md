# SparkTune

SparkTune prepara un entorno de trabajo para quien estudia, programa, juega o edita vídeo. Puedes describir tu objetivo o elegir un perfil directamente. El CLI en Python funciona en Windows, Linux y macOS. La instalación de aplicaciones mediante WinGet y los ajustes de Windows se aplican desde Windows.

## Instalación

Con [uv](https://docs.astral.sh/uv/getting-started/installation/) y [Git](https://git-scm.com/downloads) instalados, ejecuta en cualquier carpeta (uv necesita Git para instalar desde una URL `git+https`; en Windows puedes instalarlo con `winget install --id Git.Git --exact`):

```console
uv tool install git+https://github.com/josemidev1-code/CLI-SPARKTUNE
```

Si ya tienes el repositorio clonado, `uv tool install .` en su carpeta instala la misma versión.

Desde otra carpeta, comprueba `sparktune version` y `sparktune --help`. Si la terminal no encuentra el comando, ejecuta `uv tool update-shell` y vuelve a abrirla. Si tenías SparkTune 1.x, comprueba con `Get-Command sparktune -All` que estás ejecutando la versión 2. Para desinstalarla usa `uv tool uninstall sparktune`. La documentación de la edición PowerShell 1.x está en [docs/POWERSHELL.md](docs/POWERSHELL.md).

## Asistente para toda la familia

Ejecuta `sparktune` sin nada más. El asistente te saluda y te pregunta qué vas a hacer con el ordenador, por ejemplo «ver series con batería» o «programar en Python». Después te dice qué plan de energía pondría, por qué y qué valores cambiaría. Si tu uso encaja con un entorno de trabajo, también te ofrece los programas. Solo cambia algo si respondes que sí, y todo se puede deshacer. Con `GROQ_API_KEY` el saludo y la recomendación los hace Groq; con `--local` o sin clave se usan las reglas locales.

## Planes de energía según el uso

```console
sparktune energia planes
sparktune energia recomendar "Portátil gaming, voy a ver series y se me acaba la batería"
sparktune energia aplicar series-bateria --simular
sparktune energia aplicar maximo-portatil
sparktune energia restaurar
```

Hay cinco planes: `series-bateria`, `ofimatica-bateria`, `programar`, `equilibrado` y `maximo-portatil`. En un sobremesa no se ofrecen los de portátil. La IA solo elige uno de ellos: los valores de CPU, pantalla y suspensión los fija SparkTune. `aplicar` duplica el plan Equilibrado de Windows con `powercfg`, cambia esos valores y lo activa. Si aplicas otro plan al cambiar de uso, sustituye al anterior. `restaurar` vuelve al plan que tenías antes del primero y borra el de SparkTune. El estado se guarda en `~/.sparktune/energia.json`. `recomendar` también lista las apps abiertas que más memoria usan, para que decidas si cerrarlas: SparkTune no las cierra.

## Primeros cinco minutos

```console
sparktune
sparktune energia recomendar "ver series con batería" --local
sparktune perfiles
sparktune asesorar "Desarrollo aplicaciones Android y mi portátil tiene poca memoria"
sparktune preparar android --simular
sparktune explicar video-adobe
sparktune listar . --json
sparktune acciones
sparktune validar
```

## Acciones de archivos

Las acciones trabajan sobre la carpeta que indiques (por defecto, la actual). Nunca modifican ni borran los originales: el resultado se escribe en una carpeta nueva, `sparktune-salida`, dentro de esa carpeta. Si ya existe, se usa `sparktune-salida-2`, `-3`, etc.

```console
sparktune ejecutar reunir-capturas ~/pruebas --simular
sparktune ejecutar reunir-informes,inventariar ~/pruebas
sparktune ejecutar preparar-entrega ~/pruebas --si
```

- `--simular` muestra qué archivos se copiarían o incluirían y no escribe nada.
- Sin opciones, SparkTune muestra el plan y pregunta antes de crear la salida.
- `--si` confirma sin preguntar, para scripts.
- Puedes combinar acciones separándolas por comas o usar un perfil del catálogo.
- Para deshacer, descarta la carpeta de salida. Si una ejecución falla a medias, la salida conserva un archivo `.incompleto` y los originales quedan intactos.

## Esquema de `acciones.json`

SparkTune busca el catálogo en este orden: la ruta de `--config`, `./acciones.json` en la carpeta actual y el catálogo incluido en el paquete.

```console
sparktune --config mis-acciones.json validar
sparktune --config mis-acciones.json ejecutar mi-accion ~/pruebas --simular
```

```json
{
  "version": 1,
  "acciones": [
    {
      "id": "reunir-capturas",
      "descripcion": "Copia las capturas e imágenes del proyecto.",
      "tipo": "copiar",
      "extensiones": [".png", ".jpg"]
    }
  ],
  "perfiles": {
    "preparar-entrega": ["reunir-capturas"]
  }
}
```

| Campo | Obligatorio | Regla |
| --- | --- | --- |
| `version` | Sí | El entero `1`. |
| `acciones` | Sí | Lista no vacía de acciones. |
| `acciones[].id` | Sí | Único. De 1 a 48 caracteres: minúsculas ASCII, números o guiones, empezando por letra. No puede ser un nombre reservado de Windows (`con`, `nul`…). |
| `acciones[].descripcion` | Sí | Texto visible, sin caracteres de control. |
| `acciones[].tipo` | Sí | `copiar` (copia los archivos a `<id>/`), `inventario` (crea `<id>/inventario.json` con nombres y tamaños) o `huellas` (crea `<id>/sha256.json` con la huella SHA-256 de cada archivo). |
| `acciones[].extensiones` | Sí | Lista de extensiones en minúsculas, como `".png"`, sin repetir. `copiar` necesita al menos una; en `inventario` y `huellas`, una lista vacía incluye todos los archivos. |
| `perfiles` | Sí | Objeto. Cada clave sigue las reglas de `id`, no coincide con una acción y contiene una lista no vacía de IDs de acciones existentes, sin repetir. |

No se admiten campos adicionales ni claves repetidas. `sparktune validar` comprueba todo esto antes de ejecutar nada e indica el campo que falla, por ejemplo `Falta el campo acciones[2].tipo.`. Para añadir una acción de un tipo existente basta con editar el JSON. La decisión está explicada en el [ADR 0003](docs/adr/0003-configuracion-externa.md). Los prompts de la capa de IA y del desarrollo están en [docs/prompts.md](docs/prompts.md).

## Códigos de salida

| Código | Significado |
| --- | --- |
| `0` | Todo correcto, o el usuario canceló. |
| `1` | Falló la ejecución (ruta inexistente, archivo cambiado durante la copia, WinGet, Groq en `comprobar-ia`…). |
| `2` | Error de uso: opción, perfil o acción desconocidos. |
| `3` | El catálogo `acciones.json` no es válido. |

## Asesor de IA

`asesorar` elige un perfil y `explicar` ayuda a entender cómo encaja un perfil con el equipo. Ninguna de las dos aplica cambios. Cada propuesta muestra:

- **Por qué encaja con tu uso:** el motivo que da la IA o, en modo local, las palabras de tu objetivo que han llevado a ese perfil.
- **Con tu equipo:** RAM, disco y batería medidos, y cómo adaptan el plan.
- **Qué cambiaría en Windows:** cada instalación o ajuste y **cómo revertirlo** (por ejemplo, `winget uninstall --id Git.Git --exact`), además del punto de restauración que se crea antes del primer cambio.

La IA solo elige el perfil y redacta el motivo. Los cambios y su reversión salen siempre del catálogo de SparkTune, así que el modelo no puede proponer instalaciones ni instrucciones propias. Si `preparar` falla a medias, indica cómo deshacer lo que sí se aplicó.

Usa `--local` si prefieres trabajar sin red. Si no hay red o no hay clave, SparkTune lo indica y responde con sus reglas locales. Para habilitar el proveedor Groq, configura `GROQ_API_KEY` en la sesión o copia `.env.example` a un fichero privado y pasa su ruta con `--env-file`. Prueba la conexión con `sparktune comprobar-ia`. Nunca incluyas claves en capturas, transcripciones o commits. El modelo predeterminado es `openai/gpt-oss-120b`. La disponibilidad depende de la cuenta y de los límites de Groq.

## Desarrollo

Ejecuta `uv sync --locked`, `uv run pytest` y `uv run sparktune --help`. Las pruebas usan carpetas temporales y simulan WinGet, PowerShell y Groq, así que no cambian el equipo. GitHub Actions las ejecuta en Ubuntu, Windows y macOS e instala el paquete desde una carpeta limpia. Para comprobar en un portátil real el punto de restauración, WinGet y la batería, sigue [docs/PRUEBA-WINDOWS.md](docs/PRUEBA-WINDOWS.md).

### Estructura

| Módulo | Responsabilidad |
| --- | --- |
| `cli.py` | Interfaz: órdenes de Typer, salida en pantalla y traducción de errores a códigos de salida. |
| `config.py` | `Catalogo`: lee y valida `acciones.json` con las fábricas `desde_archivo()` y `desde_datos()`. |
| `acciones.py` | Una clase por tipo (`Copiar`, `Inventario`, `Huellas`). `Accion.desde_config()` crea la clase adecuada. |
| `motor.py` | `Plan`: selecciona los archivos, reserva la salida y la aplica sin tocar los originales. |
| `ficheros.py` | `Entrada`: lectura de la carpeta sin seguir enlaces y comprobación de que los archivos no cambian. |
| `esquema.py` | Reglas comunes del JSON: campos exactos, IDs portables y claves repetidas. |
| `errores.py` | Excepciones propias (`ConfigError`, `AccionNoValida`, `ErrorEjecucion`, `ErrorIA`), cada una con su código de salida. |
| `proveedores.py` | `ProveedorIA` con dos implementaciones: `ProveedorGroq` y `ProveedorLocal` (sin red). |
| `ia.py` | Órdenes `asesorar`, `explicar` y `comprobar-ia`, que recurren al proveedor local si Groq falla. |
| `preparar.py` | Perfiles de preparación de Windows, WinGet y punto de restauración. |

Para añadir un tipo de acción, crea una subclase de `Accion` con su atributo `tipo` y los métodos `describir()` y `escribir()`: queda registrada sin cambiar el motor ni el catálogo.
