# ADR 0002 · Motor portátil y asesor de IA

El registro de Windows y WinGet resuelven necesidades específicas de ese sistema. Los archivos de trabajo, la consulta de perfiles y la explicación del plan también sirven en Linux y macOS. Python 3.12 y Typer proporcionan el comando común. La parte de Windows consulta los recursos del equipo y ofrece las operaciones disponibles.

El catálogo de archivos separa los datos de las operaciones permitidas. Añadir una selección de archivos para un tipo existente solo requiere JSON. La validación ocurre antes de ejecutar. El catálogo empaquetado permite usar la herramienta desde una carpeta vacía.

El asesor utiliza el objetivo declarado y un resumen del equipo para recomendar un perfil permitido. El ejecutor construye sus órdenes a partir de sus propios datos. Esto permite cambiar el modelo sin delegar la ejecución de comandos al proveedor. La elección manual y la orientación local siguen disponibles cuando falla la conexión.
