# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/es/1.1.0/), versionado [SemVer](https://semver.org/lang/es/).

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
