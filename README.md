# SparkTune

Optimizador CLI de Windows. Sin instalar nada, sin registros raros, sin promesas raras:
detecta tu hardware, te ensena **una ficha por cambio** (quÃ© hace, riesgo, reversible), y aplicas
solo lo que quieras. Cada cambio queda en un journal y se puede deshacer con un comando.

by **@josemidev1**

## Requisitos

- Windows 10/11 (cualquier edicion)
- PowerShell 5.1+ (ya viene con Windows)
- No hace falta admin para el wizard completo, pero las acciones que lo necesitan se marcan y se omiten si no lo eres

## Instalacion

```powershell
# descarga/zip y dentro de la carpeta:
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Eso copia a `%LOCALAPPDATA%\SparkTune` y anade la carpeta al PATH de usuario (sin admin).
Abre una **nueva** ventana de CMD o PowerShell y escribe:

```
sparktune
```

Desinstalar: `powershell -File "%LOCALAPPDATA%\SparkTune\uninstall.ps1"`

## Uso

```
sparktune                          # asistente interactivo (perfil -> nivel -> lista de acciones)
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

Ejemplo recomendado la primera vez:

```
sparktune --perfil=gaming --nivel=medio --dry-run
```

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
- **Planes de energia** propios (Ultra Ahorro -> Turbo GPU) creados con `powercfg` duplicando los de fabrica, y restaurables.
- **Instalador de apps** (`sparktune apps`): 35 apps organizadas por categorias (navegadores, social, herramientas, gaming, diseno, programacion, docs, musica, seguridad) instaladas con **winget oficial**; nada de mirrors ni instaladores sueltos.
- **Seguridad sin sustos**: nunca desactiva Defender, firewall ni UAC. El catalogo `sec.*` informa y endurece (PUA, SMBv1, logs), todo reversible.

No hace "tweaks magicos" que rompen Windows: cada accion tiene undo documentado, y lo que no se
puede deshacer (limpieza de ficheros) esta marcado como irreversible y se confirma aparte.

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
- [ ] Pruebas en Windows real de las acciones nuevas (ver SESSIONS.md)
- [ ] Capturas nuevas del menu apps actualizado
- [ ] Paquete winget

## Registro de sesiones

Ver [SESSIONS.md](SESSIONS.md) (que se hace en cada sesion de desarrollo y que queda pendiente) y [CHANGELOG.md](CHANGELOG.md).

## Licencia

MIT
