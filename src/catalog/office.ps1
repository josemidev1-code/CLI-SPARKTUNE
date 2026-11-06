# SparkTune office.ps1 — categoria G: ofimatica/productividad.

function Get-OfficeCatalogActions {
    $A = @()

    $A += @{
        id='off.startup-bloat'
        titulo='Desactivar apps de inicio (OneDrive/Teams/Edge...) detectadas'
        titulo_en='Disable startup bloat (OneDrive/Teams/Edge...) detected'
        descripcion='Quita del arranjo automatico las apps de inicio tipicas que tengas instaladas.'
        descripcion_en='Removes typical installed startup apps from auto-start.'
        categoria='office'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('ofimatica','gaming','bajos-recursos','portatil-ahorro','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={
            $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            $found = @()
            $suspects = @('OneDrive','Teams','MicrosoftEdgeAutoLaunch','Discord','Spotify','Skype')
            try {
                $props = (Get-Item $run -ErrorAction Stop).Property
                foreach ($p in $props) { foreach ($s in $suspects) { if ($p -match $s) { $found += $p } } }
            } catch { }
            if ($found.Count) { "detectadas: $($found -join ', ') -> off" } else { 'nada tipico en Run -> sin cambios' }
        }
        apply={
            $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            $suspects = @('OneDrive','Teams','MicrosoftEdgeAutoLaunch','Discord','Spotify','Skype')
            try {
                $props = (Get-Item $run -ErrorAction Stop).Property
                foreach ($p in $props) {
                    foreach ($s in $suspects) {
                        if ($p -match $s) {
                            $val = (Get-ItemProperty $run).$p
                            Set-STRegValue 'HKCU:\Software\SparkTune\StartupBackup' "__ST_$p" ([string]$val) 'String'
                            Remove-ItemProperty $run $p -ErrorAction SilentlyContinue
                        }
                    }
                }
            } catch { }
        }
        undo={
            $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            $bk = 'HKCU:\Software\SparkTune\StartupBackup'
            try {
                $props = (Get-Item $bk -ErrorAction Stop).Property
                foreach ($p in $props) {
                    if ($p -like '__ST_*') {
                        $name = $p.Substring(5)
                        $val = (Get-ItemProperty $bk).$p
                        Set-STRegValue $run $name ([string]$val) 'String'
                        Remove-ItemProperty $bk $p -ErrorAction SilentlyContinue
                    }
                }
            } catch { }
        }
        undoCmd='restaura Run desde SparkTune\StartupBackup'
    }
    $A += @{
        id='off.classic-menu'
        titulo='Menu contextual clasico en Windows 11'
        titulo_en='Classic context menu on Windows 11'
        descripcion='Vuelve al menu completo de toda la vida (sin "Mostrar mas opciones").'
        descripcion_en='Brings back the full legacy menu (no "Show more options").'
        categoria='office'; riesgo='sin'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('ofimatica','gaming','portatil-rendimiento','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.IsWin11 }
        preview={ 'menu Win11 nuevo -> clasico' }
        apply={ Set-STRegValue 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(Default)' '' 'String' }
        undo={ Remove-Item 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue }
        undoCmd='borra clave CLSID 86ca1aa0...'
    }
    $A += @{
        id='off.spooler'
        titulo='Impresora/ Fax: desactivar si no los usas'
        titulo_en='Printer/Fax: disable if unused'
        descripcion='Solo si no tienes impresora ni usas Fax: Spooler a manual. Detecta colas de impresion.'
        descripcion_en='Only if you have no printer nor use Fax: Spooler to manual. Detects print queues.'
        categoria='office'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('bajos-recursos','gaming','limpieza','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw)
            try { $p = @(Get-Printer -ErrorAction Stop); return ($p.Count -eq 0) } catch { return $false }
        }
        preview={ "$(Get-STServiceStart 'Spooler') -> Manual (sin impresoras detectadas)" }
        apply={
            Set-STServiceStart 'Spooler' 'Manual'; Stop-Service Spooler -Force -ErrorAction SilentlyContinue
            Set-STServiceStart 'Fax' 'Disabled'; Stop-Service Fax -Force -ErrorAction SilentlyContinue
        }
        undo={ Set-STServiceStart 'Spooler' 'Auto'; Start-Service Spooler -ErrorAction SilentlyContinue; Set-STServiceStart 'Fax' 'Manual' }
        undoCmd='sc.exe config Spooler start=auto'
    }
    $A += @{
        id='off.netindex'
        titulo='Desactivar indexado de carpetas de red'
        titulo_en='Disable indexing of network folders'
        descripcion='Evita que WSearch intente indexar unidades de red (clavo el portatil). WSearch seguira para local.'
        descripcion_en='Stops WSearch indexing network drives (docking laptops). Local search keeps working.'
        categoria='office'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('ofimatica','portatil-ahorro','portatil-rendimiento','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'indexado red permitido -> denegado' }
        apply={ Set-STRegValue 'HKLM:\SOFTWARE\Microsoft\Windows Search' 'AllowNetworkLocations' 0 }
        undo={ Set-STRegValue 'HKLM:\SOFTWARE\Microsoft\Windows Search' 'AllowNetworkLocations' 1 }
        undoCmd='AllowNetworkLocations=1'
    }
    return $A
}
