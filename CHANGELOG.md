# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/es/1.1.0/), versionado [SemVer](https://semver.org/lang/es/).

## [2.0.0] - 2026-11-27

Nueva edición en Python 3.12 con Typer, para Windows, Linux y macOS. Se instala con `uv tool install git+https://github.com/josemidev1-code/CLI-SPARKTUNE`. La edición PowerShell 1.x sigue en el repositorio y está documentada en `docs/POWERSHELL.md`.

### Cambiado (incompatible)
- `sparktune` es ahora el CLI en Python. Las órdenes y opciones de la 1.x (`setup`, `wizard`, `--dry-run`…) no existen en la 2.0. La simulación se pide con `--simular`.
- El asesor de IA usa Groq (`GROQ_API_KEY`, modelo `openai/gpt-oss-120b`) en lugar de OpenAI.

### Añadido
- Acciones de archivos definidas en `acciones.json`: `reunir-capturas`, `reunir-informes`, `guardar-planes`, `inventariar` y `calcular-huellas`, combinables por comas o con el perfil `preparar-entrega`. Nunca modifican los originales: escriben en una carpeta `sparktune-salida` nueva y, si algo falla a medias, la marcan con `.incompleto`.
- `validar` comprueba el catálogo antes de ejecutar nada e indica el campo que falla. `--config` permite usar otro catálogo. Una acción nueva de un tipo existente solo requiere editar el JSON (ADR 0003).
- `listar`, `acciones`, `limpiar` y `version`. Cada error previsible tiene su mensaje y su código de salida: 1 si falla la ejecución, 2 si el uso es incorrecto y 3 si el catálogo no es válido.
- `perfiles` y `preparar`: 13 perfiles de uso que instalan aplicaciones con WinGet y adaptan los pasos a la RAM, el disco y la batería. Cada cambio se confirma por separado, antes del primero se crea y se verifica un punto de restauración, y SparkTune indica cómo deshacer cada cambio, también si el lote falla a medias.
- `asesorar`, `explicar` y `comprobar-ia`. La IA solo elige un perfil del catálogo y redacta el motivo: lo que se instala y cómo se revierte lo decide SparkTune. Sin red o sin clave, se usan reglas locales, y `--local` evita la red por completo.
- Pruebas con pytest en Ubuntu, Windows y macOS, e instalación del paquete en una carpeta limpia en GitHub Actions.
- `docs/DEFENSA.md` (evidencia de cada criterio y qué comprueba cada prueba) y `docs/PRUEBA-WINDOWS.md` (guion para un portátil real).

### Corregido
- Edición 1.x: 50 acciones que se declaraban reversibles sin guardar el estado anterior real quedan en revisión y no se ofrecen. `tests/run-tests.ps1` impide ofrecer una acción reversible nueva que no guarde su estado.

## [1.8.0] - 2026-11-17

- `sparktune ai` consulta a OpenAI para recomendar ajustes reversibles del catálogo según el equipo y el objetivo.
- `sparktune ai --dry-run` muestra el contexto sin enviarlo. La clave se lee de `OPENAI_API_KEY` y el modelo se puede elegir con `SPARKTUNE_AI_MODEL`.
- CI comprueba el comando, la solicitud y el manejo de respuestas con un servicio simulado en Windows PowerShell 5.1.

## [1.7.1] - 2026-11-17

- La instalación rápida descarga el ZIP de la versión publicada y comprueba sus archivos antes de instalar.
- El instalador prepara la copia nueva antes de sustituir la anterior y repara instalaciones incompletas de la misma versión.
- CI verifica la instalación desde el script suelto y desde el repositorio, junto con la actualización y la reinstalación.

## [1.7.0] - 2026-11-13

### Añadido
- **Instalacion en una linea** (README/install.ps1): `irm` del script + guardado a temp + ejecucion
  (variante segura de `| iex` frente a AMSI). `install.ps1` sin `$PSScriptRoot` (pipado) da la
  instruccion correcta en vez de petar; deteccion de **update** por `VERSION.txt`
  (misma version = no reinstala; `-Force` siempre); `USERPROFILE` con fallback a `HOME`.
- **`tests/verify-windows.ps1`**: battery de verificacion en Windows real (help/status/dry-runs/
  apps/config/doctor/history/report automaticos + checks `-Admin` de `gpu.power-mode` via
  `powercfg /query` + bloque MANUAL para wsl-nat/thumbnails/hibernacion/sec.*). `-Live` ejecuta
  install/update real de 7-Zip. Exit code para CI/scripts.
- **CI**: job `installer` (PS 5.1): install → `sparktune --help` desde `%LOCALAPPDATA%` →
  reinstall misma version detectado → `-Force`. El test de BOM ahora cubre `tests/*.ps1`.

### Arreglado
- README: caracter corrupto (`quÃ©`) revertido a `qué`.

## [1.6.0] - 2026-11-12

### Añadido
- **`sparktune apps --update=vlc,firefox`**: actualiza solo las apps indicadas (antes solo
  "actualizar todo"). Apps no instaladas se omiten con aviso, no cuentan como fallo.
- **Paquetes portables en apps.json**: FileZilla, IrfanView y Notepad++ (`.Portable` oficial de
  winget) — marcados `(p)` en el menu y con aviso al instalar; test que exige que lo `portable`
  acabe en `.Portable`. Anadidos FreeCAD y QGIS (66 apps).
- `--scope` rechazado explicitamente con `--update` (solo aplica a install).

## [1.5.0] - 2026-11-12

### Añadido
- **`sparktune apps --install=chrome,vlc`**: instalacion no interactiva por scripts (ids, nombres o
  winget ids, separados por comas). Unknown tokens avisados sin abortar el resto.
