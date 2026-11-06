# SparkTune engine.ps1 — preview/apply/undo de acciones, asistente interactivo,
# restauracion, status, analyze. Depende de ui/detect/journal/catalog.

# ---------- helpers de registro ----------
function Get-STRegValue {
    param([string]$Path, [string]$Name, $Default = $null)
    try {
        $v = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        if ($null -eq $v) { return $Default }
        return $v
    } catch { return $Default }
}
function Set-STRegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

function Get-STServiceState([string]$Name) {
    try {
        $s = Get-Service -Name $Name -ErrorAction Stop
        return "$($s.Status)"
    } catch { return 'NotFound' }
}
function Get-STServiceStart([string]$Name) {
    try {
        $ci = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
        return "$($ci.StartMode)"
    } catch { return 'NotFound' }
}
function Set-STServiceStart {
    param([string]$Name, [string]$Startup)   # Auto|Manual(=demand)|Disabled
    $sc = 'demand'; if ($Startup -eq 'Auto') { $sc = 'auto' }; if ($Startup -eq 'Disabled') { $sc = 'disabled' }
    $out = & sc.exe config $Name start=$sc 2>&1
    if ($LASTEXITCODE -ne 0) { throw "sc.exe config $Name : $out" }
}
function Restart-STService([string]$Name) {
    try {
        $s = Get-Service -Name $Name -ErrorAction Stop
        if ($s.Status -eq 'Running') { Restart-Service -Name $Name -Force -ErrorAction Stop }
    } catch { }
}

# ---------- admin / restore point ----------
function Request-STAdmin([switch]$Yes) {
    if (Is-STAdmin) { return $true }
    Write-STWarn (T 'admin.need')
    if ($Yes) { return $false }
    return (Read-STConfirm -Question 'Reintentar con privilegios elevados? (s/n) (relanza la consola)')
}

function Test-STRestoreEnabled {
    # metodo pragmatico: estado de proteccion via CIM (requiere admin; fallback registro)
    try {
        $pv = @(Get-CimInstance -ClassName Win32_RecoverableVolume -ErrorAction Stop)
        foreach ($v in $pv) { if ($v.SystemRestore -eq 1 -or $v.VolumeName -match 'C:') { return ($v.SystemRestore -eq 1) } }
    } catch { }
    return $null   # desconocido (normal sin admin)
}

function New-STRestorePoint {
    if (-not (Is-STAdmin)) { Write-STWarn 'Crear punto de restauracion requiere admin.'; return $false }
    $en = Test-STRestoreEnabled
    if ($en -eq $false) { Write-STWarn (T 'rp.nofeature') }
    try {
        Checkpoint-Computer -Description "SparkTune $($Global:STVersion)" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Seconds 2
            $last = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Select-Object -Last 1
            if ($last -and "$($last.Description)" -match 'SparkTune') {
                Write-STOk (T 'rp.done'); return $true
            }
        }
        Write-STWarn 'El punto sigue creandose en segundo plano; se continua.'
        return $true
    } catch {
        Write-STWarn "$(T 'rp.fail'): $($_.Exception.Message)"
        return $false
    }
}

# ---------- ficha ----------
function Show-STCard {
    param($Action, [switch]$Compact)
    $risk = $Action.riesgo
    $riskColor = switch ($risk) { 'alto' { 'red' } 'medio' { 'yellow' } 'bajo' { 'green' } default { 'gray' } }
    $t = STField $Action 'titulo'
    $border = '-' * ([Math]::Min(76, 14 + $t.Length))
    Write-STLine $border 'cyan'
    Write-STLine "  $t" 'cyan' 'bold'
    Write-STLine $border 'cyan'
    Write-STLine "  $(T 'card.desc'): $(STField $Action 'descripcion')"
    if ($Action.ContainsKey('aviso') -and $Action.aviso) {
        Write-STWarn (STField $Action 'aviso')
    }
    # diff actual -> propuesto
    $prevTxt = (T 'card.na')
    try {
        if ($Action.ContainsKey('preview') -and $Action.preview) { $prevTxt = (& $Action.preview) }
    } catch { $prevTxt = "(preview: $($_.Exception.Message))" }
    Write-STLine "  $(T 'card.cur'): $prevTxt" 'white'
    $revTxt = (T 'yes'); if (-not $Action.reversible) { $revTxt = "$(T 'no') ⚠" }
    $adminTxt = if ($Action.admin) { (T 'yes') } else { (T 'no') }
    $rebTxt   = if ($Action.reinicio) { (T 'yes') } else { (T 'no') }
    Write-STLine "  $(T 'card.risk'): $(T "risk.$risk")   $(T 'card.rev'): $revTxt   $(T 'card.admin'): $adminTxt   $(T 'card.reboot'): $rebTxt" $riskColor
    Write-STLine "  id: $($Action.id)" 'gray'
    Write-STLine $border 'cyan'
}

