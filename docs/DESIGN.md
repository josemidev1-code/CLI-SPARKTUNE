# SparkTune — Diseño interno

Guia para quien quiera contribuir. El producto final: una CLI de optimizacion de Windows
segura, reversible y transparente. Ninguna accion "magica": todo se documenta, se puede
deshacer y se muestra antes de ejecutar.

## Arquitectura

```
sparktune.ps1        entrada: parseo de flags, ruteo de comandos
src/core/
  globals.ps1        rutas y version (Global:ST*)
  ui.ps1             ANSI + diccionario ES/EN (T/T) + Read-Host/ReadKey wrappers
  banner.ps1         animacion de arranque (scramble + spark)
  detect.ps1         Get-STHardware via CIM (devuelve hashtable estandar $hw)
  journal.ps1        ~/.sparktune/journal.json, escritura atomica, seq/undo por refSeq
  engine.ps1         preview/apply/undo, wizard, status/analyze/history/doctor/report/apps
  catalog.ps1        agrega src/catalog/*.ps1 y resuelve perfiles desde src/data/profiles.json
src/catalog/*.ps1    modulos por area, cada uno exporta Get-<Area>CatalogActions
src/data/
  profiles.json      perfil x nivel -> lista de ids (o '*')
  apps.json          catalogo de apps para el instalador winget
  figlet.txt         fuente del logo estatico (fallback)
```

## Contrato de accion (obligatorio en cada hashtable)

| clave | tipo | notas |
|---|---|---|
| `id` | str | unico, prefix `area.`; es el identificador del journal — **no renombrar nunca** |
| `titulo` / `titulo_en` | str | UI ES/EN |
| `descripcion` / `descripcion_en` | str | ficha |
| `aviso` / `aviso_en` | str opcional | aviso extra |
| `categoria` | str | agrupacion UI |
| `riesgo` | sin\|bajo\|medio\|alto | alto = confirmacion tipeando SI |
| `reversible` | bool | false solo en limpieza de ficheros |
| `admin`, `reinicio`, `needsRP` | bool | flags de UI/flujo |
| `perfiles`, `niveles` | arrays | fallback si profiles.json no cubre |
| `detect` | scriptblock($hw) | filtra segun hardware; nunca debe lanzar |
| `preview` | scriptblock() | texto "actual -> propuesto" (se registra en journal como prevState) |
| `apply` | scriptblock() | ejecuta; debe lanzar en error |
| `undo` | scriptblock() | reversion completa |
| `undoCmd` | str | comando manual de ultimo recurso (va al journal) |

Extras opcionales: `applyPre` (scriptblock antes de apply), estado auxiliar via
`Set-STStateFile`/`Get-STStateFile` (`~/.sparktune/state-<id>.json`).

## Flujo

1. `Load-STCatalog` dot-sourcea todos los `src/catalog/*.ps1` y agrega las acciones, normalizando campos.
2. `Resolve-STProfile`: si `profiles.json` tiene el perfil+nivel, usa sus ids; si no, `perfiles`/`niveles` de la accion. En ambos casos filtra con `detect`.
3. Wizard: menu perfil → nivel → lista multiselect (pre-seleccionados riesgo bajo/medio) → confirmacion global → apply secuencial con progress bar.
4. `Invoke-STApply`: dry-run → restore point (si needsRP) → admin check → confirmacion (SI literal si alto) → apply → journal `applied`.
5. `sparktune undo`: pendientes en orden inverso, `--id` o `--category` para filtrar.

## Reglas de diseno (por algo existen)

- **Nunca** tocar Defender, UAC, Windows Update de seguridad o AppLocker. Las acciones
  `sec.*` solo endurecen o informan.
- Limpieza de ficheros = `reversible=$false` + confirmacion explicita.
- Toda clave de registro que se cambie debe guardar su valor previo (`__ST_prev_*` o state file).
- Compat PS **5.1**: nada de `??`, `?.`, ni `&&`. Todos los `.ps1` con **UTF-8 BOM**.
- `detect` no debe escribir ni tocar el sistema; solo leer.
- Nuevas dependencias externas: ninguna (solo winget para `apps`, que ademas es opt-in y interactivo).

## Tests y CI

- `tests/run-tests.ps1` — sin dependencias, ejecuta en 5.1 y 7.x: BOM, JSON valido,
  contrato de campos, ids unicos, perfiles↔catalogo, ES/EN simetrico, `detect` con hw
  simulado, specs de planes de energia, apps.json coherente.
- `.github/workflows/ci.yml` — `windows-latest`: job `contract` + job `dryrun`
  (8 perfiles × 3 niveles, stdin cerrado + `--dry-run`).
- Los bloques `apply`/`undo` **no** se ejecutan en tests: requieren Windows real y
  privilegios. Un cambio en ellos se valida a mano en dry-run y en una maquina de pruebas.

## Anadir una accion (checklist)

1. Crear el bloque en `src/catalog/<area>.ps1` con el contrato completo.
2. Anadir el id a los perfiles/niveles que corresponda en `src/data/profiles.json`.
3. `powershell tests/run-tests.ps1` debe pasar (tambien vale `pwsh` en Linux).
4. Probar en Windows: `sparktune --perfil=X --nivel=Y --dry-run`, ver la ficha, y aplicar+undo real.
5. Actualizar `CHANGELOG.md`.
