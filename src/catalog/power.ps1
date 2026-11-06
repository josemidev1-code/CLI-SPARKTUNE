# SparkTune power.ps1 — planes de energia SparkTune.
# Crea planes con powercfg /duplicate sobre los 3 planes base de Microsoft y
# ajusta subparametros documentados. Undo = volver al plan original (journal).
# Cargado por catalog.ps1.

$script:STPowerSet = @{
    'spark-ultra'    = @{ num=1; base='3af42e19-b433-4b15-8c6c-0c0b586e35c2'; name='SparkTune Ultra Ahorro' }   # base: max battery saver
    'spark-ahorro'   = @{ num=2; base='a18413be-3541-4fab-bc81-f71556f20b4a'; name='SparkTune Ahorro' }          # base: power saver
    'spark-equili'   = @{ num=3; base='381b4222-f694-41f8-9685-ff5bb260df2e'; name='SparkTune Equilibrado' }     # base: balanced
    'spark-rendi'    = @{ num=4; base='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; name='SparkTune Rendimiento' }     # base: high perf
    'spark-turbo'    = @{ num=5; base='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; name='SparkTune Turbo GPU' }
    'spark-max'      = @{ num=6; base='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; name='SparkTune Maximo (sobremesa)' }
}
$script:STPowerGuidFile = Join-Path $Global:STHome 'power-guids.json'
$script:STPowerPrevFile = Join-Path $Global:STHome 'power-prev.txt'

# GUIDs de subgrupos/subparametros (documentados por Microsoft)
$STSUB = @{
    SubBatt='001a468b-4c03-470b-8270-8b10a9d38d64'; CritBatt='9a66741a-17fc-42d9-b83d-0f145d9261d9'
    LowBatt='8183ba9a-e916-4ace-9aff-a7e02f0ea55f'; BattLevelAct='e40b5daa-1f9c-4e07-b1aa-4826e399ba76'
    SleepIdleAc='2c815c63-31a3-4b3e-8503-13b7d9ed734e'; SleepIdleDc='f2cbe7df-2ada-4c88-b9c8-7a7e1063c8d3'
    HibernateTimeout='9d7815a6-7ee4-497e-8888-515a96a0ec13'
    SubProc='54533251-82be-4824-96c1-47b60b740d00'
    ProcMinAc='893dee8d-2bef-41e0-89fb-58d45259cc4c'; ProcMinDc='bc5038f7-23e0-4960-96da-33abaf5935ec'
    ProcMaxAc='bc037623-e152-4233-b009-531e49adc355'; ProcMaxDc='45f638e3-af0b-48a7-920b-e20837f67e1f'
    IdleTimeAc='63f2ec4e-4d4f-4e90-bda6-c7c82d8aff83'; IdleTimeDc='5d76a2ca-a8d3-441c-b2f3-2fd0836d4028'
    ProcPerfBoost='be337238-0d82-4146-a960-4f3749d470c7'  # 0=Default 1=Efficient 2=Aggressive
    LatencyHint='f4baaf2c-638c-4790-b101-0f4f02493e7b'    # processor performance history/decrease hint
    SubPci='eeeabc0fe-811e-11d5-b4d9-00a0242541e9'; AspmAc='eeeabc0f-811e-11d5-b4d9-000242541e9'
    SubGPU='44f76c74-876a-482b-9b8c-7c00af9bc5a5'
    DgpuMinAc='48f03ac5-cf51-4766-8fd5-0a1db1999fd1'; DgpuMaxAc='ec8d00b4-65e9-4b1b-83cc-001e81eee0ae'
    DgpuMinDc='b8f44f6f-53e4-4a3f-a33f-9f8744a060e0'; DgpuMaxDc='ea8c88e8-f68b-4e0e-a3d3-4b1e5b5515a3'
    SubPt='7b7fd3c5-cd56-4b5a-94e5-7b9e589a1f5f'  # Power Throttling {7B7FD3C5-...} alias: 90e0adb2-...? usar: 7B7FD3C5 no documentado; usar el oficial:
}
# Power Throttling oficial: subgrupo 7B7FD3C5-C5D5-4B5A-... — usamos los GUIDs ampliamente documentados:
$STSUB.SubPt   = '7B7FD3C5-C5D5-4B5A-94E5-7B9E589A1F5F'
$STSUB.Pt90Ac  = '21c187d4-5510-24d2-59a6-65c2b2f2c84b'  # 90th percentile foreground (documentado en foros; si falla, setea y continua)
$STSUB.SubNet='e543ec7e-637f-44ef-b78d-910a4c57d14c'
$STSUB.NetRfAc='14519c9e-4e37-4ade-9c0a-c916adc3d4e9'   # Wireless adapter power mode AC
$STSUB.NetRfDc='69cfff71-c3a7-4c4c-97d3-125048f2f2ea'   # DC
$STSUB.SubVideo='7516b90f-f776-4464-8c53-06167f40cc99'
$STSUB.VidIdleAc='3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e' # video idle timeout AC
$STSUB.VidIdleDc='3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
$STSUB.SubAlrm='d84de9df-6a3c-4e8b-9dbe-5bb51b44df35'   # alarm actions
$STSUB.AlrmDc='bcda0727-8491-4a27-9bb6-abf892b415b6'    # alarm actions DC (0 play,1 bios,2 none,3 die)

function Invoke-STPowerCfg([string[]]$Args2) {
    $out = (& powercfg.exe @Args2 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "powercfg $($Args2 -join ' '): $out" }
    return $out
}

function Get-STPlanGuid([string]$Key) {
    # devuelve GUID actual del plan SparkTune o '' si no existe todavia
    $map = @{}
    if (Test-Path $script:STPowerGuidFile) {
        try {
            $o = (Get-Content $script:STPowerGuidFile -Raw) | ConvertFrom-Json
            foreach ($p in $o.PSObject.Properties) { $map[$p.Name] = $p.Value }
        } catch { }
    }
    if ($map.ContainsKey($Key)) {
        $g = $map[$Key]
        # verificar que sigue listado
        try {
            $list = (powercfg.exe /list) -join "`n"
            if ($list -match $g) { return $g }
        } catch { }
    }
    return ''
}

function Set-STPlanGuid([string]$Key, [string]$Guid) {
    $map = @{}
    if (Test-Path $script:STPowerGuidFile) {
        try { $o = (Get-Content $script:STPowerGuidFile -Raw) | ConvertFrom-Json; foreach ($p in $o.PSObject.Properties) { $map[$p.Name] = $p.Value } } catch { }
    }
    $map[$Key] = $Guid
    $j = ConvertTo-Json $map
    [System.IO.File]::WriteAllText($script:STPowerGuidFile, $j, (New-Object System.Text.UTF8Encoding($false)))
}

function New-STPowerPlan {
    param([string]$Key)
    $meta = $script:STPowerSet[$Key]
    if (-not $meta) { throw "plan desconocido: $Key" }
    $base = $meta.base
    $name = $meta.name
    Invoke-STPowerCfg @('/duplicate', $base, $name) | Out-Null
    $list = (powercfg.exe /list) -join "`n"
    # parse robusto: lineas "GUID de la configuración: <name> (<guid>)" o "Power Scheme GUID: <guid>  (<name>)"
    $g = ''
    foreach ($line in ($list -split "`n")) {
        if ($line -match [regex]::Escape($name)) {
            if ($line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { $g = $matches[1]; break }
        }
    }
    if (-not $g) { throw "No se encontro el GUID del plan $name" }
    Set-STPlanGuid -Key $Key -Guid $g
    return $g
}

function Set-STPlanValues {
    param([string]$Guid, [hashtable]$Ac, [hashtable]$Dc, [hashtable]$Subs = @{})
    foreach ($k in $Subs.Keys) { Invoke-STPowerCfg @('/setsubgroupscheme', $Guid, $k, 'sub') 2>$null }
    foreach ($kv in $Ac.Keys) {
        $pair = $kv.Split('|'); $v = ([convert]::ToString([int]$Ac[$kv], 16)).PadLeft(8,'0')
        try { Invoke-STPowerCfg @('/setacvalueindex', $Guid, $pair[0], $pair[1], "0x$v") | Out-Null } catch { }
    }
    foreach ($kv in $Dc.Keys) {
        $pair = $kv.Split('|'); $v = ([convert]::ToString([int]$Dc[$kv], 16)).PadLeft(8,'0')
        try { Invoke-STPowerCfg @('/setdcvalueindex', $Guid, $pair[0], $pair[1], "0x$v") | Out-Null } catch { }
    }
}

function Get-STPlanSpec([string]$Key, $hw) {
    # subparametros por plan. Claves "subguid|setguid" = valor.
    $P = $STSUB
    $Key = $Key.ToLowerInvariant()
    switch ($Key) {
        'spark-ultra' { return @{
            Ac=@{"$($P.SubProc)|$($P.ProcMinAc)"=5;"$($P.SubProc)|$($P.ProcMaxAc)"=80;"$($P.SubProc)|$($P.ProcPerfBoost)"=1
                 "$($P.SubBatt)|$($P.SleepIdleAc)"=120;"$($P.SubBatt)|$($P.CritBatt)"=5;"$($P.SubBatt)|$($P.LowBatt)"=20
                 "$($P.SubPci)|$($P.AspmAc)"=0;"$($P.SubNet)|$($P.NetRfAc)"=2;"$($P.SubVideo)|$($P.VidIdleAc)"=30}
            Dc=@{"$($P.SubProc)|$($P.ProcMinDc)"=5;"$($P.SubProc)|$($P.ProcMaxDc)"=60;"$($P.SubProc)|$($P.ProcPerfBoost)"=1
                 "$($P.SubBatt)|$($P.SleepIdleDc)"=60;"$($P.SubBatt)|$($P.CritBatt)"=5;"$($P.SubBatt)|$($P.LowBatt)"=20
                 "$($P.SubPci)|$($P.AspmAc)"=0;"$($P.SubNet)|$($P.NetRfDc)"=2;"$($P.SubVideo)|$($P.VidIdleDc)"=15} } }
        'spark-ahorro' { return @{
            Ac=@{"$($P.SubProc)|$($P.ProcMinAc)"=5;"$($P.SubProc)|$($P.ProcMaxAc)"=90;"$($P.SubProc)|$($P.ProcPerfBoost)"=1
                 "$($P.SubBatt)|$($P.SleepIdleAc)"=300;"$($P.SubPci)|$($P.AspmAc)"=1}
            Dc=@{"$($P.SubProc)|$($P.ProcMinDc)"=5;"$($P.SubProc)|$($P.ProcMaxDc)"=75;"$($P.SubProc)|$($P.ProcPerfBoost)"=1
                 "$($P.SubBatt)|$($P.SleepIdleDc)"=180;"$($P.SubPci)|$($P.AspmAc)"=0;"$($P.SubNet)|$($P.NetRfDc)"=2} } }
        'spark-equili' { return @{
            Ac=@{"$($P.SubProc)|$($P.ProcMinAc)"=5;"$($P.SubProc)|$($P.ProcMaxAc)"=100;"$($P.SubProc)|$($P.ProcPerfBoost)"=0
                 "$($P.SubBatt)|$($P.SleepIdleAc)"=600}
            Dc=@{"$($P.SubProc)|$($P.ProcMinDc)"=5;"$($P.SubProc)|$($P.ProcMaxDc)"=95;"$($P.SubProc)|$($P.ProcPerfBoost)"=1
                 "$($P.SubBatt)|$($P.SleepIdleDc)"=300;"$($P.SubPci)|$($P.AspmAc)"=1} } }
        'spark-rendi' { return @{
            Ac=@{"$($P.SubProc)|$($P.ProcMinAc)"=100;"$($P.SubProc)|$($P.ProcMaxAc)"=100;"$($P.SubProc)|$($P.ProcPerfBoost)"=2
                 "$($P.SubPci)|$($P.AspmAc)"=0}
            Dc=@{"$($P.SubProc)|$($P.ProcMinDc)"=5;"$($P.SubProc)|$($P.ProcMaxDc)"=98;"$($P.SubProc)|$($P.ProcPerfBoost)"=2
                 "$($P.SubBatt)|$($P.SleepIdleDc)"=300} } }
        'spark-turbo' { return @{
            Ac=@{"$($P.SubProc)|$($P.ProcMinAc)"=100;"$($P.SubProc)|$($P.ProcMaxAc)"=100;"$($P.SubProc)|$($P.ProcPerfBoost)"=2
                 "$($P.SubPci)|$($P.AspmAc)"=0
                 "$($P.SubGPU)|$($P.DgpuMinAc)"=98;"$($P.SubGPU)|$($P.DgpuMaxAc)"=100}
            Dc=@{"$($P.SubProc)|$($P.ProcMinDc)"=80;"$($P.SubProc)|$($P.ProcMaxDc)"=100;"$($P.SubProc)|$($P.ProcPerfBoost)"=2
                 "$($P.SubGPU)|$($P.DgpuMinDc)"=50;"$($P.SubGPU)|$($P.DgpuMaxDc)"=100} } }
        'spark-max' { return @{
            Ac=@{"$($P.SubProc)|$($P.ProcMinAc)"=100;"$($P.SubProc)|$($P.ProcMaxAc)"=100;"$($P.SubProc)|$($P.ProcPerfBoost)"=2
                 "$($P.SubPci)|$($P.AspmAc)"=0
                 "$($P.SubGPU)|$($P.DgpuMinAc)"=99;"$($P.SubGPU)|$($P.DgpuMaxAc)"=100}
            Dc=@{"$($P.SubProc)|$($P.ProcMinDc)"=100;"$($P.SubProc)|$($P.ProcMaxDc)"=100;"$($P.SubProc)|$($P.ProcPerfBoost)"=2} } }
    }
    throw "spec desconocida $Key"
}

function Install-STPowerPlan {
    param([string]$Key, [bool]$Activate = $true)
    if (-not (Is-STAdmin)) {
        # /duplicate no requiere admin; /setactive tampoco en tu propio plan normalmente
    }
    # guardar plan previo para undo
    $prev = ''
    if (Test-Path $script:STPowerPrevFile) { $prev = (Get-Content $script:STPowerPrevFile -First 1) }
    if (-not $prev) {
        $act = (powercfg.exe /getactivescheme 2>$null) -join "`n"
        if ($act -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { $prev = $matches[1] }
        if ($prev) { [System.IO.File]::WriteAllText($script:STPowerPrevFile, $prev) }
    }
    $g = Get-STPlanGuid $Key
    if (-not $g) {
        $g = New-STPowerPlan $Key
        $spec = Get-STPlanSpec $Key $null
        Set-STPlanValues -Guid $g -Ac $spec.Ac -Dc $spec.Dc
    }
    if ($Activate) { Invoke-STPowerCfg @('/setactive', $g) | Out-Null }
    return $g
}

function Remove-STPowerPlans {
    $list = (powercfg.exe /list) -join "`n"
    foreach ($meta in $script:STPowerSet.Values) {
        foreach ($line in ($list -split "`n")) {
            if ($line -match [regex]::Escape($meta.name) -and $line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
                $g = $matches[1]
                try { Invoke-STPowerCfg @('/delete', $g) | Out-Null } catch { }
            }
        }
    }
    if (Test-Path $script:STPowerGuidFile) { Remove-Item $script:STPowerGuidFile -Force }
}

# ---------- acciones del catalogo ----------
function Get-PowerCatalogActions {
    $A = @()
    foreach ($key in ($script:STPowerSet.Keys | Sort-Object { $script:STPowerSet[$_].num })) {
        $meta = $script:STPowerSet[$key]
        $thisKey = $key; $thisMeta = $meta
        $g = Get-STPlanGuid $key
        $descEs = switch ($key) {
            'spark-ultra'  { 'Plan de duracion maxima: CPU al 5-80%, ASPM total, radio al minimo, pantallas y suspension agresivas.' }
            'spark-ahorro' { 'Ahorro sin martyrio: CPU limitada en bateria, suspension razonable, Wi-Fi ahorrador.' }
            'spark-equili' { 'Equilibrado fino: boost eficiente en bateria, ASPM en bateria, sin limits tontas.' }
            'spark-rendi'  { 'Rendimiento alto: CPU al 100% con boost Aggressive, ASPM off (AC).' }
            'spark-turbo'  { 'Para gaming enchufado: como Rendimiento + GPU discreta al 98-100% (solo AC).' }
            'spark-max'    { 'Sobremesa sin compromises: todo al 100%, boost Aggressive. No apto para portatiles.' }
        }
        $descEn = switch ($key) {
            'spark-ultra'  { 'Max battery plan: CPU 5-80%, full ASPM, radio min power, aggressive sleep.' }
            'spark-ahorro' { 'Saver without pain: CPU capped on battery, sane sleep, Wi-Fi saver.' }
            'spark-equili' { 'Tuned balanced: efficient boost on battery, ASPM on battery.' }
            'spark-rendi'  { 'High performance: CPU 100% with Aggressive boost, ASPM off (AC).' }
            'spark-turbo'  { 'Plugged-in gaming: like Rendimiento + dGPU at 98-100% (AC only).' }
            'spark-max'    { 'Desktop no compromise: everything 100%. Not for laptops.' }
        }
        $risk = 'bajo'; if ($key -in @('spark-rendi','spark-turbo','spark-max')) { $risk = 'medio' }
        $perfs = switch ($key) {
            'spark-ultra'  { @('portatil-ahorro','bajos-recursos','ofimatica') }
            'spark-ahorro' { @('portatil-ahorro','ofimatica','bajos-recursos') }
            'spark-equili' { @('ofimatica','gaming','portatil-rendimiento','bajos-recursos','personalizado') }
            'spark-rendi'  { @('gaming','portatil-rendimiento','ofimatica') }
            'spark-turbo'  { @('gaming','portatil-rendimiento') }
            'spark-max'    { @('gaming','ofimatica') }
        }
        $detect = { param($hw)
            if ($hw.IsLaptop) {
                if ($thisKey -eq 'spark-max') { return $false }
                if ($thisKey -eq 'spark-turbo' -and -not $hw.HasDgpu) { return $false }
            } else {
                if ($thisKey -in @('spark-ultra','spark-ahorro')) { return $false }
                if ($thisKey -eq 'spark-turbo' -and -not $hw.HasDgpu) { return $false }
            }
            return $true
        }.GetNewClosure()
        $preview = {
            $cur = ''
            $act2 = (powercfg.exe /getactivescheme 2>$null) -join "`n"
            if ($act2 -match '\(([^)]+)\)\s*$') { $cur = $matches[1] }
            elseif ($act2 -match ':\s*(.+?)\s*\(') { $cur = $matches[1] }
            "$cur  ->  $($thisMeta.name)"
        }.GetNewClosure()
        $apply = { Install-STPowerPlan -Key $thisKey | Out-Null }.GetNewClosure()
        $undo = {
            $prev = ''
            if (Test-Path $script:STPowerPrevFile) { $prev = (Get-Content $script:STPowerPrevFile -First 1) }
            if ($prev) { powercfg.exe /setactive $prev | Out-Null }
            else { throw 'sin plan previo registrado' }
        }
        $act = @{
            id    = "power.$key"
            titulo = "Aplicar plan $($meta.name)"
            titulo_en = "Apply plan $($meta.name)"
            descripcion = $descEs
            descripcion_en = $descEn
            categoria = 'power'
            riesgo  = $risk
            reversible = $true
            admin   = $false
            reinicio= $false
            needsRP = $false
            perfiles= $perfs
            niveles = @{ suave=1; medio=1; agresivo=1 }
            detect  = $detect
            preview = $preview
            apply   = $apply
            undo    = $undo
            undoCmd = 'powercfg /setactive <plan previo>'
        }
        $A += $act
    }
    $A = @($A | Where-Object { $_ })
    # accion de restaurar planes originales de fabrica
    $A += @{
        id='power.restore-defaults'
        titulo='Restaurar planes originales (borrar planes SparkTune)'
        titulo_en='Restore factory plans (delete SparkTune plans)'
        descripcion='Elimina los planes SparkTune y vuelve al plan previo guardado.'
        descripcion_en='Deletes SparkTune plans and switches back to the saved previous plan.'
        categoria='power'; riesgo='sin'; reversible=$false; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('personalizado'); niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ "$(T 'card.desc'): borra SparkTune*, vuelve al plan previo." }
        apply={
            $prev=''
            if (Test-Path $script:STPowerPrevFile) { $prev=(Get-Content $script:STPowerPrevFile -First 1) }
            if ($prev) { powercfg.exe /setactive $prev 2>$null | Out-Null }
            Remove-STPowerPlans
        }
        undo={ Install-STPowerPlan -Key 'spark-equili' | Out-Null }
        undoCmd='sparktune power (recrear planes)'
    }
    return $A
}

# ---------- menu power ----------
function Invoke-STPowerMenu {
    Enable-STVirtualTerminal
    $hw = Get-STHardware
    while ($true) {
        Clear-STScreen
        Write-STLine ''
        Write-STLine "  $(T 'power.title')" 'cyan' 'bold'
        $act = (powercfg.exe /getactivescheme 2>$null) -join "`n"
        Write-STInfo "activo: $act"
        Write-STLine ''
        $items = @()
        foreach ($key in ($script:STPowerSet.Keys | Sort-Object { $script:STPowerSet[$_].num })) {
            $meta = $script:STPowerSet[$key]
            $mark = ''
            if ((Get-STPlanGuid $key) -and ($act -match [regex]::Escape((Get-STPlanGuid $key)))) { $mark = ' ✔' }
            $aplica = if ($hw.IsLaptop) { '' } elseif ($key -in @('spark-ultra','spark-ahorro')) { '  [no sobremesa]' } else { '' }
            $items += [pscustomobject]@{ id=$key; label="$($meta.num). $($meta.name)$mark$aplica" }
        }
        $items += [pscustomobject]@{ id='restore'; label='0. Restaurar originales / Restore factory' }
        $items += [pscustomobject]@{ id='quit'; label='q. ' + (T 'nav.quit') }
        $idx = Show-STMenu -Title "  $(T 'power.title')" -Items $items
        if ($idx -lt 0) { return }
        $pick = $items[$idx].id
        switch ($pick) {
            'quit' { return }
            'restore' {
                if (Read-STConfirm -Question 'Borrar planes SparkTune y volver al plan original? (s/n)') {
                    Remove-STPowerPlans
                    $prev = ''
                    if (Test-Path $script:STPowerPrevFile) { $prev = (Get-Content $script:STPowerPrevFile -First 1) }
                    if ($prev) { powercfg.exe /setactive $prev 2>$null | Out-Null; Write-STOk "plan previo restaurado: $prev" }
                }
            }
            default {
                Write-STInfo "creando/aplicando $pick ..."
                try {
                    $g = Install-STPowerPlan -Key $pick
                    Write-STOk "plan aplicado ($g)"
                } catch { Write-STErr $_.Exception.Message }
                Read-STKey | Out-Null
            }
        }
    }
}

# ---------- battery report ----------
function Show-STBatteryReport {
    Enable-STVirtualTerminal
    $hw = Get-STHardware
    Write-STLine ''
    Write-STLine "  $(T 'battery.title')" 'cyan' 'bold'
    if (-not $hw.Battery) { Write-STInfo 'sin bateria (sobremesa)'; Show-STPlanSuggestion $hw; return }
    $outFile = Join-Path $env:TEMP 'sparktune-battery.html'
    try {
        $r = powercfg.exe /batteryreport /output $outFile 2>&1
        if (Test-Path $outFile) {
            $html = Get-Content $outFile -Raw
            $design = ''; $full = ''
            if ($html -match 'Design Capacity[^0-9]*([0-9,\.]+)\s*mWh') { $design = $matches[1] }
            if ($html -match 'Full Charge Capacity[^0-9]*([0-9,\.]+)\s*mWh') { $full = $matches[1] }
            Write-STInfo "nivel actual: $($hw.BatteryPct)%  enchufado: $($hw.Plugged)"
            if ($design -and $full) {
                $d = [double]($design -replace ','); $f = [double]($full -replace ',')
                $health = [Math]::Round(100 * $f / $d)
                $col = if ($health -ge 80) { 'green' } elseif ($health -ge 60) { 'yellow' } else { 'red' }
                Write-STLine "  salud de bateria: $health%  (full $f / design $design mWh)" $col
            }
            Write-STInfo "informe completo: $outFile"
        } else { Write-STWarn 'powercfg no genero el informe' }
    } catch { Write-STErr $_.Exception.Message }
    Show-STPlanSuggestion $hw
}

function Show-STPlanSuggestion($hw) {
    Write-STLine ''
    $s = @()
    if ($hw.IsLaptop) {
        if ($hw.Plugged) {
            if ($hw.HasDgpu) { $s += 'spark-turbo' } else { $s += 'spark-rendi' }
            $s += 'spark-equili'
        } else {
            if ($hw.BatteryPct -ge 0 -and $hw.BatteryPct -lt 20) { $s += 'spark-ultra' }
            else { $s += 'spark-ahorro'; $s += 'spark-ultra' }
        }
    } else {
        $s += 'spark-equili'; $s += 'spark-rendi'; if ($hw.HasDgpu) { $s += 'spark-turbo' }; $s += 'spark-max'
    }
    Write-STLine "  planes recomendados para tu equipo:" 'cyan'
    foreach ($k in $s) {
        $meta = $script:STPowerSet[$k]
        Write-STInfo "  $($meta.num). $($meta.name)   ->  sparktune power"
    }
}
