# SparkTune cleanup.ps1 — categoria A: limpieza y almacenamiento.
# Las limpiezas no son reversibles (reversible=$false) pero son seguras: solo temporales.

function STDirBytes($items) {
    $b = 0
    foreach ($f in $items) { try { $b += $f.Length } catch { } }
    return $b
}
function Get-TempFiles([string]$path) {
    Get-ChildItem -Path $path -Recurse -Force -File -ErrorAction SilentlyContinue
}
function Clear-STTempDir([string]$path) {
    if (-not (Test-Path $path)) { return }
    Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-CleanupCatalogActions {
    $A = @()

    $A += @{
        id='clean.temp-user'
        titulo='Limpiar temporales de usuario (%TEMP%)'
        titulo_en='Clean user temp (%TEMP%)'
        descripcion='Borra archivos temporales de tu usuario. Archivos en uso se omiten.'
        descripcion_en='Deletes your user temp files. In-use files are skipped.'
        categoria='cleanup'; riesgo='sin'; reversible=$false; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('limpieza','gaming','ofimatica','bajos-recursos','portatil-ahorro','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ "  $(('{0:N0}' -f (STDirBytes (Get-TempFiles $env:TEMP) / 1MB))) MB temporales  ->  0 MB" }
        apply={ Clear-STTempDir $env:TEMP }
        undo={ Write-STWarn 'limpieza: no reversible' }
        undoCmd='n/a'
    }
    $A += @{
        id='clean.temp-system'
        titulo='Limpiar temporales de sistema (C:\Windows\Temp)'
        titulo_en='Clean system temp (C:\Windows\Temp)'
        descripcion='Borra temporales del sistema. Requiere admin.'
        descripcion_en='Deletes system temp files. Needs admin.'
        categoria='cleanup'; riesgo='bajo'; reversible=$false; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('limpieza','bajos-recursos','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ "  $(('{0:N0}' -f (STDirBytes (Get-TempFiles "$env:WINDIR\Temp") / 1MB))) MB temporales  ->  0 MB" }
        apply={ Clear-STTempDir "$env:WINDIR\Temp" }
        undo={ Write-STWarn 'limpieza: no reversible' }
        undoCmd='n/a'
    }
    $A += @{
        id='clean.dns'
        titulo='Vaciar cache DNS'
        titulo_en='Flush DNS cache'
        descripcion='Resuelve dominios obsoletos o mal resueltos.'
        descripcion_en='Fixes stale or wrong DNS entries.'
        categoria='cleanup'; riesgo='sin'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('limpieza','gaming','ofimatica','portatil-ahorro','portatil-rendimiento','bajos-recursos','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'cache actual -> vacia' }
        apply={ ipconfig /flushdns | Out-Null }
        undo={ ipconfig /flushdns | Out-Null }
        undoCmd='ipconfig /flushdns'
    }
    $A += @{
        id='clean.wu-cache'
        titulo='Limpiar cache de Windows Update'
        titulo_en='Clean Windows Update cache'
        descripcion='Detiene wuauserv/bits, borra SoftwareDistribution\Download y reinicia. Libre 1-5 GB tipico.'
        descripcion_en='Stops wuauserv/bits, clears SoftwareDistribution\Download, restarts. Typically 1-5 GB free.'
        categoria='cleanup'; riesgo='bajo'; reversible=$false; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('limpieza','bajos-recursos','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ "  $(('{0:N0}' -f (STDirBytes (Get-TempFiles "$env:WINDIR\SoftwareDistribution\Download") / 1MB))) MB cache  ->  0 MB" }
        apply={
            Stop-Service wuauserv,bits -Force -ErrorAction SilentlyContinue
            Clear-STTempDir "$env:WINDIR\SoftwareDistribution\Download"
            Start-Service bits,wuauserv -ErrorAction SilentlyContinue
        }
        undo={ Write-STWarn 'limpieza: no reversible' }
        undoCmd='n/a'
    }
    $A += @{
        id='clean.wer'
        titulo='Limpiar informes de errores (WER)'
        titulo_en='Clean error reports (WER)'
        descripcion='Borra Windows Error Reporting acumulados.'
        descripcion_en='Deletes accumulated Windows Error Reporting data.'
        categoria='cleanup'; riesgo='sin'; reversible=$false; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('limpieza','bajos-recursos','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ "  $(('{0:N0}' -f (STDirBytes (Get-TempFiles "$env:ProgramData\Microsoft\Windows\WER") / 1MB))) MB informes  ->  0 MB" }
        apply={ Clear-STTempDir "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"; Clear-STTempDir "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" }
        undo={ Write-STWarn 'limpieza: no reversible' }
        undoCmd='n/a'
    }
    $A += @{
        id='clean.recyclebin'
        titulo='Vaciar papelera de reciclaje (C:)'
        titulo_en='Empty recycle bin (C: )'
        descripcion='Vaciado total. Ultimo aviso: no habra papelera.'
        descripcion_en='Full empty. Last warning: no bin after this.'
        categoria='cleanup'; riesgo='bajo'; reversible=$false; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('limpieza','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'papelera -> vacia' }
        apply={ Clear-RecycleBin -DriveLetter C -Force -ErrorAction SilentlyContinue }
        undo={ Write-STWarn 'limpieza: no reversible' }
        undoCmd='n/a'
    }
    $A += @{
        id='clean.delivery-opt'
        titulo='Vaciar cache de Optimizacion de entrega (DOSLC)'
        titulo_en='Clear Delivery Optimization cache'
        descripcion='Cache de P2P de actualizaciones/Store.'
        descripcion_en='P2P cache for updates/Store.'
        categoria='cleanup'; riesgo='sin'; reversible=$false; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('limpieza','bajos-recursos','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'cache DOSLC -> vacia' }
        apply={
            $d = "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
            if (Test-Path $d) { Clear-STTempDir $d }
        }
        undo={ Write-STWarn 'limpieza: no reversible' }
        undoCmd='n/a'
    }
    $A += @{
        id='clean.minisave'
        titulo='Vaciar cache MiniSave (capturas de pantalla de OneDrive)'
        titulo_en='Clear MiniSave cache (OneDrive screenshot cache)'
        descripcion='Borra la cache %LOCALAPPDATA%\Microsoft\MiniSave: recortes guardados automaticamente en OneDrive que casi nadie mira.'
        descripcion_en='Clears %LOCALAPPDATA%\Microsoft\MiniSave: auto-uploaded OneDrive screenshot cache nobody reviews.'
        categoria='cleanup'; riesgo='sin'; reversible=$false; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('creativo','desarrollo','limpieza','ofimatica','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $d = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Microsoft\MiniSave' } else { '' }; [bool]($d -and (Test-Path $d)) }
        preview={ "$(('{0:N0}' -f (STDirBytes (Get-TempFiles (Join-Path $env:LOCALAPPDATA 'Microsoft\MiniSave')) / 1MB))) MB en MiniSave -> 0 MB" }
        apply={ Clear-STTempDir (Join-Path $env:LOCALAPPDATA 'Microsoft\MiniSave') }
        undo={ Write-STWarn 'limpieza: no reversible' }
        undoCmd='n/a'
    }
    $A += @{
        id='clean.thumbnails'
        titulo='Limpiar cache de miniaturas (thumbnails)'
        titulo_en='Clear thumbnail cache'
        descripcion='Borra thumbcache_*.db de Explorer. Las carpetas con miles de fotos/fotos tardan: se regeneran al abrir. No borra fotos, solo cache.'
        descripcion_en='Deletes Explorer thumbcache_*.db. Folders with thousands of photos take time: thumbnails regenerate on open. Photos are NOT deleted.'
        aviso='Al abrir carpetas grandes de fotos/turismos volveras a ver las miniaturas reconstruirse. Los originales NO se tocan.'
        aviso_en='Opening big photo/car folders you will see thumbnails rebuild. Originals are NOT touched.'
        categoria='cleanup'; riesgo='bajo'; reversible=$false; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('creativo','desarrollo','limpieza','ofimatica','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'thumbcache_*.db en %LOCALAPPDATA%\Microsoft\Windows\Explorer -> borrados' }
        apply={
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer\thumbcache_*.db') -Force -ErrorAction SilentlyContinue
            Start-Process explorer -ErrorAction SilentlyContinue
        }
        undo={ Write-STWarn 'limpieza: no reversible (se regeneran al abrir)' }
        undoCmd='n/a'
    }
    return $A
}
