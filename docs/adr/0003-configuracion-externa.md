# ADR 0003 · Acciones de archivos en un catálogo externo

Estado: aceptada · 27 de noviembre de 2026

## Contexto

SparkTune 2 trabaja sobre los archivos de una carpeta: reunir capturas, informes y planes, hacer un inventario y calcular huellas. Cada usuario organiza su trabajo de forma distinta, así que necesita cambiar qué extensiones entran en cada acción, añadir acciones o agruparlas en perfiles. Si esas decisiones estuvieran escritas en el código, cada cambio exigiría editar Python, volver a probar y publicar una versión nueva.

El ADR 0001 tomó la misma decisión en la edición PowerShell para los ajustes de Windows. Este ADR la recoge para la versión en Python y para las acciones de archivos.

## Decisión

- Las acciones y los perfiles viven en `acciones.json`. El código solo contiene los **tipos** de acción (`copiar`, `inventario` y `huellas`), cada uno como una clase de `acciones.py`.
- El catálogo se busca en este orden: `--config RUTA`, `./acciones.json` y el catálogo incluido en el paquete. Así la herramienta funciona desde una carpeta vacía y cada proyecto puede tener su propio catálogo.
- `Catalogo.desde_archivo()` valida el catálogo completo **antes** de ejecutar nada. Exige los campos exactos, comprueba los tipos, las extensiones, los ID portables y las referencias de los perfiles, y rechaza las claves repetidas. Un error indica el campo que falla (por ejemplo `acciones[2].tipo`) y sale con el código 3.
- El esquema tiene un campo `version`. Un cambio incompatible del formato subirá ese número en lugar de interpretar mal catálogos antiguos.
- Se usa JSON porque Python lo lee con la biblioteca estándar, es fácil de revisar en un diff y lo admiten todos los editores.

## Consecuencias

- Añadir una acción de un tipo existente o un perfil nuevo solo requiere editar el JSON. `sparktune validar` lo comprueba sin ejecutarlo.
- Añadir un **tipo** nuevo sí exige código: una subclase de `Accion` que se registra sola. El motor y el catálogo no cambian (lo demuestra `test_tipo_nuevo_se_registra_sin_tocar_motor_ni_catalogo`).
- El catálogo solo puede combinar operaciones que el código ya permite. No puede contener rutas de destino, órdenes del sistema ni expresiones que se ejecuten. Por eso un catálogo descargado de otra persona no puede borrar ni sobrescribir archivos.
- Como no se aceptan campos desconocidos, una errata como `"extensions"` se detecta en lugar de ignorarse.

## Alternativas descartadas

- **Acciones escritas en el código:** cada ajuste obligaría a publicar una versión nueva, y el usuario no podría tener catálogos distintos por proyecto.
- **YAML o TOML:** YAML necesita una dependencia externa y su sintaxis implícita (`no` puede leerse como falso) produce errores difíciles de ver. TOML es cómodo para configuración plana, pero las listas de objetos se leen peor que en JSON.
- **Plugins en Python cargados desde el catálogo:** darían más flexibilidad, pero un catálogo podría ejecutar código arbitrario, que es justo lo que este diseño evita.
