# SparkTune power.ps1 — planes de energia SparkTune.
# Duplica el plan equilibrado de Windows y ajusta valores de CPU y tiempos.
# La accion guarda el plan activo previo para poder restaurarlo.
# Cargado por catalog.ps1.

$script:STPowerSet = @{
    'spark-portatil-max' = @{ num=7; base='381b4222-f694-41f0-9685-ff5bb260df2e'; name='SparkTune Portátil Máximo' }
    'spark-ultra'    = @{ num=1; base='381b4222-f694-41f0-9685-ff5bb260df2e'; name='SparkTune Ultra Ahorro' }   # base: equilibrado
    'spark-ahorro'   = @{ num=2; base='381b4222-f694-41f0-9685-ff5bb260df2e'; name='SparkTune Ahorro' }          # base: equilibrado
    'spark-equili'   = @{ num=3; base='381b4222-f694-41f0-9685-ff5bb260df2e'; name='SparkTune Equilibrado' }     # base: equilibrado
    'spark-rendi'    = @{ num=4; base='381b4222-f694-41f0-9685-ff5bb260df2e'; name='SparkTune Rendimiento' }     # base: equilibrado
    'spark-turbo'    = @{ num=5; base='381b4222-f694-41f0-9685-ff5bb260df2e'; name='SparkTune Alto Rendimiento' }
    'spark-max'      = @{ num=6; base='381b4222-f694-41f0-9685-ff5bb260df2e'; name='SparkTune Maximo (sobremesa)' }
}
$script:STPowerGuidFile = Join-Path $Global:STHome 'power-guids.json'
$script:STPowerPrevFile = Join-Path $Global:STHome 'power-prev.txt'

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
    # /duplicatescheme acepta un GUID de destino, no el nombre del plan.
    $g = [guid]::NewGuid().ToString()
    Invoke-STPowerCfg @('/duplicatescheme', $base, $g) | Out-Null
    try {
        Invoke-STPowerCfg @('/changename', $g, $name) | Out-Null
    } catch {
        try { Invoke-STPowerCfg @('/delete', $g) | Out-Null } catch { }
        throw
    }
    return $g
}

function Set-STPlanValues {
    param([string]$Guid, [hashtable]$Ac, [hashtable]$Dc, [hashtable]$Subs = @{})
    foreach ($kv in $Ac.Keys) {
        $pair = $kv.Split('|')
        Invoke-STPowerCfg @('/setacvalueindex', $Guid, $pair[0], $pair[1], "$($Ac[$kv])") | Out-Null
    }
    foreach ($kv in $Dc.Keys) {
        $pair = $kv.Split('|')
        Invoke-STPowerCfg @('/setdcvalueindex', $Guid, $pair[0], $pair[1], "$($Dc[$kv])") | Out-Null
    }
}