- **apps flags**: `--scope=user` (pide a winget instalacion sin admin cuando el paquete lo
  soporta) y `--interactive` (muestra la UI de winget en vez de modo silencioso).
- **Aviso de fallos por app**: deteccion de "no encontrada en winget" (0x8A150014) y codigos de
  error por app; resumen final `X/N instaladas; pendientes: ...`. Antes el error solo se veia
  en el log de winget.

### Arreglado
- **`gpu.power-mode`**: GUIDs de powercfg corregidos (los de v1.4.0 apuntaban al subgrupo
  Video Priority {4d36e968} con un setting inexistente — no aplicaba nada). Ahora usa el
  subgrupo PCI Express {4d36e967} + Link State Power Management {eeabc0fe} = Off (AC), undo a
  Moderate Power. Descripcion actualizada.

### Cambiado
- Planes **spark-turbo** y **spark-max**: fijan ellos mismos PCI-E Link State = Off (0) en AC,
  sin depender de `gpu.power-mode`.

## [1.4.0] - 2026-11-10

### Añadido
- **Config persistente** `~/.sparktune/config.json`: `sparktune --set-lang=en`, `--set-banner=off`,
  `--set-nivel=medio` guardan preferencias (banner e idioma se aplican desde el arranque;
  `nivel` preselecciona el nivel del wizard).
- **`gpu.power-mode`**: potencia maxima de GPU en el plan activo (powercfg), para gaming/perfiles de rendimiento.
- **apps.json ampliado**: 61 apps en 11 categorias — anadidas oficina (draw.io, Obsidian, Foxit),
  emulacion (RetroArch, PCSX2, Dolphin, LaunchBox), streaming/creacion (Streamlabs, Kdenlive,
  Inkscape) y herramientas (Rufus, Ventoy, Etcher, Speccy, BleachBit, AIDA64). Se eliminaron
  entradas con IDs de winget no verificados (yuzu, Figma, Canva, Adobe, Photopea, etc.).

## [1.3.0] - 2026-11-10

### Añadido
- Perfiles **`creativo`** (foto/video/3D) y **`desarrollo`** (IDEs, WSL, compiles), con niveles suave/medio/agresivo.
- Nuevas acciones:
  - `cpu.coreparking-off` — core parking off (AC) via powercfg CPCONCURRENCY, sobremesa.
  - `gpu.resbar` — informe/guia Resizable BAR (informativo, se configura en BIOS).
  - `off.storage-sense` — activar Sensor de almacenamiento (auto-limpieza).
  - `off.hibernation` — `powercfg /h off` (libera ~0.75xRAM; no en portatiles por detect).
  - `clean.minisave` — vaciar cache MiniSave (capturas OneDrive).
  - `clean.thumbnails` — borrar thumbcache_*.db (se regeneran; no toca originales).
  - `net.wsl-nat` — WSL2 a NAT (`~/.wslconfig`, con estado previo y undo).
  - `net.smb-hardening` — bloquear SMB guest inseguro (AllowInsecureGuestAuth=0 con prev).
  - `priv.cloud-content` — off sugerencias Explorer (OneDrive/Office en carpetas).
  - `priv.feedback-all-off` — off popups "How likely to recommend".
- Capturas simuladas (ASCII) del wizard y del menu apps en el README.
- Release con asset **zip** (`git archive`) en la release de GitHub.

## [1.2.0] - 2026-11-09

### Añadido
- **`sparktune apps`**: instalador de apps por categorías via winget (estilo Christophe's winutil): internet, social, herramientas, gaming, diseño, programación, documentos, música, seguridad. Marcado ✔ instaladas, selección múltiple, `--dry-run` seguro. Catálogo en `src/data/apps.json`.
- **Catálogo de seguridad** (`sec.*`): informe Defender, PUA protection, reactivar notificaciones OEM, logs firewall, desactivar SMBv1 (reversible), restaurar opciones ocultas. SparkTune nunca desactiva Defender/firewall/UAC.
- **`sparktune doctor`**: coherencia journal↔catálogo, espacio en disco, journal grande, aviso de no-admin.
- **`sparktune report [--out=]`**: informe HTML autocontenido (sistema, discos, journal) para compartir.
- **`undo --category=priv`**: deshacer solo una categoría.
- Perfil **red-privacidad** (v1.1) ahora incluye `sec.*` en ofimatica y red-privacidad.
- **Tests de contrato** `tests/run-tests.ps1` (sin dependencias) + **CI** de GitHub Actions: job Windows 5.1 con tests + dry-run de los 8 perfiles × 3 niveles.

### Cambiado
- `globals.ps1`: home portable (`HOME` en no-Windows para CI).
- `install.ps1`: copia selectiva (sin `.git`/tests), journal portable, `WM_SETTINGCHANGE` con `lParam='Environment'` (arregla el refresco de PATH), borrado robusto con `-Force`.
- `net.doh`: ahora guarda y restaura el DNS real por adaptador (`state-net.doh.json`); antes usaba `InterfaceIndex 0` inválido.
- `power.ps1`: GUIDs de PCI Express/ASPM corregidos; eliminados los GUIDs inventados de Power Throttling.
- `clean.dns` no requiere admin.

## [1.1.0] - 2026-11-06

### Añadido
- Perfil `red-privacidad` (suave/medio/agresivo).
- Acciones: `net.wol-off`, `net.netbios-off`, `net.llmnr-off`, `priv.ads`, `priv.input-personalization`, `priv.preapps`.
- Comando `sparktune history`.

## [1.0.0] - 2026-11-05

### Añadido
- Versión inicial: wizard por perfiles/niveles, catálogo de ~50 acciones con fichas (riesgo/reversible/admin), journal con undo, planes de energía SparkTune (powercfg), status/analyze/battery/power, ES/EN, banner animado, instalador sin admin.