# ---------- aplicacion ----------
function Invoke-STApply {
    param($Action, [bool]$Yes = $false, [switch]$NoConfirm)
    $id = $Action.id
    $Yes = [bool]$Yes
    if ($Global:STDryRun) {
        Write-STInfo "[dry-run] $(STField $Action 'titulo')"
        Add-STJournalEntry -Action $Action -Status 'dryrun'
        return 'dry'
    }
    if (-not $Global:STDryRun -and $Action.needsRP -and -not $script:STRpDone -and -not $Yes) {
        $en = Test-STRestoreEnabled
        if ($en -ne $false) {
            if (Read-STConfirm -Question (T 'rp.create')) { New-STRestorePoint | Out-Null }
        } else { Write-STWarn (T 'rp.nofeature') }
        $script:STRpDone = $true
    }
    if ($Action.admin -and -not (Is-STAdmin)) {
        Write-STWarn "$(T 'admin.need')  -> $($id)"
        Add-STJournalEntry -Action $Action -Status 'failed' -Detail 'admin'
        return 'skip'
    }
    if (-not $NoConfirm -and -not $Yes) {
        Show-STCard $Action
        if ($Action.riesgo -eq 'alto') {
            if (-not (Read-STTypedYes)) { Add-STJournalEntry -Action $Action -Status 'failed' -Detail 'cancel'; return 'skip' }
        } else {
            if (-not (Read-STConfirm -Question (T 'confirm.one'))) { return 'skip' }
        }
    }
    $prev = ''
    try { $prev = (& $Action.preview) } catch { $prev = '' }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        if ($Action.ContainsKey('applyPre') -and $Action.applyPre) { & $Action.applyPre }
        & $Action.apply
        $sw.Stop()
        Add-STJournalEntry -Action $Action -Status 'applied' -Detail ([string]$sw.ElapsedMilliseconds) -PrevState ([string]$prev)
        Write-STOk "$((T 'apply.ok'))  $(STField $Action 'titulo')  ($($sw.ElapsedMilliseconds)ms)"
        return 'ok'
    } catch {
        $sw.Stop()
        Add-STJournalEntry -Action $Action -Status 'failed' -Detail $_.Exception.Message
        Write-STErr "$((T 'apply.fail'))  $(STField $Action 'titulo'): $($_.Exception.Message)"
        return 'fail'
    }
}

# ---------- wizard ----------
function Start-STWizard {
    param([switch]$NoBanner, [switch]$Yes, [string]$Perfil = '', [string]$Nivel = '')

    Show-STBanner -NoBanner:$NoBanner
    Write-STInfo "$(T 'hw.detect')."
    $hw = Get-STHardware
    Show-STDetectSummary $hw
    if ($Global:STDryRun) { Write-STWarn (T 'dryrun') }
    Write-STLine ''

    Load-STCatalog
    $all = Get-STCatalogActions

    if (-not $Perfil) { $Perfil = Select-STProfile }
    if (-not $Perfil) { return }
    if (-not $Nivel)  { $Nivel = Select-STLevel }
    if (-not $Nivel)  { return }

    $pkey = $Perfil.ToLowerInvariant()
    if ($pkey -eq 'personalizado' -or $pkey -eq 'custom') {
        $cands = @($all | Where-Object { Test-STApplies $_ $hw })
    } else {
        $cands = @(Resolve-STProfile -Perfil $pkey -Nivel $Nivel.ToLowerInvariant() -Hw $hw -All $all)
    }

    if ($cands.Count -eq 0) { Write-STWarn (T 'list.empty'); return }

    $sel = Select-STActions -Actions $cands
    if (-not $sel) { return }

    $script:STRpDone = $false
    $q = TF 'confirm.all' @($sel.Count)
    if (-not (Read-STConfirm -Question $q -Yes:$Yes)) { Write-STInfo '(cancelado)'; return }

    $i = 0; $ok = 0; $fail = 0; $skip = 0; $dry = 0
    foreach ($a in $sel) {
        $i++
        $lbl = "$i/$($sel.Count)"
        $r = Invoke-STApply -Action $a -Yes $Yes -NoConfirm
        switch ($r) { 'ok' { $ok++ } 'dry' { $dry++ } 'fail' { $fail++ } default { $skip++ } }
        Write-STProgress -Pct ([int](100 * $i / $sel.Count)) -Label "$lbl  $(STField $a 'titulo')"
    }
    Write-STProgress -Pct 100 -Label (T 'run.done')
    Write-STLine ''
    if ($Global:STDryRun -and $dry) {
        Write-STOk "$(T 'apply.ok'): $dry  (dry-run)"
    } else {
        Write-STOk  "$(T 'apply.ok'): $ok"
    }
    if ($fail) { Write-STErr "$(T 'apply.fail'): $fail" }
    if ($skip) { Write-STWarn "$(T 'apply.skip'): $skip" }
    if (-not $Global:STDryRun -and ($ok -gt 0)) {
        Write-STLine "  $(T 'run.undo')" 'cyan'
        $reboots = @($sel | Where-Object { $_.reinicio })
        if ($reboots.Count) { Write-STWarn "Requiere reinicio: $($reboots.id -join ', ')" }
    }
}

