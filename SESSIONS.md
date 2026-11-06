# SparkTune — registro de sesiones de desarrollo

Cada sesion registra **que se ha hecho** y **que queda pendiente**. Orden: el mas reciente primero.

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

### Pendiente / siguiente sesion

- [ ] **Probar en Windows**: no hay pwsh en este PC Linux; `net.*` nuevas y `history`
      solo se han validado por sintaxis/contratos, no ejecutadas.
- [ ] `net.wol-off` en laptops: comprobar que el undo (Enable) no despierta WoL que
      el usuario tenia ya apagado de fabrica (revisar si conviene guardar estado previo).
- [ ] Smoke-test automatizado `--dry-run` en CI (GitHub Actions runner `windows-latest`).
- [ ] Mas perfiles: creativo/edicion, desarrollo.
- [ ] Capturas en README y paquete winget.

### Notas para el desarrollador

- Cambiar `$Global:STVersion` en `src/core/globals.ps1` solo cuando se pruebe en Windows
  (pendiente: subir a `1.1.0`).
- Los IDs de accion son contrato del journal: no renombrar IDs ya publicados.
