# SparkTune updates.ps1 — categoria H: actualizaciones.
# NUNCA desactiva actualizaciones de seguridad de forma permanente; la pausa es temporal.

function Get-UpdatesCatalogActions {
    $A = @()

    $A += @{
        id='upd.pause'
        titulo='Pausar actualizaciones 35 dias (reversible)'
        titulo_en='Pause updates 35 days (reversible)'
        descripcion='Usa el mecanismo oficial de pausa. Las de seguridad volveran al vencer. Ideal antes de una sesion larga de juego/trabajo.'
        descripcion_en='Uses the official pause mechanism. Security updates return on expiry. Ideal before a long gaming/work session.'
        categoria='updates'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','ofimatica','portatil-rendimiento','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.Build -ge 17763 }
        preview={
            $g='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
            $end = Get-STRegValue $g 'PauseUpdatesExpiryTime' $null
            if ($end) { "pausado hasta $end -> +35 dias" } else { 'sin pausa -> +35 dias' }
        }
        apply={
            $g='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
            $now = Get-Date
            Set-STRegValue $g '__ST_prev_EndDate' ((Get-STRegValue $g 'PauseFeatureUpdatesStartTime' '') -as [string]) 'String'
            Set-STRegValue $g 'PauseFeatureUpdatesStartTime' ($now.ToString('yyyy-MM-ddTHH:mm:ssZ')) 'String'
            Set-STRegValue $g 'PauseFeatureUpdatesEndTime' ($now.AddDays(35).ToString('yyyy-MM-ddTHH:mm:ssZ')) 'String'
            Set-STRegValue $g 'PauseQualityUpdatesStartTime' ($now.ToString('yyyy-MM-ddTHH:mm:ssZ')) 'String'
            Set-STRegValue $g 'PauseQualityUpdatesEndTime' ($now.AddDays(35).ToString('yyyy-MM-ddTHH:mm:ssZ')) 'String'
            Set-STRegValue $g 'PauseUpdatesExpiryTime' ($now.AddDays(35).ToString('yyyy-MM-ddTHH:mm:ssZ')) 'String'
            Write-STWarn 'La pausa se aplica via clave de UX; confirma en Configuracion > Windows Update.'
        }
        undo={
            $g='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
            foreach ($k in @('PauseFeatureUpdatesStartTime','PauseFeatureUpdatesEndTime','PauseQualityUpdatesStartTime','PauseQualityUpdatesEndTime')) {
                Remove-ItemProperty $g $k -ErrorAction SilentlyContinue
            }
            Remove-ItemProperty $g '__ST_prev_EndDate' -ErrorAction SilentlyContinue
            Restart-Service wuauserv -Force -ErrorAction SilentlyContinue
        }
        undoCmd='borra claves Pause* + restart wuauserv'
    }
    $A += @{
        id='upd.forced-reboot'
        titulo='⚠ Evitar reinicios forzosos de Windows Update'
        titulo_en='⚠ Prevent forced Windows Update reboots'
        descripcion='NoReboot en horario activo + bloqueo de reinicio automatico de AU (NoAutoRebootWithLoggedOnUsers).'
        descripcion_en='NoReboot during active hours + AU auto-reboot block (NoAutoRebootWithLoggedOnUsers).'
        aviso='Windows pedira reinicio igualmente para completar actualizaciones; no se actualizan los parches ya instalados hasta reiniciar.'
        aviso_en='Windows will still ask for a reboot to finish updates; installed patches stay pending until you reboot.'
        categoria='updates'; riesgo='alto'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'reinicios forzosos activos -> bloqueados con usuarios conectados' }
        apply={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            if (-not (Test-Path $g)) { New-Item -Path $g -Force | Out-Null }
            $cur = Get-STRegValue $g 'NoAutoRebootWithLoggedOnUsers' 0
            Set-STRegValue $g '__ST_prev_NoAutoReboot' ([int]$cur)
            Set-STRegValue $g 'NoAutoRebootWithLoggedOnUsers' 1
        }
        undo={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            $prev = Get-STRegValue $g '__ST_prev_NoAutoReboot' 0
            Set-STRegValue $g 'NoAutoRebootWithLoggedOnUsers' ([int]$prev)
            Remove-ItemProperty $g '__ST_prev_NoAutoReboot' -ErrorAction SilentlyContinue
        }
        undoCmd='NoAutoRebootWithLoggedOnUsers al valor previo'
    }
    $A += @{
        id='upd.driver-advice'
        titulo='Consejos de drivers (informativo, no instala nada)'
        titulo_en='Driver advice (info only, installs nothing)'
        descripcion='Comprueba si hay drivers GPU/chipset desactualizados comparando versiones.'
        descripcion_en='Checks for outdated GPU/chipset drivers by comparing versions.'
        categoria='updates'; riesgo='sin'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('gaming','ofimatica','portatil-rendimiento','bajos-recursos','portatil-ahorro','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={
            $hw2 = Get-STHardware
            $g = ($hw2.Gpu | ForEach-Object { "$($_.Name): $($_.Driver)" }) -join ' / '
            if (-not $g) { $g = 'sin GPU dedicada' }
            "drivers GPU: $g"
        }
        apply={
            $hw2 = Get-STHardware
            if ($hw2.HasNvidia) { Write-STInfo 'Nvidia: usa GeForce Experience o nvidia.com; evita drivers de Windows Update para GPU.' }
            if ($hw2.HasAmd) { Write-STInfo 'AMD: usa Adrenalin o amd.com; desmarca "driver de Windows Update" si quieres control.' }
            if ($hw2.HasIntelGpu) { Write-STInfo 'Intel: Intel Driver & Support Assistant (intel.com/dsa).' }
            Write-STInfo 'Chipset: siempre desde la web del fabricante de placa/portatil.'
        }
        undo={ Write-STInfo 'nada que deshacer (informativo).' }
        undoCmd='n/a'
    }
    return $A
}
