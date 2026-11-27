# Relevo · SparkTune Python · 27 de noviembre de 2026

Objetivo acordado: preparar equipos para necesidades reales, usar IA como asesor, poder simular y combinar acciones y confirmar cada cambio de sistema. La entrega requiere Python 3.12, Typer, uv y pruebas en los tres sistemas. Conservar el código PowerShell como versión anterior.

Plan de implementación y verificación:
- Motor de archivos y catálogo JSON externo. Trabajar solo en la carpeta elegida, sin sobrescrituras. Probar rutas inválidas, colisiones, simulación y configuración inválida.
- Perfiles y preparación Windows con hardware real, previsualización, confirmación individual y punto de restauración comprobado. Probar con ejecutores simulados y reservar comprobación real para la VM.
- Dos consultas de IA que ayuden a elegir y comprender los perfiles. Rechazar respuestas fuera de catálogo y ofrecer alternativas locales.
- Empaquetado, interfaz, pruebas del comando instalado, matriz CI, guía de VM y simulacro de defensa. Registrar resultados y limitaciones aquí.
