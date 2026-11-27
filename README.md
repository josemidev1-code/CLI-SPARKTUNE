# SparkTune

SparkTune prepara un entorno de trabajo para quien estudia, programa, juega o edita vídeo. Puedes describir tu objetivo o elegir un perfil directamente. El CLI en Python funciona en Windows, Linux y macOS. La instalación de aplicaciones mediante WinGet y los ajustes de Windows se aplican desde Windows.

## Instalación

Con [uv](https://docs.astral.sh/uv/getting-started/installation/) instalado, en la carpeta de esta versión ejecuta:

```console
uv tool install .
```

Desde otra carpeta, comprueba `sparktune version` y `sparktune --help`. Si la terminal no encuentra el comando, ejecuta `uv tool update-shell` y vuelve a abrirla. Si tenías SparkTune 1.x, comprueba con `Get-Command sparktune -All` que estás ejecutando la versión 2. Para desinstalarla usa `uv tool uninstall sparktune`. La documentación de la edición PowerShell 1.x está en [docs/POWERSHELL.md](docs/POWERSHELL.md).

## Primeros cinco minutos

```console
sparktune perfiles
sparktune asesorar "Desarrollo aplicaciones Android y mi portátil tiene poca memoria"
sparktune preparar android --simular
sparktune explicar video-adobe
sparktune listar . --json
sparktune acciones
sparktune validar
```

`asesorar` elige un perfil y `explicar` ayuda a entender cómo encaja un perfil con el equipo. Usa `--local` si prefieres trabajar sin red. Para habilitar el proveedor Groq, configura `GROQ_API_KEY` en la sesión o copia `.env.example` a un fichero privado y pasa su ruta con `--env-file`. Prueba la conexión con `sparktune comprobar-ia`. Nunca incluyas claves en capturas, transcripciones o commits. El modelo predeterminado es `openai/gpt-oss-120b`. La disponibilidad depende de la cuenta y de los límites de Groq.

Para desarrollar, ejecuta `uv sync --locked`, `uv run pytest` y `uv run sparktune --help`. La guía de [pruebas en una VM](docs/PRUEBA-VM.md) y el [simulacro](docs/SIMULACRO.md) explican cómo comprobar el comportamiento.
