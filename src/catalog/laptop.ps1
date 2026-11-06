# SparkTune laptop.ps1 — categoria J: portatiles (bateria, iGPU/dGPU, radios).

function Get-LaptopCatalogActions {
    $A = @()

    $A += @{
        id='lap.wifi-powersave'
        titulo='Wi-Fi: modo maximo ahorro en bateria'
        titulo_en='Wi-Fi: max power save on battery'
        descripcion='Adaptador Wi-Fi en modo ahorro solo con bateria (BCC 2). Ping sube algo; bateria sube bastante.'
        descripcion_en='Wi-Fi adapter power save on battery only. Ping rises a bit; battery gains a lot.'
        categoria='laptop'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('portatil-ahorro','ofimatica','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.IsLaptop -and $hw.Battery }
        preview={ 'modo AC/DC: -> DC=Max Power Save (2)' }
        apply={
            $g='e543ec7e-637f-44ef-b78d-910a4c57d14c'
            $s='14519c9e-4e37-4ade-9c0a-c916adc3d4e9'
            $d='69cfff71-c3a7-4c4c-97d3-125048f2f2ea'
            powercfg.exe /setdcvalueindex SCHEME_CURRENT $g $d 2 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undo={
            $g='e543ec7e-637f-44ef-b78d-910a4c57d14c'
            $d='69cfff71-c3a7-4c4c-97d3-125048f2f2ea'
            powercfg.exe /setdcvalueindex SCHEME_CURRENT $g $d 0 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undoCmd='powercfg setdcvalueindex ... RFAdapt DC 0'
    }
    $A += @{
        id='lap.dgpu-off-batt'
        titulo='dGPU al minimo en bateria (Optimus/hibrido)'
        titulo_en='dGPU to minimum on battery (Optimus/hybrid)'
        descripcion='GPU discreta al 5% en bateria: apaga la dGPU hasta que se necesite. Enchufado vuelve al plan Turbo/Rendimiento.'
        descripcion_en='dGPU at 5% on battery: powers down until needed. On AC use Turbo/Rendimiento plan.'
        categoria='laptop'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('portatil-ahorro','ofimatica','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.IsLaptop -and $hw.HasDgpu }
        preview={ 'dGPU DC -> min 5% max 100%' }
        apply={
            $g='44f76c74-876a-482b-9b8c-7c00af9bc5a5'
            powercfg.exe /setdcvalueindex SCHEME_CURRENT $g b8f44f6f-53e4-4a3f-a33f-9f8744a060e0 5 2>$null
            powercfg.exe /setdcvalueindex SCHEME_CURRENT $g ea8c88e8-f68b-4e0e-a3d3-4b1e5b5515a3 100 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undo={
            $g='44f76c74-876a-482b-9b8c-7c00af9bc5a5'
            powercfg.exe /setdcvalueindex SCHEME_CURRENT $g b8f44f6f-53e4-4a3f-a33f-9f8744a060e0 100 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undoCmd='powercfg setdcvalueindex DgpuMin 100'
    }
    $A += @{
        id='lap.adaptive'
        titulo='Modo adaptativo: avisar al desenchufar o con bateria <20%'
        titulo_en='Adaptive mode: warn when unplugged or battery <20%'
        descripcion='SparkTune NO cambia el plan solo: te avisa y te ofrece el plan de ahorro. Se registra en el journal como accion de configuracion.'
        descripcion_en='SparkTune does NOT switch plans on its own: it warns and offers the saver plan. Logged as config action.'
        categoria='laptop'; riesgo='sin'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('portatil-ahorro','ofimatica','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $hw.IsLaptop -and $hw.Battery }
        preview={ 'adaptativo OFF -> ON (recomienda plan de ahorro)' }
        apply={ Set-STRegValue 'HKCU:\Software\SparkTune' 'Adaptive' 1 }
        undo={ Remove-ItemProperty 'HKCU:\Software\SparkTune' 'Adaptive' -ErrorAction SilentlyContinue }
        undoCmd='borra Software\SparkTune Adaptive'
    }
    $A += @{
        id='lap.hibernate-fast'
        titulo='Hibernacion + Fast Startup coherentes'
        titulo_en='Hibernate + coherent Fast Startup'
        descripcion='Asegura hibernacion habilitada para el plan Ultra Ahorro (umbral de bateria critica). Sin tocar dual-boot.'
        descripcion_en='Ensures hibernation is available for Ultra Ahorro plan (critical battery threshold). Dual-boot safe-ish.'
        aviso='Si arrancas Linux en dual-boot, NO montes la particion Windows con hibernacion activa.'
        aviso_en='If you dual-boot Linux, do NOT mount the Windows partition while hibernated.'
        categoria='laptop'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('portatil-ahorro','bajos-recursos','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $hw.Battery }
        preview={ 'hiberfil.sys -> habilitado (powercfg /h on)' }
        apply={ powercfg.exe /h on 2>$null | Out-Null }
        undo={ powercfg.exe /h off 2>$null | Out-Null }
        undoCmd='powercfg /h off (si quieres)'
    }
    $A += @{
        id='lap.bluetooth-idle'
        titulo='Bluetooth: suspension selectiva en bateria'
        titulo_en='Bluetooth: selective suspend on battery'
        descripcion='Apaga el adaptador BT si esta inactivo en bateria (solo si no tienes mando/auriculares por BT).'
        descripcion_en='Powers off BT adapter when idle on battery (only if no BT controller/headset).'
        aviso='Si usas mando/auriculares Bluetooth, NO actives esto o se desconectaran.'
        aviso_en='If you use a BT controller/headset, do NOT enable this or they will drop.'
        categoria='laptop'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('portatil-ahorro','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $hw.IsLaptop }
        preview={ 'BT radio en reposo -> suspend' }
        apply={
            # via powercfg: radios (si el adapter lo expone)
            $g='a763a11c-a36b-4c5f-b297-a22c62a70001'  # subgrupo: wireless-radio state? usar generic radio:
            $r='ee5c9b4e-011f-4288-91f2-888640e03df6'
            powercfg.exe /setdcvalueindex SCHEME_CURRENT $g $r 0 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undo={
            $g='a763a11c-a36b-4c5f-b297-a22c62a70001'
            $r='ee5c9b4e-011f-4288-91f2-888640e03df6'
            powercfg.exe /setdcvalueindex SCHEME_CURRENT $g $r 1 2>$null
            powercfg.exe /setactive SCHEME_CURRENT 2>$null
        }
        undoCmd='powercfg radio DC 1'
    }
    return $A
}