function Select-STProfile {
    $profs = @(
        @{ id='gaming';              icon='1' }
        @{ id='ofimatica';           icon='2' }
        @{ id='portatil-ahorro';     icon='3' }
        @{ id='portatil-rendimiento';icon='4' }
        @{ id='limpieza';            icon='5' }
        @{ id='bajos-recursos';      icon='6' }
        @{ id='red-privacidad';      icon='7' }
        @{ id='personalizado';       icon='8' }
    )
    $items = @()
    foreach ($p in $profs) { $items += [pscustomobject]@{ id = $p.id; label = "$(T "prof.$($p.id)")" } }
    $idx = Show-STMenu -Title (T 'menu.title') -Items $items
    if ($idx -lt 0) { return '' }
    return $items[$idx].id
}

function Select-STLevel {
    $items = @(
        [pscustomobject]@{ id='suave';    label = (T 'lvl.suave') }
        [pscustomobject]@{ id='medio';    label = (T 'lvl.medio') }
        [pscustomobject]@{ id='agresivo'; label = (T 'lvl.agresivo') }
    )
    $idx = Show-STMenu -Title (T 'menu.level') -Items $items
    if ($idx -lt 0) { return '' }
    return $items[$idx].id
}

function Show-STMenu {
    param([string]$Title, [array]$Items, [int]$Start = 0)
    $cur = $Start
    while ($true) {
        Clear-STScreen
        Write-STLine ''
        Write-STLine "  $Title" 'cyan' 'bold'
        Write-STLine ''
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $mark = '  '; $col = ''
            if ($i -eq $cur) { $mark = '> '; $col = 'yellow' }
            Write-STLine "    $mark$($Items[$i].label)" $col $(if ($i -eq $cur) { 'bold' } else { '' })
        }
        Write-STLine ''
        Write-STLine "    ↑↓ $(T 'nav.updown')   Enter $(T 'nav.enter')   Esc $(T 'nav.quit')" 'gray'
        $k = Read-STKey
        switch ($k.Key) {
            'Up'    { $cur--; if ($cur -lt 0) { $cur = $Items.Count - 1 } }
            'Down'  { $cur++; if ($cur -ge $Items.Count) { $cur = 0 } }
            'Enter' { return $cur }
            'Esc'   { return -1 }
        }
    }
    return -1
}

