# SparkTune cpu.ps1 — categoria C: CPU y rendimiento.

function Get-CpuCatalogActions {
    $A = @()

    $A += @{
        id='cpu.fgboost'
        titulo='Foreground boost activo (Win32PrioritySeparation)'
        titulo_en='Enable foreground boost (Win32PrioritySeparation)'
        descripcion='Da mas quantum a la ventana activa: 0x26 = boost corto y variable (clasico gaming).'
        descripcion_en='More quantum to the active window: 0x26 = short variable boost (gaming classic).'
        categoria='cpu'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$true; needsRP=$false
        perfiles=@('gaming','ofimatica','portatil-rendimiento','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={
            $cur = Get-STRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 2
            "$cur (0x{0:x})  ->  38 (0x26)"
        }
        apply={ Set-STRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38 }
        undo={
            $base='HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
            $prev = Get-STRegValue $base '__ST_prev_Win32PrioritySeparation' $null
            if ($null -eq $prev) { $prev = 2 }
            Set-STRegValue $base 'Win32PrioritySeparation' ([int]$prev)
            Remove-ItemProperty $base '__ST_prev_Win32PrioritySeparation' -ErrorAction SilentlyContinue
        }
        undoCmd='Win32PrioritySeparation=2 por defecto'
        applyPre={
            $base='HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
            $cur = Get-STRegValue $base 'Win32PrioritySeparation' 2
            Set-STRegValue $base '__ST_prev_Win32PrioritySeparation' ([int]$cur)
        }
    }
    $A += @{
        id='cpu.visualeffects'
        titulo='Reducir efectos visuales/animaciones'
        titulo_en='Reduce visual effects/animations'
        descripcion='Animaciones de ventanas, transparencias y efectos: menos GPU/RAM en equipos modestos.'
        descripcion_en='Window animations and transparency: less GPU/RAM on modest hardware.'
        categoria='cpu'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('bajos-recursos','ofimatica','portatil-ahorro','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) ($hw.RamGB -lt 16) -or $hw.IsLaptop }
        preview={ 'animaciones ON  ->  OFF' }
        apply={
            $paths = @(
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects',
                'HKCU:\Software\Microsoft\Windows\DWM'
            )
            if (-not (Test-Path $paths[0])) { New-Item -Path $paths[0] -Force | Out-Null }
            Set-ItemProperty -Path $paths[0] -Name VisualFXSetting -Value 2 -Type DWord
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name UserPreferencesMask -Value ([byte[]](0x90,0x12,0x07,0x80,0x10,0x00,0x00,0x00)) -Type Binary
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name MinAnimate -Value '0' -Type String
            Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name TaskbarAnimations -Value 0 -Type DWord
        }
        undo={
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' -ErrorAction SilentlyContinue
        }
        undoCmd='borra claves VisualFX/UserPreferencesMask/MinAnimate'
    }
    $A += @{
        id='cpu.spectre'
        titulo='⚠ Desactivar mitigaciones Spectre/Meltdown'
        titulo_en='⚠ Disable Spectre/Meltdown mitigations'
        descripcion='Hasta 5-10% mas CPU en equipos antiguos. DESACTIVA proteccion contra exploits de CPU.'
        descripcion_en='Up to 5-10% more CPU on old hardware. DISABLES CPU exploit mitigations.'
        aviso='Riesgo de seguridad real: no lo hagas en maquinas con navegador/correo/productividad. Pensado para PC de juego offline.'
        aviso_en='Real security risk: do not use on machines that browse the web or check email. Offline gaming rigs only.'
        categoria='cpu'; riesgo='alto'; reversible=$true; admin=$true; reinicio=$true; needsRP=$true
        perfiles=@('gaming','bajos-recursos','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $hw.Cpu -match 'Intel|AMD' }
        preview={
            $cur = Get-STRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'FeatureSettingsOverride' 0
            "$cur (mitigaciones activas)  ->  33 (override minimo)"
        }
        apply={
            $base='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
            $cur = Get-STRegValue $base 'FeatureSettingsOverride' 0
            Set-STRegValue $base '__ST_prev_FeatureSettingsOverride' ([int]$cur)
            Set-STRegValue $base 'FeatureSettingsOverride' 33
            Set-STRegValue $base 'FeatureSettingsOverrideMask' 3
        }
        undo={
            $base='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
            $prev = Get-STRegValue $base '__ST_prev_FeatureSettingsOverride' $null
            if ($null -eq $prev) { $prev = 0 }
            Set-STRegValue $base 'FeatureSettingsOverride' ([int]$prev)
            Remove-ItemProperty $base 'FeatureSettingsOverrideMask' -ErrorAction SilentlyContinue
            Remove-ItemProperty $base '__ST_prev_FeatureSettingsOverride' -ErrorAction SilentlyContinue
        }
        undoCmd='FeatureSettingsOverride al valor previo'
    }
    $A += @{
        id='cpu.hpet'
        titulo='⚠ Use Platform Clock (desactivar HPET)'
        titulo_en='⚠ Use Platform Clock (disable HPET)'
        descripcion='Menor latencia de timer (mitos y reales: small win). Puede causar inestabilidad en chips antiguos.'
        descripcion_en='Lower timer latency (small win). Can destabilize old chipsets.'
        aviso='Si notas micro-stutters, congelaciones o problemas de audio tras aplicar: undo inmediato + reinicio.'
        aviso_en='If you notice micro-stutters, freezes or audio issues after applying: immediate undo + reboot.'
        categoria='cpu'; riesgo='alto'; reversible=$true; admin=$true; reinicio=$true; needsRP=$true
        perfiles=@('gaming','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={
            $useHpet = (bcdedit.exe /enum '{globalsettings}' 2>&1) -join ' '
            $state = 'por defecto'
            if ("$useHpet" -match 'useplatformclock\s+Yes') { $state = 'HPET forzado' }
            "$state  ->  useplatformclock=No"
        }
        apply={ bcdedit.exe /set useplatformclock No | Out-Null }
        undo={ bcdedit.exe /deletevalue useplatformclock 2>$null | Out-Null; bcdedit.exe /set useplatformclock Yes 2>$null | Out-Null; bcdedit.exe /deletevalue useplatformclock 2>$null | Out-Null }
        undoCmd='bcdedit /deletevalue useplatformclock'
    }
    $A += @{
        id='cpu.idlestates'
        titulo='⚠ Desactivar CPU idle states en plan de alto rendimiento'
        titulo_en='⚠ Disable CPU idle states in high perf plan'
        descripcion='Sin C-states: menos latencia, mucho mas calor/consumo. Solo sobremesa bien refrigerada y plans Rendimiento/Maximo.'
        descripcion_en='No C-states: lower latency, way more heat/power. Desktop with good cooling + Rendimiento/Maximo plans only.'
        aviso='Sube temperatura y consumo 20-40W. En portatil: JAMAS.'
        aviso_en='Adds 20-40W heat/power. On laptops: NEVER.'
        categoria='cpu'; riesgo='alto'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('gaming','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) (-not $hw.IsLaptop) }
        preview={ 'C-States AC: on  ->  off (en plan SparkTune Rendimiento/Maximo)' }
        apply={
            # 0=disabled en el plan ACTIVE actual (asumimos plan SparkTune Rendimiento/Maximo/Turbo)
            powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 1 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undo={
            powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 0 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undoCmd='powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 0'
    }
    return $A
}
