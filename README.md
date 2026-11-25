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
sparktune
```

Para desinstalar desde PowerShell, ejecuta `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\SparkTune\uninstall.ps1"`.

## Uso

```
sparktune                          # asistente interactivo (perfil -> nivel -> lista de acciones)
sparktune ai                       # recomendaciones personalizadas de OpenAI
sparktune status                   # CPU, RAM, discos, GPU, bateria, plan, servicios pesados
sparktune analyze                  # que esta ocupando espacio (no borra nada)
sparktune power                    # planes SparkTune: listar / crear / aplicar / restaurar
sparktune battery                  # informe de bateria + planes recomendados
sparktune history                  # historial de cambios del journal (estado por entrada)
sparktune apps                     # instalar apps populares (menu estilo winutil, via winget)
sparktune apps --install=chrome,vlc --scope=user   # instalacion no interactiva (scripts)
sparktune apps --update=vlc             # actualizar solo apps concretas
sparktune doctor                   # salud del sistema y coherencia journal/catalogo
sparktune report [--out=archivo]   # informe HTML (sistema, discos, journal) para compartir
sparktune undo                     # deshace cambios (en orden inverso), --id=xxx o --category=priv
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

Las opciones desconocidas terminan con código 2 para evitar que un error al escribir `--dry-run` ejecute cambios por accidente.

`--dry-run` simula el asistente, `apps`, `ai` y `undo`; para `power`, `battery`, `report` y los cambios de configuración se rechaza, ya que esos comandos pueden escribir archivos o cambiar ajustes. La simulación no añade entradas al historial. Con `--perfil` y `--nivel` explícitos, muestra las acciones compatibles sin abrir menús ni seleccionar cambios.

**Estado de la revisión:** no ejecutes ajustes reales en un equipo de uso diario todavía. Algunos módulos anteriores guardan valores supuestos para `undo` o silencian errores de Windows. Se están corrigiendo y deben probarse en una VM; los planes de ahorro también necesitan pruebas de consumo en un portátil físico. El asistente ya no preselecciona acciones.

Ejemplo recomendado la primera vez:

```
sparktune --perfil=gaming --nivel=medio --dry-run
```

## Recomendaciones con IA

`sparktune ai` pide a OpenAI hasta cuatro recomendaciones del catálogo compatibles
con el equipo. Muestra el motivo, el riesgo y si hace falta reiniciar o abrir
PowerShell como administrador. Tú decides qué ajustes aplicar desde el asistente.

Primero puedes ver el contexto que se enviaría, sin clave y sin contactar a la API:

```powershell
sparktune ai --objetivo="Ahorrar batería" --dry-run
```

Para hacer la consulta, crea una [clave de API de OpenAI](https://platform.openai.com/api-keys)
y cárgala en la sesión de PowerShell. El primer comando solicita la clave sin mostrarla
en pantalla. Las consultas consumen cuota de la API.

```powershell
$key = Read-Host 'Clave de API de OpenAI' -AsSecureString
$env:OPENAI_API_KEY = [System.Net.NetworkCredential]::new('', $key).Password
sparktune ai --objetivo="Ahorrar batería" --perfil=portatil-ahorro --nivel=suave
```

La consulta envía el objetivo, categorías del hardware y metadatos de los ajustes
candidatos. El historial, los nombres del equipo y las rutas locales se quedan
en el PC. SparkTune lee la clave de la variable de entorno y no la guarda en
su configuración. El modelo predeterminado es `gpt-4.1-mini`. Para usar otro
modelo compatible con Responses y Structured Outputs, configura
`SPARKTUNE_AI_MODEL`. Usa `--lang=en` para recibir recomendaciones en inglés.

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