function Get-STPlanSpec([string]$Key, $hw) {
    # Los mismos identificadores de ajustes se usan tanto en CA como en bateria.
    # Los tiempos de VIDEOIDLE y STANDBYIDLE se expresan en segundos.
    $minAc = 5; $minDc = 5; $maxAc = 100; $maxDc = 100
    $videoDc = 600; $sleepDc = 1800
    switch ($Key.ToLowerInvariant()) {
        'spark-portatil-max' { $maxDc = 80; $videoDc = 300; $sleepDc = 900 }
        'spark-ultra'  { $maxDc = 60; $videoDc = 180; $sleepDc = 600 }
        'spark-ahorro' { $maxDc = 80; $videoDc = 300; $sleepDc = 900 }
        'spark-equili' { }
        'spark-rendi'  { $minAc = 25 }
        'spark-turbo'  { $minAc = 50 }
        'spark-max'    { $minAc = 100 }
        default { throw "spec desconocida $Key" }
    }
    $spec = @{
        Ac = @{ 'SUB_PROCESSOR|PROCTHROTTLEMIN'=$minAc; 'SUB_PROCESSOR|PROCTHROTTLEMAX'=$maxAc }
        Dc = @{ 'SUB_PROCESSOR|PROCTHROTTLEMIN'=$minDc; 'SUB_PROCESSOR|PROCTHROTTLEMAX'=$maxDc
                'SUB_VIDEO|VIDEOIDLE'=$videoDc; 'SUB_SLEEP|STANDBYIDLE'=$sleepDc }
    }
    if ($Key -eq 'spark-portatil-max') {
        $spec.Ac['SUB_PROCESSOR|PERFEPP'] = 0
        $spec.Dc['SUB_PROCESSOR|PERFEPP'] = 75
    }
    return $spec
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
        try {
            $spec = Get-STPlanSpec $Key $null
            Set-STPlanValues -Guid $g -Ac $spec.Ac -Dc $spec.Dc
            Set-STPlanGuid -Key $Key -Guid $g
        } catch {
            try { Invoke-STPowerCfg @('/delete', $g) | Out-Null } catch { }
            throw
        }
    }
    if ($Activate) { Invoke-STPowerCfg @('/setactive', $g) | Out-Null }
    return $g
}

function Get-STActivePowerGuid {
    $text = Invoke-STPowerCfg @('/getactivescheme')
    if ($text -notmatch '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        throw 'No se pudo identificar el plan de energia activo.'
    }
    return $matches[1]
}