function Select-STActions {
    param([array]$Actions)
    $sel = New-Object 'bool[]' $Actions.Count
    # pre-seleccionar riesgo bajo/medio
    for ($i = 0; $i -lt $Actions.Count; $i++) {
        if ($Actions[$i].riesgo -in @('sin','bajo','medio')) { $sel[$i] = $true }
    }
    $cur = 0
    while ($true) {
        Clear-STScreen
        Write-STLine ''
        Write-STLine "  $(T 'list.title')" 'cyan' 'bold'
        Write-STLine ''
        $nSel = 0; foreach ($b in $sel) { if ($b) { $nSel++ } }
        for ($i = 0; $i -lt $Actions.Count; $i++) {
            $a = $Actions[$i]
            $box = '[ ]'; if ($sel[$i]) { $box = '[x]' }
            $mark = '  '; $col = ''
            if ($i -eq $cur) { $mark = '> '; $col = 'yellow' }
            $warn = ''; if ($a.riesgo -eq 'alto') { $warn = ' ⚠' }
            elseif ($a.riesgo -eq 'medio') { $warn = ' •' }
            $line = "  $mark$box $($a.categoria.PadRight(9)) $(STField $a 'titulo')$warn"
            Write-STLine $line $col $(if ($i -eq $cur) { 'bold' } else { '' })
        }
        Write-STLine ''
        Write-STLine "  Seleccionadas: $nSel/$($Actions.Count)   Espacio=$(T 'nav.space')  F=$(T 'nav.f')  A=$(T 'nav.a')  Enter=$(T 'nav.enter')  Esc=$(T 'nav.esc')" 'gray'
        $k = Read-STKey
        switch ($k.Key) {
            'Up'   { $cur--; if ($cur -lt 0) { $cur = $Actions.Count - 1 } }
            'Down' { $cur++; if ($cur -ge $Actions.Count) { $cur = 0 } }
            'Space' { $sel[$cur] = -not $sel[$cur] }
            'Esc'  { return $null }
            'Enter' {
                $out = @()
                for ($i = 0; $i -lt $Actions.Count; $i++) { if ($sel[$i]) { $out += $Actions[$i] } }
                if ($out.Count -eq 0) { Write-STWarn (T 'list.empty'); Read-STKey | Out-Null }
                else { return $out }
            }
            default {
        $ch = "$($k.Ch)".ToLowerInvariant()
        if ($ch -eq 'f') { Show-STCard $Actions[$cur]; Read-STKey | Out-Null }
        if ($ch -eq 'a' -or $ch -eq 'e') { $all = $true; foreach ($b in $sel) { if (-not $b) { $all = $false } }; for ($i = 0; $i -lt $sel.Count; $i++) { $sel[$i] = -not $all } }
            }
        }
    }
}

# ---------- undo ----------
function Invoke-STUndo {
    param([string]$Id = '', [switch]$Yes)
    $pend = @(Get-STJournalPending)
    if ($Id) { $pend = @($pend | Where-Object { $_.id -eq $Id }) }
    if ($pend.Count -eq 0) { Write-STInfo (T 'undo.none'); return }

    Write-STLine ''
    Write-STLine "  $(T 'undo.title')" 'cyan' 'bold'
    Write-STLine "  $(T 'undo.list')" 'gray'
    foreach ($e in $pend) { Write-STLine "    $($e.seq)  $($e.id)  — $($e.titulo)" }
    Write-STLine ''
    if ($pend.Count -gt 1 -and -not $Yes) {
        Write-STWarn 'Vas a DESHACER varios cambios. Escribe DESACER (mayusculas) para confirmar:'
        $w = Read-Host
        if ($w -cne 'DESACER' -and $w -cne 'UNDO') { Write-STInfo '(cancelado)'; return }
    }
    Load-STCatalog
    $all = Get-STCatalogActions
    $byId = @{}
    foreach ($a in $all) { $byId[$a.id] = $a }

    $rev = @($pend); [Array]::Reverse($rev)
    $i = 0
    foreach ($e in $rev) {
        $i++
        if (-not $e.reversible) { Write-STWarn "$($e.id): no reversible (limpieza) — omitido"; continue }
        $a = $byId[$e.id]
        if (-not $a) { Write-STWarn "$($e.id): accion no encontrada en el catalogo — manual: $($e.undoCmd)"; continue }
        if ($a.admin -and -not (Is-STAdmin)) { Write-STWarn "$($e.id): requiere admin — omitido"; continue }
        try {
            & $a.undo
            Mark-STJournalUndone -Seq $e.seq
            Write-STOk "undo OK  $($e.id)"
        } catch {
            Write-STErr "undo FAIL $($e.id): $($_.Exception.Message)"
        }
        Write-STProgress -Pct ([int](100 * $i / $rev.Count)) -Label "$i/$($rev.Count)"
    }
    Write-STProgress -Pct 100 -Label (T 'run.done')
}

