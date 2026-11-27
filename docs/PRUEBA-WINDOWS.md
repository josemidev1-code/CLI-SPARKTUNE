# Prueba en un portátil con Windows

Este guion comprueba en un equipo real lo que las pruebas automáticas solo pueden simular: el punto de restauración, las instalaciones con WinGet y el efecto en la batería. Las pruebas de `pytest` sustituyen PowerShell, WinGet y el registro por dobles, y un runner de GitHub Actions no tiene batería ni una Protección del sistema que se pueda configurar.

Sigue los apartados **en orden**. Los casos que impiden crear el punto de restauración están al final (apartado 5), porque cambian el estado del equipo para los siguientes.

Rellena la [tabla de resultados](#tabla-de-resultados) mientras avanzas. Un caso falla si el resultado obtenido no coincide con el esperado, aunque SparkTune no muestre ningún error.

## Antes de empezar

### Equipo

- Un portátil físico con batería, con Windows 10 versión 1809 (compilación 17763) o posterior, o con Windows 11. Comprueba la versión con `winver`.
- Una cuenta de administrador. Los puntos de restauración requieren una consola elevada.
- Conexión a Internet por Wi-Fi. El caso 3.2 corta la red con el modo avión, que no desconecta un cable de red.
- Al menos 20 GiB libres en `C:`.

### Precauciones

- Haz una copia de tus documentos. SparkTune no los toca, pero en este guion se instalan programas y se usa Restaurar sistema.
- El caso 5.3 desactiva la Protección del sistema. **Al desactivarla, Windows borra todos los puntos de restauración de `C:` y las «Versiones anteriores» de tus archivos que dependen de ellos.** Si las necesitas, sáltate ese caso y márcalo como omitido.
- No desinstales programas que ya tenías antes de la prueba. El guion indica en cada caso qué hacer si ya tienes alguno de los que usa.
- No uses un equipo de trabajo ni del centro. Algunas políticas de empresa bloquean WinGet o la Protección del sistema, y los resultados no serían representativos.

### Instalación

Abre PowerShell como administrador:
- En Windows 11: clic derecho en Inicio → «Terminal (administrador)».
- En Windows 10: clic derecho en Inicio → «Windows PowerShell (administrador)».
- Si solo aparece «Símbolo del sistema», busca «PowerShell» en Inicio y elige «Ejecutar como administrador».

Comprueba las herramientas:

```powershell
winget --version
git --version
uv --version
```

- Si `winget` no responde, actualiza «Instalador de aplicaciones» desde Microsoft Store.
- Si `git` no responde, instálalo con `winget install --id Git.Git --exact --source winget` y vuelve a abrir la consola. uv lo necesita para instalar desde una URL `git+https`.
- Si `uv` no responde, instálalo siguiendo https://docs.astral.sh/uv/getting-started/installation/ y vuelve a abrir la consola.

Instala SparkTune desde la rama del PR, porque `main` todavía no contiene la versión 2:

```powershell
uv tool install git+https://github.com/josemidev1-code/CLI-SPARKTUNE@codex/sparktune-python
sparktune version
```

- `sparktune version` debe mostrar `2.0.0`.
- Si la consola no encuentra el comando, ejecuta `uv tool update-shell` y ábrela de nuevo.
- Si tenías la edición 1.x, comprueba con `Get-Command sparktune -All` que se ejecuta la versión 2.
- Si no puedes instalar Git, hay una alternativa sin él: `uv tool install https://github.com/josemidev1-code/CLI-SPARKTUNE/archive/refs/heads/codex/sparktune-python.zip`.

### Registro de la sesión

Guarda la salida de la consola en un archivo para poder copiar después los mensajes exactos:

```powershell
New-Item -ItemType Directory -Force "$HOME\sparktune-prueba" | Out-Null
Start-Transcript -Path "$HOME\sparktune-prueba\sesion.txt" -Append
```

`sparktune` y `winget` son programas externos a PowerShell. Su salida no pasa directamente a la transcripción: PowerShell la copia de la pantalla cuando termina cada orden y pierde las líneas que ya no caben en la ventana. Por eso:
- Después del caso 1.1, abre `sesion.txt` y comprueba que la ayuda aparece completa.
- Si faltan líneas, maximiza la ventana o copia los mensajes de la pantalla. En Windows Terminal también puedes usar «Exportar texto» en el menú de la pestaña.

### Estado inicial

Ejecuta estas órdenes y anota los resultados en la tabla «Equipo»:

```powershell
Get-ComputerInfo -Property OsName, OsVersion, OsBuildNumber, CsModel
Get-ComputerRestorePoint | Select-Object SequenceNumber, Description, @{n='Fecha'; e={$_.ConvertToDateTime($_.CreationTime)}}
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency
winget list LibreOffice
winget list Firefox
winget list "Creative Cloud"
```

- `winget list` busca aquí por nombre, porque un Firefox en español instalado desde mozilla.org puede tener otro identificador, como `Mozilla.Firefox.es-ES`. Anota los identificadores que aparezcan.
- Anota también si Git y uv ya estaban instalados antes de la prueba.
- La primera vez que se usa WinGet, puede pedir que aceptes los acuerdos de un origen. Respóndelo tú y anótalo. SparkTune instala solo desde el origen `winget` y no acepta ningún acuerdo por ti.
- Si `SystemRestorePointCreationFrequency` no muestra nada, es que el valor no existe. Anota «no existe».
- Abre `SystemPropertiesProtection.exe` y anota si la protección de `C:` está «Activada». Si está desactivada, actívala con `Enable-ComputerRestore -Drive "C:\"` y anótalo para dejarla como estaba al terminar.

**Perfil de instalación.** Los apartados 2 y 3 instalan las dos aplicaciones de `ofimatica`: LibreOffice y Firefox.
- Si ya tienes alguna de las dos, con cualquier identificador, usa en los apartados 2 y 3.2 el perfil `streaming` en su lugar. Sustituye `TheDocumentFoundation.LibreOffice` por `OBSProject.OBSStudio` y `Mozilla.Firefox` por `Audacity.Audacity` en las órdenes **y en los resultados esperados**. No copies los bloques de desinstalación del guion: ejecuta solo las órdenes que muestre SparkTune.
- Anota en la tabla qué perfil usas y qué aplicaciones ya tenías.

### Quitar el límite de puntos durante la prueba

Windows no crea un punto de restauración nuevo si ya hay otro de las últimas 24 horas, aunque lo haya creado Windows Update o un instalador. En ese caso solo muestra una advertencia. Casi todos los casos del guion crean un punto, así que quita el límite hasta el caso 5.2, donde se vuelve a poner para probarlo:

```powershell
$clave = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
New-ItemProperty $clave -Name SystemRestorePointCreationFrequency -PropertyType DWord -Value 0 -Force
```

El valor está en minutos y `0` permite crear un punto cada vez. Con el límite quitado, el instalador MSI de LibreOffice puede crear también su propio punto («Installed …»). Es normal.

## 1. Comprobaciones sin cambios

Ninguno de estos casos debe instalar nada ni crear puntos de restauración. Al terminar el apartado, `Get-ComputerRestorePoint` debe mostrar la misma lista que en el estado inicial.

**1.1 · Ayuda y perfiles.** Ejecuta `sparktune --help` y `sparktune perfiles`.
Esperado: se muestran la ayuda y los 13 perfiles, entre ellos `android`, `ofimatica` y `video-adobe`.

**1.2 · Simulación.** Ejecuta `sparktune preparar ofimatica --simular`.
Esperado:
- «Equipo observado» indica la RAM y el disco reales. Si el portátil está desenchufado, dice «con batería, desenchufado», y si está enchufado, «con batería, enchufado». Si dice «enchufado» estando desenchufado, es un fallo: anótalo.
- Se listan LibreOffice y Firefox, cada uno con su orden `winget uninstall`.
- El último mensaje es `Simulación terminada.`.

**1.3 · Rechazarlo todo.** Ejecuta `sparktune preparar ofimatica` y pulsa Enter en cada pregunta.
Esperado: `Sin cambios.`, sin puntos de restauración nuevos ni instalaciones.

**1.4 · Asesor local.** Ejecuta `sparktune asesorar "Quiero editar vídeos con Adobe" --local`.
Esperado:
- Se recomienda `video-adobe` y «Con tu equipo» muestra la RAM y el disco reales.
- La última línea es `Todavía no se ha aplicado nada. Para revisar el plan, ejecuta sparktune preparar video-adobe --simular`.

**1.5 · Asesor sin clave.** Sin `--local` ni `GROQ_API_KEY` en la sesión. Si la tienes definida, ejecuta antes `Remove-Item Env:GROQ_API_KEY`.

1. Ejecuta `sparktune asesorar "Quiero editar vídeos con Adobe"`.

Esperado:
- Primero aparece `Configura GROQ_API_KEY en tu sesión o pasa un archivo privado con --env-file.`.
- Después, la misma recomendación local del caso 1.4.
- El código de salida es 0. Compruébalo con `$LASTEXITCODE`.

Si tienes una clave de Groq, repite el caso en el 3.2 con el modo avión activado y la clave en la sesión. Esperado: `Falló la conexión con Groq. Comprueba la red y vuelve a intentarlo.` y la recomendación local.

## 2. Instalación con punto de restauración

**2.1 · Un punto antes del primer cambio.**

1. Ejecuta `sparktune preparar ofimatica`.
2. Responde `s` a LibreOffice y `s` a Firefox. Si se pregunta por la transparencia, responde `n`.

Esperado:
- Antes de la primera instalación aparece `Punto verificado: SparkTune-<identificador>`.
- Después aparecen `Disponible: TheDocumentFoundation.LibreOffice` y `Disponible: Mozilla.Firefox`, en ese orden.
- Al final aparecen `Preparación terminada.`, la lista «Cambios aplicados y cómo deshacerlos uno a uno» con las dos órdenes `winget uninstall` y el aviso de Restaurar sistema.

Compruébalo:

```powershell
Get-ComputerRestorePoint | Select-Object -Last 3 SequenceNumber, Description, @{n='Fecha'; e={$_.ConvertToDateTime($_.CreationTime)}}
winget list --id TheDocumentFoundation.LibreOffice --exact --source winget
winget list --id Mozilla.Firefox --exact --source winget
```

Debe haber **exactamente un** punto `SparkTune-…` nuevo, con la descripción que mostró SparkTune y creado antes que cualquier punto «Installed …». Las dos aplicaciones deben estar instaladas.

**2.2 · Qué deshace Restaurar sistema (sin restaurar).**

1. Ejecuta `rstrui.exe`. Si aparece la opción «Elegir otro punto de restauración», márcala. Pulsa Siguiente.
2. Selecciona el punto `SparkTune-…`. Si no lo ves, marca «Mostrar más puntos de restauración».
3. Pulsa «Detectar programas afectados». En algunas versiones se llama «Buscar programas afectados».
4. Cierra el asistente con Cancelar, **sin** restaurar.

Esperado: LibreOffice y Firefox aparecen entre los programas que se eliminarían. Así se comprueba lo que promete SparkTune: «Windows quita los programas y controladores instalados después de ese punto y no toca tus documentos».

**2.3 · Deshacer uno a uno.** Ejecuta las órdenes que mostró SparkTune. Con `ofimatica` son estas; con `streaming`, son las de OBS Studio y Audacity:

```powershell
winget uninstall --id Mozilla.Firefox --exact
winget uninstall --id TheDocumentFoundation.LibreOffice --exact
```

Esperado: las dos desinstalaciones terminan bien y `winget list` ya no muestra esas aplicaciones.

## 3. WinGet en situaciones reales

**3.1 · Aplicación ya instalada.** Este caso usa siempre `ofimatica` y Firefox.

1. Si no tienes Firefox, instálalo por tu cuenta: `winget install --id Mozilla.Firefox --exact --source winget`. Si ya lo tenías al empezar con el identificador `Mozilla.Firefox`, no hace falta. Si tu Firefox tiene otro identificador, como `Mozilla.Firefox.es-ES`, omite este caso: SparkTune instalaría `Mozilla.Firefox` además del tuyo.
2. Ejecuta `sparktune preparar ofimatica`. Responde `n` a LibreOffice, `s` a Firefox y `n` a la transparencia, si aparece.

Esperado:
- Aparece `Mozilla.Firefox ya estaba instalado.` y al final `Preparación terminada.`.
- Puede crearse un punto de restauración aunque no se instale nada. No es un fallo.
- **Firefox no debe aparecer en «Cambios aplicados y cómo deshacerlos uno a uno»**, porque SparkTune no lo instaló. Si aparece, anótalo como fallo: seguir esa lista desinstalaría un programa que ya tenías. Es un error conocido de la versión actual, apuntado en `docs/RELEVO.md`.

Si en lugar de «ya estaba instalado» aparece `WinGet terminó con código 0x…`, anota el código: tu versión de WinGet usa un código que SparkTune todavía no reconoce.

**3.2 · Fallo de red a mitad del lote.** Comprueba que lo ya instalado se puede deshacer y que lo pendiente no se intenta.

Si ya tenías LibreOffice o Firefox al empezar, haz este caso con `streaming` y sustituye los identificadores como en el apartado 2.

1. Desinstala Firefox si lo instalaste en el caso 3.1. LibreOffice no debe estar instalado, porque el caso 2.3 lo desinstaló.
2. Ejecuta `sparktune preparar ofimatica` y responde `s` a LibreOffice.
3. Cuando aparezca `Disponible: TheDocumentFoundation.LibreOffice`, y antes de responder a Firefox, activa el modo avión.
4. Responde `s` a Firefox y espera a que termine.
5. Desactiva el modo avión.

Esperado:
- Aparece `Preparación detenida. WinGet terminó con código 0x… para Mozilla.Firefox.`. Anota el código.
- La lista «Cambios aplicados y cómo deshacerlos uno a uno» incluye **solo** LibreOffice, y aparece el aviso de Restaurar sistema.
- El código de salida es 1.

Al terminar, desinstala LibreOffice con `winget uninstall --id TheDocumentFoundation.LibreOffice --exact`.

**3.3 · Adobe Creative Cloud, que requiere cuenta.** Si ya tenías Creative Cloud, omite este caso y no lo desinstales.

1. Ejecuta `sparktune preparar video-adobe`. Responde `s` a `Adobe.CreativeCloud`, `n` a `VideoLAN.VLC` y `n` a la transparencia, si aparece.
2. Si el instalador de Adobe abre una ventana o pide confirmación, acéptala tú y anótalo.

Esperado:
- WinGet instala Creative Cloud. Si falla, anota el código y si se abrió alguna ventana.
- SparkTune **no** instala Premiere Pro ni After Effects. Los pasos indican que hay que iniciar sesión con un Adobe ID y comprobar la licencia, la suscripción o la prueba.
- Para deshacerlo, indica que primero se desinstalan Premiere Pro y After Effects desde Creative Cloud, y después se ejecuta `winget uninstall --id Adobe.CreativeCloud --exact`.

Para dar el caso por bueno no hace falta iniciar sesión ni activar una prueba de Adobe. Al terminar, desinstala Creative Cloud con esa orden. Sus servicios en segundo plano alterarían la medición de batería del apartado 6.

## 4. Ajuste de transparencia

SparkTune propone desactivar los efectos de transparencia cuando el equipo funciona con batería o tiene 8 GiB de RAM o menos.

**4.1 · Desactivar y revertir.**

1. Activa la transparencia en Configuración → Personalización → Colores y desenchufa el portátil.
2. Ejecuta `sparktune preparar ofimatica`. Responde `n` a las aplicaciones y `s` a la transparencia.

Esperado:
- Antes del ajuste aparece `Punto verificado: SparkTune-…`.
- Después aparece `Efectos de transparencia desactivados. Puedes reactivarlos en Configuración > Personalización > Colores.`.
- `EnableTransparency` pasa de 1 a 0:

  ```powershell
  Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency
  ```

Para revertirlo, vuelve a activar la transparencia en Personalización → Colores y comprueba que `EnableTransparency` vuelve a 1.

Si no se pregunta por la transparencia estando desenchufado, revisa la línea «Equipo observado». Si dice «enchufado», es el fallo del caso 1.2.

## 5. Cuando no se puede crear el punto

En estos casos SparkTune debe detenerse **antes de instalar nada**. Ejecuta `winget list --id TheDocumentFoundation.LibreOffice --exact --source winget` antes y después de cada caso. Las dos salidas deben coincidir, y no debe aparecer ningún `Disponible:`.

**5.1 · Consola sin administrador.**

1. Abre una consola de PowerShell normal, sin elevar.
2. Ejecuta `sparktune preparar ofimatica` y responde `s` a LibreOffice.

Esperado: `Preparación detenida.` seguido del error de permisos de Windows, código de salida 1 y ninguna instalación.

Esta ventana no tiene transcripción: copia el mensaje desde la pantalla. Después ciérrala y vuelve a la consola de administrador. Si la consola normal no encuentra `sparktune`, anótalo: la consola elevada usa otro usuario u otro PATH.

**5.2 · Límite de 24 horas.**

1. Vuelve a poner el límite. Si en el estado inicial el valor no existía, bórralo:

   ```powershell
   Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name SystemRestorePointCreationFrequency
   ```

   Si existía, vuelve a darle su valor con `New-ItemProperty`, como en «Quitar el límite». Si tu valor original era menor que 1440, ponlo a 1440 solo para este caso y restaura el original en la limpieza.
2. Ejecuta `sparktune preparar ofimatica` y responde `s` a LibreOffice.

Esperado:
- Tras alrededor de medio minuto de comprobaciones aparece `Preparación detenida. No se pudo verificar un punto de restauración nuevo…`, con la mención del límite de 24 horas.
- El código de salida es 1 y no se instala nada.
- Funciona porque los casos anteriores ya han creado puntos hoy.

**5.3 · Protección del sistema desactivada.** Recuerda que desactivarla borra los puntos existentes y las «Versiones anteriores» de tus archivos.

1. Desactívala con `Disable-ComputerRestore -Drive "C:\"`. También puedes hacerlo en `SystemPropertiesProtection.exe` → `C:` → Configurar → Desactivar.
2. Ejecuta `sparktune preparar ofimatica` y responde `s` a LibreOffice.
3. Vuelve a activarla con `Enable-ComputerRestore -Drive "C:\"`.

Esperado en el paso 2: `Preparación detenida.` seguido de un error de Windows o del mensaje de verificación del caso 5.2, código de salida 1 y ninguna instalación. Copia el mensaje exacto en la tabla.

## 6. Autonomía

SparkTune **no afirma que la batería dure más** al quitar la transparencia. Este apartado mide si hay alguna diferencia.

**6.1 · Informe de batería.**

```powershell
powercfg /batteryreport /output "$HOME\sparktune-prueba\bateria-antes.html"
```

El informe sale en el idioma de Windows. Anota en la tabla:
- «Capacidad de diseño» (Design capacity) y «Capacidad de carga completa» (Full charge capacity). Si la segunda es mucho menor, la batería está desgastada: las tandas durarán menos, pero siguen siendo comparables entre sí.
- En «Estimaciones de duración de la batería» (Battery life estimates), la estimación final, calculada con todas las descargas desde que se instaló Windows.

**6.2 · Medición.** Compara la misma carga con la transparencia activada (A) y desactivada (B), cambiándola a mano en Personalización → Colores.

Antes de empezar, anota el plan de energía, el brillo y el estado del Bluetooth para dejarlos igual al final. En todas las tandas, las condiciones deben ser las mismas:
- La misma carga inicial: la máxima que permita el equipo. Algunos portátiles limitan la carga al 80 % para cuidar la batería.
- El mismo plan de energía y el mismo brillo, fijado a mano y con el brillo automático desactivado.
- Wi-Fi activado, Bluetooth desactivado y ningún periférico USB.
- La misma carga de trabajo, por ejemplo un vídeo local en bucle con el reproductor de Windows y una página web fija en el navegador.
- Ninguna actualización de Windows en curso. Compruébalo en Windows Update.

Procedimiento:
1. Desenchufa el portátil y anota la hora y el porcentaje.
2. Pasados 60 minutos, anota el porcentaje y genera un informe nuevo, por ejemplo `bateria-tanda1.html`. En «Uso de la batería» (Battery usage), anota la energía consumida en mWh durante la tanda. Es más precisa que el porcentaje.
3. Haz al menos dos tandas de cada configuración, alternándolas (A, B, A, B), para que la temperatura o el desgaste no favorezcan siempre a la misma.

Si A y B difieren menos que dos tandas de la misma configuración entre sí, el ajuste no produce una diferencia medible. Ese resultado también es válido: anótalo así y no afirmes una mejora.

## 7. Limpieza final

Compara con el estado inicial que anotaste:
- Comprueba con `winget list` que no queda ninguna aplicación instalada por el guion: LibreOffice, Firefox, OBS Studio, Audacity o Creative Cloud. Desinstala solo las que no tenías al empezar. **Si ya tenías Firefox, no lo desinstales, aunque SparkTune lo listara en el caso 3.1.**
- Si instalaste Git o uv solo para la prueba, puedes desinstalarlos. Git se quita con `winget uninstall --id Git.Git --exact`.
- Deja la transparencia como estaba.
- Comprueba que `SystemRestorePointCreationFrequency` vuelve a tener el valor del estado inicial. Si no existía, ya lo borraste en el caso 5.2, y `Get-ItemProperty` no debe mostrar nada.
- Los puntos `SparkTune-…` de hoy quedan en el equipo si no hiciste el caso 5.3. Windows no permite borrarlos uno a uno desde la interfaz: déjalos y anótalo.
- Deja la Protección del sistema de `C:` como estaba al empezar.
- Vuelve a dejar el plan de energía, el brillo, el brillo automático y el Bluetooth como estaban antes del apartado 6.
- Si quieres, quita SparkTune con `uv tool uninstall sparktune`.
- Ejecuta `Stop-Transcript`.

## Tabla de resultados

Copia estas tablas en el PR o en una issue. **No adjuntes los informes HTML de batería**: contienen el nombre del equipo y el número de serie de la batería. Copia en la tabla solo las capacidades y los consumos. Antes de compartir `sesion.txt`, borra su cabecera, que incluye tu usuario y el nombre del equipo, y comprueba que no contiene claves.

En «Resultado obtenido», pon el mensaje exacto o el código cuando el resultado no coincida con el esperado.

**Equipo y estado inicial**

| Dato | Valor |
| --- | --- |
| Fecha | |
| Modelo del portátil | |
| Windows (versión y compilación) | |
| Versiones de WinGet y de SparkTune | |
| RAM y disco libre | |
| Puntos de restauración iniciales (número y fecha del último) | |
| Protección del sistema en `C:` al empezar | |
| `SystemRestorePointCreationFrequency` al empezar | |
| `EnableTransparency` al empezar | |
| Aplicaciones que ya tenías (LibreOffice, Firefox, Creative Cloud) y su identificador | |
| ¿Tenías Git y uv antes de la prueba? | |
| Perfil del apartado 2 (`ofimatica` o `streaming`) | |
| ¿WinGet pidió aceptar acuerdos? | |
| Capacidad de diseño / de carga completa | |
| Duración estimada (Battery life estimates) | |

**Casos**

| Caso | Resultado esperado | Resultado obtenido | ¿Coincide? | Notas |
| --- | --- | --- | --- | --- |
| 1.1 Ayuda y perfiles | Ayuda y 13 perfiles | | | ¿`sesion.txt` completa? |
| 1.2 Simulación | `Simulación terminada.`, batería bien indicada | | | |
| 1.3 Rechazarlo todo | `Sin cambios.`, sin punto | | | |
| 1.4 Asesor local | `video-adobe` con el equipo real | | | |
| 1.5 Asesor sin clave | Aviso de la clave, recomendación local, código 0 | | | |
| 2.1 Punto antes del primer cambio | Un punto `SparkTune-…` y dos aplicaciones | | | |
| 2.2 Programas afectados | LibreOffice y Firefox en la lista | | | |
| 2.3 Deshacer uno a uno | Las dos desinstalaciones terminan bien | | | |
| 3.1 Ya instalada | `ya estaba instalado.`, Firefox fuera de «Cambios aplicados» | | | Código si falla: |
| 3.2 Fallo de red | Solo LibreOffice en la reversión, código 1 | | | Código de WinGet: |
| 3.3 Creative Cloud | Instalada, sin Premiere ni After Effects | | | ¿Ventanas de Adobe? |
| 4.1 Transparencia | Punto y `EnableTransparency` a 0 | | | |
| 5.1 Sin administrador | Detenido antes de instalar, código 1 | | | Mensaje de Windows: |
| 5.2 Límite de 24 horas | Detenido antes de instalar, código 1 | | | |
| 5.3 Protección desactivada | Detenido antes de instalar, código 1 | | | Mensaje de Windows: |
| 7 Limpieza | Equipo igual que al empezar | | | |

**Autonomía** (60 minutos por tanda)

| Tanda | Configuración | Hora de inicio | % al empezar | % a los 60 min | Energía consumida (mWh) |
| --- | --- | --- | --- | --- | --- |
| 1 | A · transparencia activada | | | | |
| 2 | B · transparencia desactivada | | | | |
| 3 | A · transparencia activada | | | | |
| 4 | B · transparencia desactivada | | | | |

Conclusión sobre la autonomía (diferencia media entre A y B, comparada con la diferencia entre tandas de la misma configuración):
