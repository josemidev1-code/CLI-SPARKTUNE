# SparkTune

Optimizador CLI de Windows. Sin instalar nada, sin registros raros, sin promesas raras:
detecta tu hardware, te ensena **una ficha por cambio** (qué hace, riesgo, reversible), y aplicas
solo lo que quieras. Los cambios se registran en un historial; algunas operaciones son irreversibles y otras necesitan una revisión adicional antes de poder garantizar su restauración.

by **@josemidev1**

## Requisitos

- Windows 10/11 (cualquier edicion)
- PowerShell 5.1+ (ya viene con Windows)
- No hace falta admin para el wizard completo, pero las acciones que lo necesitan se marcan y se omiten si no lo eres

## Instalacion

**Instalación rápida desde PowerShell** (sin administrador). Descarga el instalador
y deja que instale la última versión publicada. Para actualizar, repite el bloque.

```powershell
$dir = Join-Path $env:TEMP ('sparktune-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
try {
    $script = Join-Path $dir 'install.ps1'
    Invoke-WebRequest -UseBasicParsing -ErrorAction Stop -Uri 'https://raw.githubusercontent.com/josemidev1-code/CLI-SPARKTUNE/main/install.ps1' -OutFile $script
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
    if ($LASTEXITCODE -ne 0) { throw "La instalación falló (código $LASTEXITCODE)." }
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force
}
```

