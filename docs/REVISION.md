# Revisión de SparkTune

SparkTune es un optimizador de Windows; la finalidad es elegir ajustes útiles para cada caso y poder comprobar sus efectos. Esta revisión está en curso. No se ha validado el comportamiento del catálogo completo en Windows.

## Corregido en esta revisión

- Los planes nuevos duplican el plan equilibrado con un GUID válido; usan ajustes explícitos de CPU y tiempos y comunican fallos de `powercfg`. Si falla su configuración, no se activan.
- Cada acción de plan guarda el plan que estaba activo antes de aplicarla. El borrado solo usa GUID registrados y no borra un plan activo.
- El asistente no selecciona acciones automáticamente y vuelve a confirmar acciones irreversibles y de riesgo alto. `--dry-run` no ejecuta `undo` ni escribe entradas de historial.
- Un historial mal formado detiene el proceso sin sobrescribirlo. Las entradas nuevas tienen identificadores únicos y no se reaplica una acción reversible si hay otra aplicación pendiente de deshacer.
- La opción adaptativa se oculta porque no había ningún proceso que vigilara la batería. Vaciar DNS figura como irreversible.
- Se han auditado las 81 acciones del catálogo. Las 50 que se declaraban reversibles sin guardar el estado anterior real quedan **en revisión**: la lista `$script:STEnRevision` de `src/core/catalog.ps1`. `Test-STApplies` las rechaza, así que no aparecen en el asistente, los perfiles, `setup`, `ejecutar` ni la IA. Siguen en el catálogo para que `undo` pueda deshacer aplicaciones anteriores. Tienen alguno de estos defectos:
  - Restauran un valor fijo en lugar del anterior. Por ejemplo, los servicios vuelven siempre a `Auto` y los valores de `powercfg`, a un número concreto.
  - Borran valores del registro que podían existir antes de aplicarlas.
  - Si el valor no existía, el undo crea uno. Por ejemplo, `net.smb-hardening` escribe `AllowInsecureGuestAuth=1`, que relaja la seguridad respecto a no tener la directiva.
  - El apply no guarda nada que el undo pueda leer. En `cpu.fgboost`, el undo lee una copia que nunca se escribe, y en `mem.compact` vuelve a escribir el valor actual.
- En una segunda revisión pasaron también a revisión `net.doh` y `net.wsl-nat`, ya son 52:
  - `net.doh`: el undo borra las entradas DoH de 1.1.1.1, 8.8.8.8 y 9.9.9.9 aunque existieran antes (Windows 11 las trae de serie). Además, con dos adaptadores activos, el segundo `Add-DnsClientDohServerAddress` falla antes de guardar el estado.
  - `net.wsl-nat`: si `~/.wslconfig` ya tiene una sección `[wsl2]`, el apply lo reescribe entero y se pierden sus otras opciones mientras está aplicado.
- Se siguen ofreciendo las acciones que guardan el estado con `Set-STStateFile` (los planes de energía y los ajustes de `setup`), `off.startup-bloat` (guarda cada entrada borrada de `Run`), las informativas y las irreversibles, que se confirman una por una. `tests/run-tests.ps1` comprueba que ninguna acción en revisión se ofrece y que una acción reversible nueva no puede ofrecerse sin guardar su estado.

## Pendiente antes de recomendar su uso diario

- Corregir las acciones en revisión: cada apply debe guardar con `Set-STStateFile` el valor y el tipo anteriores, incluido si el valor no existía, y su undo debe restaurarlos o borrar el valor. Después se quita la acción de la lista y se prueba en una VM con instantánea.
- `off.startup-bloat` restaura las entradas de `Run` como `REG_SZ`. Si alguna era `REG_EXPAND_SZ`, cambia de tipo.
- Revisar los ajustes que silencian errores, especialmente `powercfg`, servicios, red y limpieza; informar de fallos parciales. Evitar afirmar mejoras de batería o de rendimiento sin mediciones.
- Revisar que los planes guardados por versiones anteriores se actualicen o migren de forma segura; esta revisión solo cambia la creación de planes nuevos.
- Verificar instalación, acciones, historial y restauración en Windows 10/11 dentro de una VM con instantánea. Las pruebas de este repositorio usan simulaciones y no sustituyen la ejecución en Windows.
- Medir autonomía, temperatura y rendimiento en un portátil físico antes de afirmar que un perfil mejora la batería. Una VM no representa fielmente la batería, GPU ni gestión de energía del hardware.
- Revisar el flujo de fallos entre la modificación del sistema y la escritura del historial, y la concurrencia entre dos instancias.

Los cambios locales aún no están publicados.
