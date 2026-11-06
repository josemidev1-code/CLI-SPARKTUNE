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
sparktune undo                     # deshace cambios (en orden inverso), --id=xxx para uno
sparktune --help
```

Flags:

```
--perfil=gaming|ofimatica|limpieza|bajos-recursos|portatil-ahorro|portatil-rendimiento|personalizado
--nivel=suave|medio|agresivo
--yes                              # sin confirmaciones (usalo solo si sabes lo que haces)
--dry-run                          # simulacion: muestra lo que haria, no toca nada
--lang=es|en
--no-banner
```

Ejemplo recomendado la primera vez:

```
sparktune --perfil=gaming --nivel=medio --dry-run
```

## Que hace (y que no)

- **Perfiles por caso de uso** (gaming, ofimatica, portatil ahorro/rendimiento, limpieza, PC antiguo) en 3 niveles de agresividad.
- **Deteccion de hardware**: aplica o filtra acciones segun SSD/HDD, bateria, GPU discreta, RAM, portatil/sobremesa.
- **Fichas antes de aplicar**: descripcion, aviso, valor actual -> propuesto, riesgo, reversible, admin, reinicio.
- **Riesgo alto = confirmacion tipando SI**, y aviso de punto de restauracion.
- **Journal** en `~/.sparktune/journal.json` y **undo** de todo o de un cambio concreto.
- **Planes de energia** propios (Ultra Ahorro -> Turbo GPU) creados con `powercfg` duplicando los de fabrica, y restaurables.

No hace "tweaks magicos" que rompen Windows: cada accion tiene undo documentado, y lo que no se
puede deshacer (limpieza de ficheros) esta marcado como irreversible y se confirma aparte.

## Estructura

```
sparktune.ps1        entrada + parseo de flags
install.ps1          instalacion usuario (PATH sin admin)
src/core/            ui (ES/EN, ANSI), detect, engine (preview/apply/undo), journal, banner, catalog loader
src/catalog/         acciones por area: cpu, gpu, memory, network, privacy, cleanup, power, laptop, office, updates
src/data/            profiles.json (id de acciones por perfil/nivel), figlet.txt (banner)
```

## Roadmap

- [ ] Mas perfiles (creativo/edicion, desarrollo)
- [ ] Perfil "red/privacidad" dedicado (acciones `net.*` / `priv.*` hoy solo en personalizado)
- [ ] Smoke-test automatizado en --dry-run (CI en runner de Windows)
- [ ] Capturas en el README
- [ ] Paquete winget

## Licencia

MIT (por anadir)
