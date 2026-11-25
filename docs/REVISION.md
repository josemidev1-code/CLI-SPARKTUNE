# Revisión de SparkTune

SparkTune es un optimizador de Windows; la finalidad es elegir ajustes útiles para cada caso y poder comprobar sus efectos. Esta revisión está en curso. No se ha validado el comportamiento del catálogo completo en Windows.

## Corregido en esta revisión

- Los planes nuevos duplican el plan equilibrado con un GUID válido; usan ajustes explícitos de CPU y tiempos y comunican fallos de `powercfg`. Si falla su configuración, no se activan.
- Cada acción de plan guarda el plan que estaba activo antes de aplicarla. El borrado solo usa GUID registrados y no borra un plan activo.
- El asistente no selecciona acciones automáticamente y vuelve a confirmar acciones irreversibles y de riesgo alto. `--dry-run` no ejecuta `undo` ni escribe entradas de historial.
- Un historial mal formado detiene el proceso sin sobrescribirlo. Las entradas nuevas tienen identificadores únicos y no se reaplica una acción reversible si hay otra aplicación pendiente de deshacer.
- La opción adaptativa se oculta porque no había ningún proceso que vigilara la batería. Vaciar DNS figura como irreversible.

## Pendiente antes de recomendar su uso diario

- Auditar cada acción de `src/catalog`: validar su utilidad y sus comandos; capturar el estado anterior real y restaurarlo, o marcarla como irreversible cuando corresponda. Por ejemplo, hay acciones que restauran un valor fijo o borran valores existentes del registro.
- Revisar los ajustes que silencian errores, especialmente `powercfg`, servicios, red y limpieza; informar de fallos parciales. Evitar afirmar mejoras de batería o de rendimiento sin mediciones.
- Revisar que los planes guardados por versiones anteriores se actualicen o migren de forma segura; esta revisión solo cambia la creación de planes nuevos.
- Verificar instalación, acciones, historial y restauración en Windows 10/11 dentro de una VM con instantánea. Las pruebas de este repositorio usan simulaciones y no sustituyen la ejecución en Windows.
- Medir autonomía, temperatura y rendimiento en un portátil físico antes de afirmar que un perfil mejora la batería. Una VM no representa fielmente la batería, GPU ni gestión de energía del hardware.
- Revisar el flujo de fallos entre la modificación del sistema y la escritura del historial, y la concurrencia entre dos instancias.

Los cambios locales aún no están publicados.