# ---------- history ----------
function Show-STHistory {
    $entries = @(Read-STJournal)
    Write-STLine ''
    Write-STLine "  $(T 'history.title')" 'cyan' 'bold'
    Write-STLine ''
    if ($entries.Count -eq 0) { Write-STInfo (T 'history.none'); return }
    $undoneKeys = @{}
    foreach ($e in $entries) { if ($e.status -eq 'undo' -and $e.refSeq) { $undoneKeys["$($e.refSeq)"] = $true } }
    Write-STLine ("    {0,-18} {1,-26} {2,-10} {3}" -f 'seq','id','estado','titulo') 'gray'
    foreach ($e in $entries) {
        if ($e.status -eq 'undo') { continue }
        $st = $e.status
        $col = switch ($st) { 'applied' { if ($undoneKeys["$($e.seq)"]) { $st = 'undone'; 'gray' } else { 'green' } } 'failed' { 'red' } 'dryrun' { 'gray' } default { 'gray' } }
        Write-STLine ("    {0,-18} {1,-26} {2,-10} {3}" -f $e.seq, $e.id, $st, $e.titulo) $col
    }
    $pend = @(Get-STJournalPending)
    Write-STLine ''
    Write-STInfo "$(T 'history.line'): $($entries.Count) entradas, $($pend.Count) activas (sparktune undo para deshacer)"
}

# ---------- status ----------
function Show-STStatus {
    $hw = Get-STHardware
    Write-STLine ''
    Write-STLine "  SparkTune · $(T 'status.title')" 'cyan' 'bold'
    Write-STLine ''
    Show-STDetectSummary $hw
    Write-STInfo "$(T 'status.plan'): $($hw.PowerPlan) [$($hw.PowerPlanGuid)]"
    Write-STLine ''
    Write-STLine "  $(T 'status.heavy'):" 'cyan'
    $svcs = @('SysMain','WSearch','DiagTrack','Spooler','WaaSMedicSvc','MapsBroker')
    foreach ($n in $svcs) {
        $st = Get-STServiceState $n
        if ($st -eq 'NotFound') { continue }
        $col = if ($st -eq 'Running') { 'yellow' } else { 'gray' }
        Write-STLine ("    {0,-16} {1,-10} arranque: {2}" -f $n, $st, (Get-STServiceStart $n)) $col
    }
    try {
        $top = Get-Process -ErrorAction SilentlyContinue | Sort-Object WS -Descending | Select-Object -First 5
        foreach ($p in $top) {
            Write-STInfo ("  proc {0,-22} {1,8:N0} MB" -f $p.ProcessName, ($p.WS / 1MB))
        }
    } catch { }
    $pend = @(Get-STJournalPending)
    Write-STLine ''
    Write-STInfo "Journal: $($pend.Count) cambios activos (sparktune undo para deshacer)"
}

# ---------- analyze ----------
function Invoke-STAnalyze {
    Write-STLine ''
    Write-STLine "  $(T 'analyze.title')" 'cyan' 'bold'
    Write-STLine ''
    $targets = [ordered]@{
        'Temp usuario'        = $env:TEMP
        'Temp sistema'        = "$env:WINDIR\Temp"
        'Descargas'           = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads')
        'Documentos'          = ([Environment]::GetFolderPath('MyDocuments'))
        'Windows Update cache'= "$env:WINDIR\SoftwareDistribution\Download"
        'WER reports'         = "$env:ProgramData\Microsoft\Windows\WER"
        'Recycle Bin (C:)'    = 'C:\`$Recycle.Bin'
    }
    foreach ($k in $targets.Keys) {
        $path = $targets[$k]
        if (-not $path -or -not (Test-Path $path)) { continue }
        try {
            $bytes = 0
            $files = @(Get-ChildItem -Path $path -Recurse -Force -File -ErrorAction SilentlyContinue | Select-Object -First 30000)
            foreach ($f in $files) { $bytes += $f.Length }
            Write-STInfo ("{0,-24} {1,10:N1} MB   {2}" -f $k, ($bytes / 1MB), $path)
        } catch { Write-STWarn "$k : $($_.Exception.Message)" }
    }
    Write-STLine ''
    Write-STLine '  Archivos > 1 GB en carpetas de usuario:' 'cyan'
    try {
        $big = Get-ChildItem ([Environment]::GetFolderPath('UserProfile')) -Recurse -Force -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 1GB } | Sort-Object Length -Descending | Select-Object -First 15
        foreach ($f in $big) { Write-STInfo ("  {0,8:N1} GB  {1}" -f ($f.Length / 1GB), $f.FullName) }
    } catch { }
}
