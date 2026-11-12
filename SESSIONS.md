# SparkTune — registro de sesiones de desarrollo

Cada sesion registra **que se ha hecho** y **que queda pendiente**. Orden: el mas reciente primero.

## 2026-11-12 — Sesion 5 (v1.5.0: apps no interactivo + fix GUIDs GPU)

### Hecho

- **`sparktune apps --install=chrome,vlc`**: instalacion no interactiva (ids/nombres/winget-ids,
  coma separada). Tokens desconocidos avisados sin abortar el resto; `--scope=user` y
  `--interactive` (UI de winget visible). Flag `--scope`/`--interactive` sin `--install` = error.
- **Fallos por app**: helper `Install-STWingetApp` mira `$LASTEXITCODE` + salida; distingue
  "no encontrada" (0x8A150014), codigo de error concreto y fallo generico; resumen final
  `X/N instaladas; pendientes: ...`. El menu interactivo usa el mismo helper (antes marcaba
  como instalada cualquier app aunque winget fallase).
- **`gpu.power-mode` arreglado**: los GUIDs de v1.4.0 eran incorrectos (subgrupo 4d36e968 =
  Video Priority + setting inexistente: powercfg no aplicaba nada). Ahora PCI Express
  {4d36e967} + Link State Power Management {eeabc0fe} = 0/Off en AC, undo a 2 (Moderate).
  Descripcion/preview actualizados.
- **Planes spark-turbo / spark-max**: fijan PCI-E Link State = 0 (AC) en su propia spec, sin
  depender de la accion `gpu.power-mode`.
- CHANGELOG, README (uso+flags+roadmap), ayuda ES/EN, version 1.5.0.

### Pendiente / siguiente sesion

- [ ] **Windows real** (acumulado v1.4-1.5): probar `apps --install` (incl. `--scope=user`),
      `--interactive`, avisos de "no encontrada"; `gpu.power-mode` real + `powercfg /query`
      para confirmar el setting; wizard con config; `net.wsl-nat`; `clean.thumbnails`; `--set-*`.
- [ ] **apps**: actualizar solo seleccionadas; paquetes portables.
- [ ] Taggear v1.5.0 + asset zip tras CI verde.

## 2026-11-10 — Sesion 4 (v1.4.0: config persistente + apps ampliadas)

### Hecho

- **Config persistente** (`~/.sparktune/config.json`): nuevos flags `--set-lang`,
  `--set-banner=on|off`, `--set-nivel=...` que escriben el config y salen. `globals.ps1`
  lo lee al arrancar: idioma por defecto, banner on/off, y nivel preseleccionado en el
  wizard. Verificado en pwsh Linux (guarda y aplica).
- **apps.json**: de 35 a 61 apps en 11 categorias (nuevas: oficina, emulacion,
  streaming/creacion). Eliminadas entradas con winget id no verificado (yuzu, Figma,
  Canva, Adobe, Photopea, Element, Glary…) para no ofrecer installs rotos.
- **`gpu.power-mode`** en gaming/creativo: maxima potencia GPU en el plan (powercfg
  SCHEME_CURRENT PCI-E PowerMgmtPolicy=0 AC, undo a 1).
- CHANGELOG, README (flags nuevos) y version 1.4.0.

### Pendiente / siguiente sesion

- [ ] **Windows real**: probar `--set-*` y wizard con config, `gpu.power-mode`,
      `net.wsl-nat` (con WSL real), `clean.thumbnails`, e `apps` con winget.
- [x] **apps**: ofrecer `--scope=user` y `--interactive` opcional; detectar "no encontrado"
      de winget y avisar por app en vez de solo log. (v1.5.0)
- [x] **apps**: comando `sparktune apps --install=chrome,vlc` no interactivo (scripts). (v1.5.0)
- [x] GPU power mode por plan SparkTune (los planes podrian fijar PowerMgmtPolicy ellos mismos). (v1.5.0)
- [x] Taggear v1.4.0 + zip (tag v1.4.0 publicado, CI verde).

## 2026-11-10 — Sesion 3 (v1.3.0: perfiles creativo/desarrollo + asset zip)

Repo: https://github.com/josemidev1-code/CLI-SPARKTUNE (rama `main`)

### Hecho

- **Perfiles nuevos** `creativo` y `desarrollo` (suave/medio/agresivo) en profiles.json,
  wizard (opcion 8 y 9), etiquetas ES/EN y ayuda.
- **10 acciones nuevas**: `cpu.coreparking-off`, `gpu.resbar` (informativo),
  `off.storage-sense`, `off.hibernation`, `clean.minisave`, `clean.thumbnails`,
  `net.wsl-nat` (con `.wslconfig` guardado y undo), `net.smb-hardening` (guest SMB off
  con valor previo), `priv.cloud-content`, `priv.feedback-all-off`. Todos con contract
  completo y detect tolerantes a rutas nulas (no petan fuera de Windows).
- README con **capturas simuladas** (banner + wizard + menu apps) y lista de perfiles completa.
- **Release v1.2.0 con asset zip** (`git archive`) — descarga directa lista para `install.ps1`.
- Version 1.3.0 + CHANGELOG.

