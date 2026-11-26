# ADR 0001 — Catálogo externo para los ajustes de setup

Los perfiles de SparkTune combinan aplicaciones, ajustes de Windows y un plan de energía. Los ajustes simples de cuenta se definen en `src/data/acciones.json`, para poder añadirlos y revisarlos con un diff de datos.

El motor interpreta cinco acciones con una misma operación: leer un valor DWORD de HKCU, guardar su destino y valor anterior, y escribir 0 o 1. El catálogo restringe rutas, nombres, compilaciones e IDs. La validación no escribe en el registro. Los planes compartidos solo contienen referencias al catálogo. Una acción con otro mecanismo, como aplicar un plan de energía, conserva su módulo específico.

Con este diseño, la interfaz, las definiciones y la ejecución tienen responsabilidades separadas. Cada acción declarativa se puede combinar en un perfil y revisar con `sparktune ejecutar --dry-run`. Al cambiar qué valor de Windows modifica una acción se debe asignar un ID nuevo, de modo que el historial conserve su significado.