function Remove-STPowerPlans {
    # Solo borrar los GUID registrados por SparkTune, nunca por coincidencia de nombre.
    if (-not (Test-Path $script:STPowerGuidFile)) { return }
    try { $map = Get-Content $script:STPowerGuidFile -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'No se puede leer power-guids.json; no se borrara ningun plan.' }
    $active = Get-STActivePowerGuid
    foreach ($p in $map.PSObject.Properties) {
        $g = [string]$p.Value
        if ($g -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') { throw 'GUID de plan invalido; no se borraran planes.' }
        if ($g -eq $active) { throw 'Un plan SparkTune esta activo; restaura otro plan antes de borrarlo.' }
    }
    foreach ($p in $map.PSObject.Properties) { Invoke-STPowerCfg @('/delete', [string]$p.Value) | Out-Null }
    Remove-Item -LiteralPath $script:STPowerGuidFile -Force -ErrorAction Stop
}

# ---------- acciones del catalogo ----------
function Get-PowerCatalogActions {
    $A = @()
    foreach ($key in ($script:STPowerSet.Keys | Sort-Object { $script:STPowerSet[$_].num })) {
        $meta = $script:STPowerSet[$key]
        $descEs = switch ($key) {
            'spark-portatil-max' { 'Enchufado: hasta 100% de CPU y preferencia por rendimiento en equipos compatibles. En batería: hasta 80%, pantalla a 5 min y suspensión a 15 min.' }
            'spark-ultra'  { 'En bateria: CPU hasta 60%, pantalla a 3 min y suspension a 10 min de inactividad.' }
            'spark-ahorro' { 'En bateria: CPU hasta 80%, pantalla a 5 min y suspension a 15 min de inactividad.' }
            'spark-equili' { 'CPU hasta 100%; en bateria, pantalla a 10 min y suspension a 30 min.' }
            'spark-rendi'  { 'CPU minimo 25% enchufado; hasta 100% en bateria y enchufado.' }
            'spark-turbo'  { 'CPU minimo 50% enchufado; no modifica directamente la GPU.' }
            'spark-max'    { 'CPU minimo 100% enchufado; puede aumentar el consumo y el calor.' }
        }
        $descEn = switch ($key) {
            'spark-portatil-max' { 'Plugged in: up to 100% CPU and performance preference on compatible hardware. On battery: up to 80%, display off after 5 min and sleep after 15 min.' }
            'spark-ultra'  { 'On battery: CPU max 60%, display off after 3 min, sleep after 10 min.' }
            'spark-ahorro' { 'On battery: CPU max 80%, display off after 5 min, sleep after 15 min.' }
            'spark-equili' { 'CPU max 100%; on battery, display off after 10 min and sleep after 30 min.' }
            'spark-rendi'  { 'CPU minimum 25% on AC; maximum 100% on AC and battery.' }
            'spark-turbo'  { 'CPU minimum 50% on AC; does not directly change the GPU.' }
            'spark-max'    { 'CPU minimum 100% on AC; may increase heat and consumption.' }
        }
        $risk = 'bajo'; if ($key -in @('spark-rendi','spark-turbo','spark-max','spark-portatil-max')) { $risk = 'medio' }
        $perfs = switch ($key) {
            'spark-portatil-max' { @('portatil-rendimiento','gaming','creativo') }
            'spark-ultra'  { @('portatil-ahorro','bajos-recursos','ofimatica') }
            'spark-ahorro' { @('portatil-ahorro','ofimatica','bajos-recursos') }
            'spark-equili' { @('ofimatica','gaming','portatil-rendimiento','bajos-recursos','personalizado') }
            'spark-rendi'  { @('gaming','portatil-rendimiento','ofimatica') }
            'spark-turbo'  { @('gaming','portatil-rendimiento') }
            'spark-max'    { @('gaming','ofimatica') }
        }
        $detect = { param($hw, $action)
            if ($hw.IsLaptop) {
                if ($($action.planKey) -eq 'spark-max') { return $false }
                if ($($action.planKey) -eq 'spark-turbo' -and -not $hw.HasDgpu) { return $false }
            } else {
                if ($($action.planKey) -in @('spark-ultra','spark-ahorro','spark-portatil-max')) { return $false }
                if ($($action.planKey) -eq 'spark-turbo' -and -not $hw.HasDgpu) { return $false }
            }
            return $true
        }
        $preview = {
            param($action)
            $cur = ''
            $act2 = (powercfg.exe /getactivescheme 2>$null) -join "`n"
            if ($act2 -match '\(([^)]+)\)\s*$') { $cur = $matches[1] }
            elseif ($act2 -match ':\s*(.+?)\s*\(') { $cur = $matches[1] }
            "$cur  ->  $($action.planName)"
        }
        $apply = {
            param($action)
            $prev = Get-STActivePowerGuid
            Set-STStateFile "power.$($action.planKey)" @{ previous = $prev }
            Install-STPowerPlan -Key $action.planKey | Out-Null
        }
        $undo = {
            param($action)
            $state = Get-STStateFile "power.$($action.planKey)"
            if (-not $state -or -not $state.previous) { throw 'Sin plan previo para esta accion; restaura manualmente el plan original.' }
            Invoke-STPowerCfg @('/setactive', [string]$state.previous) | Out-Null
            Remove-STStateFile "power.$($action.planKey)"
        }
        $act = @{
            id    = "power.$key"
            planKey = $key
            planName = $meta.name
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
            if (-not $prev) { throw 'Sin plan previo guardado; selecciona otro plan antes de borrar los de SparkTune.' }
            Invoke-STPowerCfg @('/setactive', $prev) | Out-Null
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
            if (($key -eq 'spark-portatil-max' -and -not $hw.IsLaptop) -or ($key -eq 'spark-max' -and $hw.IsLaptop)) { continue }
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
                    try {
                        $prev = ''
                        if (Test-Path $script:STPowerPrevFile) { $prev = (Get-Content $script:STPowerPrevFile -First 1) }
                        if (-not $prev) { throw 'Sin plan previo guardado; selecciona otro plan antes de borrar los de SparkTune.' }
                        Invoke-STPowerCfg @('/setactive', $prev) | Out-Null
                        Remove-STPowerPlans
                        Write-STOk "plan previo restaurado: $prev"
                    } catch { Write-STErr $_.Exception.Message }
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
            $s += 'spark-portatil-max'
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
