# SparkTune gpu.ps1 — categoria D: graficos/gaming.

function Get-GpuCatalogActions {
    $A = @()

    $A += @{
        id='gpu.hags'
        titulo='Hardware-accelerated GPU scheduling (HAGS)'
        titulo_en='Hardware-accelerated GPU scheduling (HAGS)'
        descripcion='El GPU gestiona su propia cola. Gana en GPUs modernas (Nvidia 20-series+/AMD 5000+); puede ir peor en GPUs viejas.'
        descripcion_en='GPU manages its own queue. Wins on modern GPUs (Nvidia 20+/AMD 5000+); can regress on old ones.'
        categoria='gpu'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$true; needsRP=$false
        perfiles=@('gaming','portatil-rendimiento','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) ($hw.HasNvidia -or $hw.HasAmd) -and $hw.Build -ge 19041 }
        preview={
            $cur = Get-STRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 1
            $t = if ($cur -eq 2) { 'ON' } else { 'OFF' }
            "$t  ->  ON"
        }
        apply={
            $base='HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
            $cur = Get-STRegValue $base 'HwSchMode' 1
            Set-STRegValue $base '__ST_prev_HwSchMode' ([int]$cur)
            Set-STRegValue $base 'HwSchMode' 2
        }
        undo={
            $base='HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
            $prev = Get-STRegValue $base '__ST_prev_HwSchMode' 1
            if ([int]$prev -eq 1) { Remove-ItemProperty $base 'HwSchMode' -ErrorAction SilentlyContinue }
            else { Set-STRegValue $base 'HwSchMode' ([int]$prev) }
            Remove-ItemProperty $base '__ST_prev_HwSchMode' -ErrorAction SilentlyContinue
        }
        undoCmd='borra HwSchMode'
    }
    $A += @{
        id='gamemode'
        titulo='Activar Game Mode (Modo de juego)'
        titulo_en='Enable Game Mode'
        descripcion='Prioriza CPU/GPU al juego en primer plano. En Win10/11 suele ayudar.'
        descripcion_en='Prioritizes CPU/GPU to foreground game. Usually helps on Win10/11.'
        categoria='gpu'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('gaming','portatil-rendimiento','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'GameDVR AllowGameMonitoring por defecto -> 1' }
        apply={
            Set-STRegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
            Set-STRegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
        }
        undo={
            Remove-ItemProperty 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' -ErrorAction SilentlyContinue
        }
        undoCmd='borra claves GameBar'
    }
    $A += @{
        id='gamebar.dvr'
        titulo='Desactivar Game DVR / captura de fondo (GameDVR)'
        titulo_en='Disable Game DVR / background capture'
        descripcion='Evita que el backend de captura consuma GPU/CPU en juegos. Game Bar seguira disponible manualmente.'
        descripcion_en='Stops capture backend eating GPU/CPU in games. Game Bar stays available manually.'
        categoria='gpu'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('gaming','portatil-rendimiento','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'AppCaptureEnabled=1 (por defecto) -> 0' }
        apply={
            $g='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
            if (-not (Test-Path $g)) { New-Item -Path $g -Force | Out-Null }
            Set-ItemProperty -Path $g -Name AppCaptureEnabled -Value 0 -Type DWord
            Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name GameDVR_Enabled -Value 0 -Type DWord
        }
        undo={
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' -ErrorAction SilentlyContinue
        }
        undoCmd='borra AppCaptureEnabled/GameDVR_Enabled'
    }
    $A += @{
        id='gpu.driver-advice'
        titulo='Checklist de drivers GPU (informativo)'
        titulo_en='GPU driver checklist (info only)'
        descripcion='Muestra ajustes de driver recomendados segun tu GPU. NO toca el driver.'
        descripcion_en='Shows recommended driver settings for your GPU. Does NOT touch the driver.'
        categoria='gpu'; riesgo='sin'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('gaming','portatil-rendimiento','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) ($hw.HasNvidia -or $hw.HasAmd) }
        preview={
            $hw2 = Get-STHardware
            $g = ($hw2.Gpu | ForEach-Object { "$($_.Name) [$($_.Driver)]" }) -join ' + '
            "GPU: $g"
        }
        apply={
            $hw2 = Get-STHardware
            Write-STLine ''
            if ($hw2.HasNvidia) {
                Write-STInfo 'NVIDIA: panel de control -> Manage 3D settings:'
                Write-Host '    - Power management mode: Prefer maximum performance'
                Write-Host '    - Low Latency Mode: On/Ultra (competitive) o Off (calidad)'
                Write-Host '    - Texture filtering Quality: High Performance'
                Write-Host '    - Threaded optimization: On'
                Write-Host '    - G-SYNC: On + Enable for windowed mode (si monitor G-Sync)'
            }
            if ($hw2.HasAmd) {
                Write-STInfo 'AMD Adrenalin:'
                Write-Host '    - Radeon Anti-Lag: On | Radeon Boost: segun juego'
                Write-Host '    - Texture Filtering Quality: Performance'
                Write-Host '    - Wait for Vertical Refresh: Off, unless application specifies'
            }
            if ($hw2.HasIntelGpu -and $hw2.IsLaptop -and -not ($hw2.HasNvidia -or $hw2.HasAmd)) {
                Write-STInfo 'Intel: usa plan SparkTune Equilibrado/Rendimiento; evita Turbo GPU (no hay dGPU).'
            }
            Write-STInfo 'VSync: OFF para competivo, ON/adaptive para evitar tearing en AAA.'
            Write-STLine ''
        }
        undo={ Write-STInfo 'nada que deshacer (informativo).' }
        undoCmd='n/a'
    }
    $A += @{
        id='gpu.resbar'
        titulo='Resizable BAR activo (si la GPU/CPU lo soportan)'
        titulo_en='Resizable BAR enabled (if GPU/CPU support it)'
        descripcion='Permite que la CPU acceda a toda la VRAM de golpe: +5-10% en juegos modernos. Depende de BIOS (Re-Size BAR Enable) y driver actualizado.'
        descripcion_en='Lets the CPU access all VRAM at once: +5-10% in modern games. Needs BIOS "Re-Size BAR Enable" and up-to-date driver.'
        aviso='Si tu placa no lo soporta, la accion informa y no toca nada. No hay registro que revertir: se configura en BIOS.'
        aviso_en='If the board lacks support, the action reports and changes nothing. Nothing to revert: it is configured in BIOS.'
        categoria='gpu'; riesgo='sin'; reversible=$true; admin=$true; reinicio=$true; needsRP=$false
        perfiles=@('creativo','gaming','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.HasNvidia -or $hw.HasAmd }
        preview={
            $r = 'soporte: desconocido (comprueba en MSI Afterburner/HWiNFO: Resizable BAR)'
            try {
                $gpu = (Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Where-Object { "$($_.Name)" -match 'NVIDIA|GeForce|Radeon' } | Select-Object -First 1)
                if ($gpu) { $r = "GPU: $($gpu.Name) - el estado real de BAR se lee en HWiNFO; esta accion solo da el aviso y enlace" }
            } catch { }
            $r
        }
        apply={ Write-STInfo 'Resizable BAR se activa en la BIOS (Re-Size BAR / SMART Access). Driver >= 496 (NVIDIA) o Adrenalin 22.x (AMD).' }
        undo={ Write-STInfo 'nada que deshacer en Windows' }
        undoCmd='n/a (BIOS)'
    }
    $A += @{
        id='gpu.power-mode'
        titulo='Maximo rendimiento de GPU en plan de energia (AC)'
        titulo_en='Maximum GPU performance in power plan (AC)'
        descripcion='Quita el ahorro de energia PCI Express (Link State Power Management = Off) en el plan activo cuando estas con corriente: la GPU/disco NVMe responden sin latencia de reactivacion. En bateria no cambia nada.'
        descripcion_en='Turns off PCI Express Link State Power Management in the active plan when plugged in: GPU/NVMe respond without wake-up latency. On battery, untouched.'
        categoria='gpu'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('creativo','gaming','portatil-rendimiento','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) ($hw.HasNvidia -or $hw.HasAmd) }
        preview={ 'PCI-E Link State Power Management (AC) -> Off (maxima potencia)' }
        apply={
            # PCI Express Link State Power Management: subgrupo {4d36e967-...}, setting {eeabc0fe-...} = 0 (Off)
            # (los GUIDs anteriores estaban mal: 4d36e968 es Video Priority, no PCI-E)
            powercfg.exe -setacvalueindex SCHEME_CURRENT 4d36e967-e325-11ce-bfc1-08002be10318 eeabc0fe-811e-11d5-b4d9-00a0242541e9 0 | Out-Null
            powercfg.exe -setactive SCHEME_CURRENT | Out-Null
        }
        undo={
            powercfg.exe -setacvalueindex SCHEME_CURRENT 4d36e967-e325-11ce-bfc1-08002be10318 eeabc0fe-811e-11d5-b4d9-00a0242541e9 2 | Out-Null
            powercfg.exe -setactive SCHEME_CURRENT | Out-Null
        }
        undoCmd='powercfg -setacvalueindex SCHEME_CURRENT 4d36e967-e325-11ce-bfc1-08002be10318 eeabc0fe-811e-11d5-b4d9-00a0242541e9 2'
    }
    return $A
}