### Pendiente / siguiente sesion

- [ ] **Windows real**: probar apps (winget), sec.*, doctor, y las 10 acciones de esta sesion
      (sobre todo `net.wsl-nat` con WSL instalado y `clean.thumbnails` con Explorer abierto).
- [ ] Ampliar `apps.json` (mas categorias: emulacion, office completo, portables).
- [ ] Paquetes winget con `--scope=user` cuando exista para evitar admin en `apps`.
- [ ] Perfil `creativo` podria ganar accion propia de GPU (power GPU plan por perfil).
- [ ] Actualizar el asset zip cuando se taggee v1.3.0.

## 2026-11-09 — Sesion 2 (v1.2.0 "final boss": apps, seguridad, CI)

Repo: https://github.com/josemidev1-code/CLI-SPARKTUNE (rama `main`)

### Hecho

- **F0 fixes**: `net.doh` guarda/restaura DNS real por adaptador (`state-net.doh.json`;
  antes usaba `InterfaceIndex 0` invalido); GUIDs PCI/ASPM de power.ps1 corregidos y GUIDs
  inventados de Power Throttling eliminados; `clean.dns` sin exigir admin; install.ps1: copia
  selectiva sin `.git`/tests, journal portable, `WM_SETTINGCHANGE` con `lParam='Environment'`;
  uninstall robusto; todos los `.ps1`/JSON con UTF-8 BOM; `globals.ps1` con home portable (`HOME`).
- **F1**: `tests/run-tests.ps1` (11 tests sin dependencias, pasan en pwsh 7 y 5.1) +
  `.github/workflows/ci.yml` (job contract + dry-run 8 perfiles×3 niveles en windows-latest).
- **Apps estilo winutil**: `sparktune apps` — menu por categorias (9), 35 apps `apps.json`
  via winget oficial, ✔ de instaladas, dry-run seguro, `winget upgrade` global.
- **Seguridad**: `src/catalog/security.ps1` — `sec.defender-report`, `sec.pua-protection`,
  `sec.autostart-notifs`, `sec.firewall-log`, `sec.smb1-off`, `sec.hidden-restore`
  (integrado en red-privacidad y ofimatica). Nunca desactiva nada de seguridad.
- **`doctor`**, **`report --out=`** (HTML), **`undo --category=`**.
- **Docs**: CHANGELOG.md (v1.0-1.2), docs/DESIGN.md (arquitectura + contrato de accion +
  checklist para anadir acciones), README actualizado, version 1.2.0.

## 2026-11-06 — Sesion 1 (perfil red-privacidad + comando history)

Repo: https://github.com/josemidev1-code/CLI-SPARKTUNE (rama `main`)

### Hecho

- **Nuevo perfil `red-privacidad`** (suave/medio/agresivo) en `src/data/profiles.json`,
  etiquetas ES/EN en `src/core/ui.ps1`, opcion 7 en el wizard (`src/core/engine.ps1`)
  y ayuda de `--perfil` actualizada.
- **Nuevas acciones de red** (`src/catalog/network.ps1`):
  - `net.wol-off` — desactiva Wake-on-LAN (`Disable-NetAdapterPowerManagement`).
  - `net.netbios-off` — NetBIOS over TCP/IP deshabilitado por interfaz (registro NetBT).
  - `net.llmnr-off` — LLMNR + mDNS off via politicas DNSClient (guarda previos, undo real).
- **Nuevas acciones de privacidad** (`src/catalog/privacy.ps1`):
  - `priv.ads` — contenido patrocinado del menu Inicio off.
  - `priv.input-personalization` — fin de subida de datos de tecleo/manuscrito (HKCU+HKLM).
  - `priv.preapps` — bloquea auto-instalacion silenciosa de "recommended apps".
- **Nuevo comando `sparktune history`**: resumen del journal por entrada
  (`applied/undone/failed/dryrun`) con colores; funcion `Show-STHistory` en `engine.ps1`,
  strings ES/EN `history.*`, enrutado en `sparktune.ps1` y ayuda.
- README: perfil y comando nuevos, roadmap actualizado.

### Pendiente (heredado a Sesion 2)

- Probar en Windows real; CI smoke-test; mas perfiles; capturas y winget.

### Pendiente / siguiente sesion

- [ ] **Probar en Windows**: no hay pwsh en este PC Linux; `net.*` nuevas y `history`
      solo se han validado por sintaxis/contratos, no ejecutadas.
- [ ] `net.wol-off` en laptops: comprobar que el undo (Enable) no despierta WoL que
      el usuario tenia ya apagado de fabrica (revisar si conviene guardar estado previo).
- [ ] Smoke-test automatizado `--dry-run` en CI (GitHub Actions runner `windows-latest`).
- [ ] Mas perfiles: creativo/edicion, desarrollo.
- [ ] Capturas en README y paquete winget.

### Notas para el desarrollador

- `pwsh` local para probar en Linux: `/tmp/opencode/pwsh/pwsh` (no forma parte del repo).
- Los IDs de accion son contrato del journal: no renombrar IDs ya publicados.