**Instalación manual.** Extrae el ZIP de la [última versión](https://github.com/josemidev1-code/CLI-SPARKTUNE/releases/latest),
abre PowerShell en la carpeta extraída y ejecuta:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Eso copia a `%LOCALAPPDATA%\SparkTune` y anade la carpeta al PATH de usuario (sin admin).
Abre una **nueva** ventana de CMD o PowerShell y escribe:

```
sparktune ayuda
```

`sparktune` muestra la intro y la guía de comandos. Para abrir el asistente interactivo, escribe `sparktune optimizar`. El asistente ofrece crear un punto de restauración antes de aplicar ajustes que lo requieren, si Windows lo permite y tienes permisos de administrador.

Si tienes configurada una clave de Groq u OpenAI, SparkTune te invita a describir tu situación al arrancar en una terminal interactiva. Puedes pulsar Enter para ir a la guía. La recomendación de inicio es una vista previa. También puedes acceder a la IA desde el menú de `sparktune preparar`.

```powershell
sparktune ayuda preparar
sparktune help --lang=en
sparktune --set-lang=en
```

Para desinstalar desde PowerShell, ejecuta `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\SparkTune\uninstall.ps1"`.

## Intro en la terminal

Al ejecutar `sparktune` desde una terminal de Windows verás cómo los `0` y `1` forman el logo de bloques, una chispa enciende la onda RGB y aparece la firma `made by josemidev1`. Puedes reproducir la intro por separado con `sparktune banner`. Usa `--no-banner` para omitirla.

## Preparar un PC nuevo

`sparktune preparar` pregunta para qué vas a usar el PC y agrupa los perfiles en Trabajo y estudios, Creación y juegos, Tecnología y Casa y uso cotidiano. Usa `sparktune perfiles` para verlos todos desde la terminal. El comando muestra las aplicaciones y los ajustes propuestos. Puedes confirmar cada aplicación, cada ajuste y el plan de energía por separado.

| Perfil | Qué prepara |
| --- | --- |
| `desarrollo` | VS Code, Git, Node.js LTS, Python y 7-Zip |
| `video-adobe` | Herramientas auxiliares e instrucciones oficiales para instalar Premiere Pro y After Effects desde Creative Cloud con tu cuenta |
| `video-libre` | Kdenlive, Blender, Audacity y VLC |
| `gaming` | Steam, Discord, 7-Zip y Modo Juego |
| `ofimatica` | LibreOffice, Firefox y 7-Zip |
| `estudios` | LibreOffice, Obsidian, Foxit PDF y draw.io |
| `teletrabajo` | Zoom, LibreOffice, Bitwarden y Firefox |
| `diseno` | GIMP, Inkscape, Blender e IrfanView |
| `streaming` | OBS Studio, Audacity, Discord y VLC |
| `datos` | Python, VS Code, DBeaver y LibreOffice |
| `ingenieria` | FreeCAD, QGIS, draw.io y 7-Zip |
| `casa` | Firefox, VLC y LibreOffice |

```powershell
sparktune perfiles
sparktune preparar estudios --simular
sparktune setup --perfil=video-adobe
sparktune setup --perfil=gaming --sin-apps
sparktune setup --perfil=ofimatica --sin-ajustes --plan=ninguno
sparktune setup --perfil=gaming --sin-apps --sin-ajustes --plan=spark-portatil-max
```

Al terminar, el resumen distingue las instalaciones que WinGet comunica como correctas, las ya presentes, los fallos y las que no se intentaron. Un resultado correcto del instalador no garantiza que la app esté configurada: puede pedir inicio de sesión, licencia o pasos adicionales. Adobe se instala manualmente desde Creative Cloud con la cuenta y el plan correspondientes.

Con `--dry-run` puedes revisar el plan sin instalar ni aplicar cambios. `--yes` acepta todas las propuestas del perfil. Puedes usar `--interactive` si quieres ver los instaladores de las aplicaciones que lo admiten. Las apps automáticas se instalan desde la fuente `winget`.

Si prefieres explicarlo con tus palabras, elige **Cuéntale tu situación a la IA** en `sparktune setup` o pasa el texto en el comando:

```powershell
sparktune setup '--objetivo=Quiero programar en mi portátil y que la batería me dure más' --sin-apps
```

La IA explica qué perfil y plan propone. SparkTune prepara la lista a partir de su catálogo y te pide confirmación antes de instalar o aplicar. Usa la misma variable `GROQ_API_KEY` u `OPENAI_API_KEY` que `sparktune ai`. Para revisar qué datos se enviarían sin llamar al proveedor, añade `--dry-run` al ejemplo. Se envían tu objetivo, si el equipo tiene batería o está enchufado y las opciones del catálogo.

**Portátil Máximo** favorece el rendimiento al enchufarlo y limita el estado máximo de CPU al 80 % con batería. También apaga antes la pantalla y suspende tras 15 minutos de inactividad con batería. Si priorizas la autonomía, puedes elegir `--plan=spark-ahorro` o `--plan=spark-ultra`. El efecto del plan depende del hardware y del firmware. Los ajustes y los cambios de plan hechos por `setup` se pueden deshacer con `sparktune undo`. Gestiona las aplicaciones instaladas por separado desde Windows o WinGet.

Puedes reutilizar una propuesta en otro equipo con un archivo JSON. Guárdala desde un perfil o desde una recomendación de IA:

```powershell
sparktune setup --perfil=desarrollo '--guardar-plan=Mi plan.json'
sparktune validar '--cargar-plan=Mi plan.json'
sparktune setup '--cargar-plan=Mi plan.json' --dry-run
sparktune setup '--cargar-plan=Mi plan.json' --yes
```

El archivo guarda identificadores de aplicaciones y ajustes, y el plan de energía elegido. Al cargarlo, SparkTune valida el catálogo y la compatibilidad antes de aplicar cambios. Puedes añadir `--sin-apps` o `--sin-ajustes` para saltar una parte. Guardar crea un archivo nuevo y, si ya existe, pide un nombre distinto mediante un error.

Para añadir perfiles, edita [setup-profiles.json](src/data/setup-profiles.json). El campo `grupo` acepta `trabajo`, `creacion`, `tecnologia` o `casa`. En `apps` usa identificadores de [apps.json](src/data/apps.json). En `ajustes` usa identificadores de las acciones preparadas para `setup`. `plan-portatil` y `plan-sobremesa` eligen un plan para cada equipo y `manual` permite documentar aplicaciones que se instalan desde el proveedor.

También puedes revisar y ejecutar un solo ajuste del catálogo:

```powershell
sparktune acciones
sparktune acciones --json
sparktune validar
sparktune ejecutar --id=setup.file-extensions --dry-run
sparktune ejecutar --id=setup.file-extensions
```

El catálogo [acciones.json](src/data/acciones.json) define los ajustes de cuenta que usa `setup`. Cada entrada indica un ID único `setup.…`, títulos y descripciones en español e inglés, una ruta en `HKCU` (bajo `Software\Microsoft` o `System\GameConfigStore`), el nombre del ajuste, el valor booleano de registro como entero `0` o `1`, y la compilación mínima de Windows. El motor valida el catálogo y guarda el destino y valor previos para `undo`. Si cambias el destino de un ajuste, dale un ID nuevo. Véase el [ADR del catálogo](docs/adr/0001-catalogo-de-acciones.md). Añade el ID al perfil que quieras desde `setup-profiles.json`.

## Uso

```
sparktune ayuda                    # guía rápida
sparktune preparar desarrollo      # preparación por perfil
sparktune optimizar                # asistente interactivo (perfil -> nivel -> lista de acciones)
sparktune ia                       # recomendaciones personalizadas con IA
sparktune estado                   # CPU, RAM, discos, GPU, bateria, plan, servicios pesados
sparktune espacio                  # que esta ocupando espacio (no borra nada)
sparktune energia                  # planes SparkTune: listar / crear / aplicar / restaurar
sparktune bateria                  # informe de bateria + planes recomendados
sparktune historial                # historial de cambios del journal (estado por entrada)
sparktune apps                     # instalar apps populares (menu estilo winutil, via winget)
sparktune apps --install=chrome,vlc --scope=user   # instalacion no interactiva (scripts)
sparktune apps --update=vlc             # actualizar solo apps concretas
sparktune doctor                   # salud del sistema y coherencia journal/catalogo
sparktune informe [--out=archivo]  # informe HTML (sistema, discos, journal) para compartir
sparktune deshacer                 # deshace cambios (en orden inverso), --id=xxx o --category=priv
sparktune --help
```

Flags:

```
--perfil=gaming        gaming|ofimatica|limpieza|bajos-recursos|
                       portatil-ahorro|portatil-rendimiento|
                       red-privacidad|creativo|desarrollo|personalizado
--nivel=suave|medio|agresivo
--yes                              # sin confirmaciones (usalo solo si sabes lo que haces)
--dry-run                          # simulacion: muestra lo que haria, no toca nada
--lang=es|en                       # idioma de esta ejecucion
--set-lang=es|en                   # guarda idioma por defecto (persistente)
--set-banner=on|off                # banner por defecto
--set-nivel=suave|medio|agresivo   # nivel por defecto en el wizard
--install=a,b                      # (apps) instalar sin interactuar; --scope=user, --interactive
--update=a,b                       # (apps) actualizar solo esas apps
--no-banner
```

`sparktune version` muestra la versión. `sparktune validar --cargar-plan=archivo.json` valida el formato, el catálogo y la compatibilidad sin aplicar cambios. Códigos de salida: `0` correcto, `1` error de operación, `2` uso incorrecto y `3` configuración inválida o plan incompatible.

Las opciones desconocidas terminan con código 2 para evitar que un error al escribir `--dry-run` ejecute cambios por accidente.

`--dry-run` simula el asistente, `apps`, `ai` y `undo`; para `power`, `battery`, `report` y los cambios de configuración se rechaza, ya que esos comandos pueden escribir archivos o cambiar ajustes. La simulación no añade entradas al historial. Con `--perfil` y `--nivel` explícitos, muestra las acciones compatibles sin abrir menús ni seleccionar cambios.

**Estado de la revisión:** no ejecutes ajustes reales en un equipo de uso diario todavía. Algunos módulos anteriores guardan valores supuestos para `undo` o silencian errores de Windows. Se están corrigiendo y deben probarse en una VM; los planes de ahorro también necesitan pruebas de consumo en un portátil físico. El asistente ya no preselecciona acciones.

Ejemplo recomendado la primera vez:

```
sparktune --perfil=gaming --nivel=medio --dry-run
```

## Recomendaciones con IA

`sparktune ai` pide hasta cuatro recomendaciones del catálogo compatibles
con el equipo. Muestra el motivo, el riesgo y si hace falta reiniciar o abrir
PowerShell como administrador. Tú decides qué ajustes aplicar desde el asistente.

Primero puedes ver el contexto que se enviaría, sin clave y sin contactar a la API:

```powershell
sparktune ai --objetivo="Ahorrar batería" --dry-run
```

Para usar **GPT-OSS 20B con el plan gratuito de Groq**, crea una [clave de Groq](https://console.groq.com/keys) y cárgala en la sesión de PowerShell:

```powershell
$key = Read-Host 'Clave de API de Groq' -AsSecureString
$env:GROQ_API_KEY = [System.Net.NetworkCredential]::new('', $key).Password
sparktune setup '--objetivo=Quiero programar y ahorrar batería' --sin-apps
```

Si ya tienes `OPENAI_API_KEY` configurada, SparkTune usará OpenAI. Retira esa variable de la sesión con `Remove-Item Env:OPENAI_API_KEY` si prefieres probar Groq. Con OpenAI, el modelo predeterminado es `gpt-4.1-mini` y lo puedes cambiar con `SPARKTUNE_AI_MODEL`. Ambos servicios tienen límites de uso.

La consulta envía el objetivo, categorías del hardware y opciones del catálogo.
El historial, los nombres del equipo y las rutas locales se quedan en el PC.
SparkTune lee la clave del entorno. Usa `--lang=en` para recibir recomendaciones en inglés.

## Capturas (simuladas)

Asistente: perfil gaming / medio — cada accion con ficha de riesgo y reversible:

```
> SparkTune v1.2.0
███████╗ █████╗ ██████╗ ██████╗  █████╗ ████████╗████████╗██╗   ██╗███╗   ██╗
██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝╚██╗ ██╔╝████╗ ████║████╗ ████║
███████╗███████║██████╔╝██████╔╝███████║   ██║    ╚████╔╝ ██╔████╔██║██╔████╔██║
╚════██║██╔══██║██╔═══╝ ██╔══██╗██╔══██║   ██║     ╚██╔╝  ██║╚██╔╝██║██║╚██╔╝██║
███████║██║  ██║██║     ██║  ██║██║  ██║   ██║      ██║   ██║ ╚═╝ ██║██║ ╚═╝ ██║
╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝     ╚═╝╚═╝     ╚═╝
   ⚡ Optimizacion de Windows · v1.2.0 · por @josemidev1 ⚡

Sistema: Windows 11 Pro (build 22631)
CPU:     AMD Ryzen 7 5800X [8C/16T]     RAM: 32 GB
Disco:   931GB SSD                       GPU: NVIDIA GeForce RTX 3070 + Intel UHD
Bateria: sobremesa

Que quieres optimizar?
  > 1. Gaming
      2. Ofimatica / Productividad
      3. Portatil - Ahorro de bateria
      ...
```

Instalador de apps (menu `sparktune apps` → Herramientas del sistema):

```
  Apps  ·  ✔=instalada

  [ ] 7-Zip                          ✔
  [x] PowerToys
  [ ] Notepad++
  [ ] ShareX (capturas)
  [ ] TeamViewer

  1 seleccionadas   Espacio=Seleccionar  Enter=Continuar  Esc=Volver
```

## Que hace (y que no)

- **Perfiles por caso de uso** (gaming, ofimatica, portatil ahorro/rendimiento, limpieza, PC antiguo, **creativo**, **desarrollo**, **red-privacidad**) en 3 niveles de agresividad.
- **Deteccion de hardware**: aplica o filtra acciones segun SSD/HDD, bateria, GPU discreta, RAM, portatil/sobremesa.
- **Fichas antes de aplicar**: descripcion, aviso, valor actual -> propuesto, riesgo, reversible, admin, reinicio.
- **Riesgo alto = confirmacion tipando SI**, y aviso de punto de restauracion.
- **Journal** en `~/.sparktune/journal.json` y **undo** de todo o de un cambio concreto.
- **Planes de energia** propios (Ultra Ahorro -> Alto Rendimiento) creados con `powercfg` duplicando los de fabrica, y restaurables.
- **Instalador de apps** (`sparktune apps`): 66 apps organizadas por categorias (navegadores, social, herramientas, gaming, diseno, programacion, docs, musica, seguridad, oficina, emulacion, streaming) instaladas con **winget oficial**; nada de mirrors ni instaladores sueltos. Incluye paquetes **portables** (marcados `(p)`) que no tocan el registro.
- **Seguridad sin sustos**: nunca desactiva Defender, firewall ni UAC. El catalogo `sec.*` informa y endurece (PUA, SMBv1, logs), la restauración de cada ajuste necesita verificación en Windows real.

La limpieza de ficheros es irreversible y se confirma aparte. La restauración de otros ajustes aún está en revisión: comprueba los cambios en una máquina virtual antes de usarlos en tu equipo.

## Estructura

```
sparktune.ps1        entrada + parseo de flags
install.ps1          instalacion usuario (PATH sin admin)
src/core/            ui (ES/EN, ANSI), detect, engine (preview/apply/undo), journal, banner, catalog loader
src/catalog/         acciones por area: cpu, gpu, memory, network, privacy, security, cleanup, power, laptop, office, updates
src/data/            profiles.json (ids por perfil/nivel), apps.json (instalador), figlet.txt (banner)
tests/run-tests.ps1  tests de contrato (sin dependencias)
docs/DESIGN.md       arquitectura y como anadir acciones
```

## Roadmap

- [x] Perfil "red/privacidad" dedicado (perfil `red-privacidad` + acciones `net.*` / `priv.*` nuevas) — v1.1.0
- [x] Instalador de apps estilo winutil via winget (`sparktune apps`) — v1.2.0
- [x] Smoke-test automatizado en --dry-run (CI en runner de Windows) — v1.2.0
- [x] Perfiles creativo/edicion y desarrollo — v1.3.0
- [x] Config persistente (`--set-lang/--set-banner/--set-nivel`) y 61 apps — v1.4.0
- [x] `apps --install=...` no interactivo + `--scope=user`/`--interactive` + avisos de fallo por app — v1.5.0
- [x] `apps --update=...` (solo seleccionadas) + paquetes portables winget — v1.6.0
- [ ] Pruebas en Windows real de las acciones nuevas: `tests/verify-windows.ps1` (ver SESSIONS.md)
- [ ] Capturas nuevas del menu apps actualizado
- [ ] Paquete winget del propio SparkTune (PR a microsoft/winget-pkgs) — ver nota en SESSIONS.md

## Registro de sesiones

Ver [SESSIONS.md](SESSIONS.md) (que se hace en cada sesion de desarrollo y que queda pendiente) y [CHANGELOG.md](CHANGELOG.md).

## Licencia

MIT
