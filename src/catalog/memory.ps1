# SparkTune memory.ps1 — categoria B: memoria y procesos.

function Get-MemoryCatalogActions {
    $A = @()

    $A += @{
        id='svc.sysmain'
        titulo='Desactivar SysMain (Superfetch)'
        titulo_en='Disable SysMain (Superfetch)'
        descripcion='Libera ~200MB de RAM y trabajo de disco. Recomendado en SSD; en HDD puede empeorar la apertura de apps.'
        descripcion_en='Frees ~200MB RAM and disk work. Recommended on SSD; on HDD may slow app launch.'
        categoria='memory'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','ofimatica','bajos-recursos','portatil-ahorro','limpieza','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.HasSSD -and -not $hw.HasHDD }
        preview={ "$(Get-STServiceStart 'SysMain') / $(Get-STServiceState 'SysMain')  ->  Disabled" }
        apply={ Set-STServiceStart 'SysMain' 'Disabled'; Stop-Service SysMain -Force -ErrorAction SilentlyContinue }
        undo={ Set-STServiceStart 'SysMain' 'Auto'; Start-Service SysMain -ErrorAction SilentlyContinue }
        undoCmd='sc.exe config SysMain start=auto'
    }
    $A += @{
        id='svc.sysmain-hdd-off'
        titulo='SysMain en HDD: reducir a manual'
        titulo_en='SysMain on HDD: reduce to manual'
        descripcion='En HDD, Superfetch puede causar picos de disco. Modo manual como compromiso.'
        descripcion_en='On HDD Superfetch can cause disk spikes. Manual as compromise.'
        categoria='memory'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('bajos-recursos','limpieza','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $hw.HasHDD }
        preview={ "$(Get-STServiceStart 'SysMain')  ->  Manual" }
        apply={ Set-STServiceStart 'SysMain' 'Manual'; Stop-Service SysMain -Force -ErrorAction SilentlyContinue }
        undo={ Set-STServiceStart 'SysMain' 'Auto'; Start-Service SysMain -ErrorAction SilentlyContinue }
        undoCmd='sc.exe config SysMain start=auto'
    }
    $A += @{
        id='svc.wsearch'
        titulo='Desactivar Windows Search (indexado)'
        titulo_en='Disable Windows Search indexing'
        descripcion='Ahorra disco/RAM. En HDD se nota mucho. Busqueda de archivos quedara lenta (Start Menu seguira funcionando).'
        descripcion_en='Saves disk/RAM. Big win on HDD. File search gets slow (Start Menu keeps working).'
        categoria='memory'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('bajos-recursos','portatil-ahorro','limpieza','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $hw.HasHDD -or ($hw.RamGB -lt 8) }
        preview={ "$(Get-STServiceStart 'WSearch') / $(Get-STServiceState 'WSearch')  ->  Disabled" }
        apply={ Set-STServiceStart 'WSearch' 'Disabled'; Stop-Service WSearch -Force -ErrorAction SilentlyContinue }
        undo={ Set-STServiceStart 'WSearch' 'Auto'; Start-Service WSearch -ErrorAction SilentlyContinue }
        undoCmd='sc.exe config WSearch start=auto'
    }
    $A += @{
        id='mem.compact'
        titulo='Compresion de memoria (LaunchMemoryCompression)'
        titulo_en='Memory compression'
        descripcion='Comprime paginas de apps en segundo plano. Gana RAM real en 8GB+.'
        descripcion_en='Compresses background app pages. Real RAM win on 8GB+.'
        categoria='memory'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$true; needsRP=$false
        perfiles=@('bajos-recursos','ofimatica','portatil-ahorro','gaming','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.RamGB -ge 8 }
        preview={
            $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
            $cur = Get-STRegValue $base 'DisableMemoryCompression' 0
            $curTxt = if ($cur -eq 1) { 'compresion OFF' } else { 'compresion ON' }
            "$curTxt  ->  compresion ON"
        }
        apply={ Set-STRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisableMemoryCompression' 0 }
        undo={
            $prev = Get-STRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisableMemoryCompression' $null
            if ($null -eq $prev) { Remove-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisableMemoryCompression' -ErrorAction SilentlyContinue }
            else { Set-STRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisableMemoryCompression' $prev }
        }
        undoCmd='borra DisableMemoryCompression'
    }
    $A += @{
        id='svc.diagsvc'
        titulo='Reducir Diagnostic Policy Service a manual'
        titulo_en='Reduce Diagnostic Policy Service to manual'
        descripcion='Servicio de diagnostico/diagnostica de red. Manual = se activa bajo demanda.'
        descripcion_en='Diagnostics service. Manual = starts on demand.'
        categoria='memory'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('bajos-recursos','limpieza','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ "$(Get-STServiceStart 'DiagSVC')  ->  Manual" }
        apply={ Set-STServiceStart 'DiagSVC' 'Manual'; Stop-Service DiagSVC -Force -ErrorAction SilentlyContinue }
        undo={ Set-STServiceStart 'DiagSVC' 'Auto'; Start-Service DiagSVC -ErrorAction SilentlyContinue }
        undoCmd='sc.exe config DiagSVC start=auto'
    }
    $A += @{
        id='svc.xbox'
        titulo='Desactivar servicios Xbox/GameBar si no juegas'
        titulo_en='Disable Xbox/GameBar services if not gaming'
        descripcion='XblAuthManager, XblGameSave, XboxGipSvc, XboxNetApiSvc en manual.'
        descripcion_en='XblAuthManager, XblGameSave, XboxGipSvc, XboxNetApiSvc to manual.'
        categoria='memory'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('ofimatica','bajos-recursos','portatil-ahorro','limpieza','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'Xbox* auto/demand -> Manual' }
        apply={
            foreach ($s in @('XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc')) {
                Set-STServiceStart $s 'Manual'; Stop-Service $s -Force -ErrorAction SilentlyContinue
            }
        }
        undo={
            foreach ($s in @('XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc')) { Set-STServiceStart $s 'Auto' }
        }
        undoCmd='sc.exe config <Xbox*> start=auto'
    }
    return $A
}
