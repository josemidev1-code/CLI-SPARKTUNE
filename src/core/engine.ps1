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

# ---------- estat d'accions (undo complex: snapshots de configuracion) ----------
function Get-STStateFile([string]$Id) {
    $f = Join-Path $Global:STHome "state-$Id.json"
    if (-not (Test-Path $f)) { return $null }
    try { return (Get-Content $f -Raw -Encoding UTF8) | ConvertFrom-Json } catch { return $null }
}
function Set-STStateFile([string]$Id, $Data) {
    $f = Join-Path $Global:STHome "state-$Id.json"
    $tmp = "$f.tmp"
    $json = ConvertTo-Json $Data -Depth 10
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -Path $tmp -Destination $f -Force
}
function Remove-STStateFile([string]$Id) {
    $f = Join-Path $Global:STHome "state-$Id.json"
    if (Test-Path $f) { Remove-Item $f -Force }
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
    $NoBanner = [bool]($NoBanner -or -not $Global:STBanner)
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
    if (-not $Nivel -and $Global:STNivelDefault) { $Nivel = $Global:STNivelDefault }
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
        @{ id='creativo';            icon='8' }
        @{ id='desarrollo';          icon='9' }
        @{ id='personalizado';       icon='10' }
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
    param([string]$Id = '', [string]$Category = '', [switch]$Yes)
    $pend = @(Get-STJournalPending)
    if ($Id) { $pend = @($pend | Where-Object { $_.id -eq $Id }) }
    if ($Category) { $pend = @($pend | Where-Object { $_.categoria -eq $Category }) }
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

# ---------- apps (instalador tipo winutil, via winget) ----------
function Get-STAppsCatalog {
    $f = Join-Path $Global:STData 'apps.json'
    if (-not (Test-Path $f)) { Write-STWarn 'apps.json no encontrado'; return $null }
    try { return (Get-Content $f -Raw -Encoding UTF8) | ConvertFrom-Json } catch { Write-STErr "apps.json: $($_.Exception.Message)"; return $null }
}
function Test-STWinget {
    $c = Get-Command winget.exe -ErrorAction SilentlyContinue
    return [bool]$c
}
function Invoke-STAppsMenu {
    Enable-STVirtualTerminal
    if (-not (Test-STWinget)) {
        Write-STWarn 'winget no esta disponible. Instalalo desde "Administrador de aplicaciones" (ms-windows-store:) o App Installer.'
        return
    }
    $cat = Get-STAppsCatalog
    if (-not $cat) { return }
    $lang = if ($Global:STLang -eq 'en') { 'en' } else { 'es' }
    while ($true) {
        Clear-STScreen
        Write-STLine ''
        Write-STLine "  $(if ($lang -eq 'en') { 'Install apps (winget)' } else { 'Instalar apps (winget)' })" 'cyan' 'bold'
        Write-STLine ''
        $items = @()
        foreach ($c in $cat.categories) {
            $lbl = if ($lang -eq 'en') { $c.label_en } else { $c.label_es }
            $n = @($cat.apps | Where-Object { $_.cat -eq $c.id -and -not $_.hidden }).Count
            $items += [pscustomobject]@{ id = $c.id; label = "$lbl  ($n)" }
        }
        $items += [pscustomobject]@{ id = '_all'; label = $(if ($lang -eq 'en') { 'Update everything installed' } else { 'Actualizar todo lo instalado' }) }
        $items += [pscustomobject]@{ id = '_quit'; label = 'q. ' + (T 'nav.quit') }
        $idx = Show-STMenu -Title "  apps" -Items $items
        if ($idx -lt 0) { return }
        $pick = $items[$idx].id
        switch ($pick) {
            '_quit' { return }
            '_all'  { Invoke-STWinget @('upgrade','--include-unknown','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') }
            default { Invoke-STAppsCategory $cat $pick $lang }
        }
    }
}
function Invoke-STWinget([array]$WArgs) {
    Write-STLine ''
    Write-STInfo "winget $($WArgs -join ' ')"
    try { & winget.exe @WArgs } catch { Write-STErr $_.Exception.Message }
    Write-STLine ''
    Read-STKey | Out-Null
}
function Install-STWingetApp($App, [string]$Scope, [bool]$Interactive) {
    # instala 1 app; devuelve 'ok' | 'notfound' | 'fail'.wingetCode | 'error'.mensaje
    $w = @('install','-e','--id',$App.winget,'--accept-package-agreements','--accept-source-agreements')
    if (-not $Interactive) { $w += '--disable-interactivity' }
    if ($Scope -eq 'user') { $w += '--scope=user' }
    try {
        if ($Interactive) { & winget.exe @w; if ($LASTEXITCODE -eq 0) { return 'ok' }; return 'fail' }
        $out = (& winget.exe @w 2>&1) -join "`n"
        if ($LASTEXITCODE -eq 0) { return 'ok' }
        if ($out -match '0x8A150014|no found|no se encontr|Package status Unknown') { return 'notfound' }
        if ($out -match '(0x[0-9A-Fa-f]{8})') { return "fail.$($matches[1])" }
        return 'fail'
    } catch { return "error.$($_.Exception.Message)" }
}
function Get-STAppsByToken($Cat, [string]$Tok) {
    # resuelve token por id de app, nombre (substring) o winget id
    $t = "$Tok".Trim().ToLowerInvariant()
    $hit = $null
    foreach ($a in $Cat.apps) {
        if ("$($a.id)".ToLowerInvariant() -eq $t) { $hit = $a; break }
        if ("$($a.winget)".ToLowerInvariant() -eq $t) { $hit = $a; break }
    }
    if (-not $hit) { foreach ($a in $Cat.apps) { if ("$($a.name)".ToLowerInvariant() -match [regex]::Escape($t)) { $hit = $a; break } } }
    return $hit
}
function Update-STWingetApp($App, [bool]$Interactive) {
    # actualiza 1 app; 'ok' | 'notfound' (no instalada/desconocida) | 'fail' | 'error'.msg
    $w = @('upgrade','-e','--id',$App.winget,'--accept-package-agreements','--accept-source-agreements')
    if (-not $Interactive) { $w += '--disable-interactivity' }
    try {
        if ($Interactive) { & winget.exe @w; if ($LASTEXITCODE -eq 0) { return 'ok' }; return 'fail' }
        $out = (& winget.exe @w 2>&1) -join "`n"
        if ($LASTEXITCODE -eq 0) { return 'ok' }
        if ($LASTEXITCODE -eq -1978335189) { return 'ok' }   # 0x8A15002B: no se encontro aplicacion para actualizar (no instalada)
        if ($out -match '0x8A150014|no found|no se encontr|No installed package found') { return 'notfound' }
        return 'fail'
    } catch { return "error.$($_.Exception.Message)" }
}
function Invoke-STAppsInstall {
    param([string]$List, [string]$Scope, [bool]$Interactive, [string]$Mode = 'install')
    if ($Scope -and $Scope -ne 'user') { Write-STErr "apps: --scope no valido: $Scope (soportado: user)"; exit 1 }
    if ($Mode -eq 'update' -and $Scope) { Write-STErr 'apps: --scope solo aplica a install'; exit 1 }
    if (-not $Global:STDryRun -and -not (Test-STWinget)) { Write-STWarn 'winget no esta disponible.'; exit 1 }
    $cat = Get-STAppsCatalog
    if (-not $cat) { exit 1 }
    $toks = @($List -split ',' | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($toks.Count -eq 0) { Write-STErr "apps: lista vacia (usa --install=a,b o --update=a,b)"; exit 1 }
    $found = @(); $missing = @()
    foreach ($t in $toks) { $a = Get-STAppsByToken $cat $t; if ($a) { $found += $a } else { $missing += $t } }
    foreach ($m in $missing) { Write-STWarn "desconocida: $m (usa sparktune apps para ver el catalogo)" }
    if ($found.Count -eq 0) { exit 1 }
    $fail = @(); $skip = @()
    foreach ($a in $found) {
        if ($Global:STDryRun) {
            if ($Mode -eq 'update') { Write-STInfo "[dry-run] winget upgrade -e --id $($a.winget)$(if ($Interactive) { ' --interactive' } else { '' })" }
            else { Write-STInfo "[dry-run] winget install -e --id $($a.winget)$(if ($Scope -eq 'user') { ' --scope=user' } else { '' })$(if ($Interactive) { ' --interactive' } else { '' })" }
            continue
        }
        Write-STInfo "-> $($a.name)"
        if ($a.portable) { Write-STInfo "  portable: winget lo instala en tu carpeta de apps de usuario (sin registro/instalador)" }
        if ($Mode -eq 'update') { $r = Update-STWingetApp -App $a -Interactive:$Interactive }
        else { $r = Install-STWingetApp -App $a -Scope $Scope -Interactive:$Interactive }
        if ($r -eq 'ok') { Write-STOk $a.name }
        elseif ($r -eq 'notfound') {
            if ($Mode -eq 'update') { Write-STInfo "no instalada, se omite: $($a.name)"; $skip += $a.name }
            else { Write-STWarn "no encontrada en winget: $($a.name) [$($a.winget)]"; $fail += $a.name }
        }
        else {
            $cod = ''; if ($r -match '^fail\.(.+)$') { $cod = " ($($matches[1]))" }
            if ($Mode -eq 'update') { Write-STErr "fallo actualizando: $($a.name)$cod" } else { Write-STErr "fallo: $($a.name)$cod" }
            $fail += $a.name
        }
    }
    Write-STLine ''
    if ($Global:STDryRun) { Write-STInfo "dry-run: $($found.Count) apps"; return }
    $verb = @{ install = 'instaladas'; update = 'actualizadas' }[$Mode]
    if ($fail.Count -gt 0) { Write-STWarn "$($found.Count - $fail.Count)/$($found.Count) $verb; pendientes: $($fail -join ', ')" }
    else {
        $msg = "$($found.Count) $verb"
        if ($skip.Count -gt 0) { $msg += " ($($skip.Count) omitidas por no instaladas)" }
        Write-STOk $msg
    }
}
function Invoke-STAppsCategory($cat, [string]$CatId, [string]$Lang) {
    $apps = @($cat.apps | Where-Object { $_.cat -eq $CatId -and -not $_.hidden })
    if ($apps.Count -eq 0) { $apps = @($cat.apps | Where-Object { $_.cat -eq $CatId }) }
    $installed = @{}
    try {
        $lst = (& winget.exe list --accept-source-agreements --disable-interactivity 2>$null) -join "`n"
        foreach ($ln in ($lst -split "`n")) {
            foreach ($a in $apps) { if ($ln -match [regex]::Escape($a.name)) { $installed[$a.id] = $true } }
        }
    } catch { }
    $sel = New-Object 'bool[]' $apps.Count
    $cur = 0
    while ($true) {
        Clear-STScreen
        Write-STLine ''
        Write-STLine "  $(if ($Lang -eq 'en') { 'Apps' } else { 'Apps' })  ·  ✔=$(if ($Lang -eq 'en') {'installed'} else {'instalada'})" 'cyan' 'bold'
        Write-STLine ''
        for ($i = 0; $i -lt $apps.Count; $i++) {
            $box = '[ ]'; if ($sel[$i]) { $box = '[x]' }
            $tick = if ($installed.ContainsKey($apps[$i].id)) { ' ✔' } else { '' }
            $tagp = if ($apps[$i].portable) { ' (p)' } else { '' }
            $mark = '  '; $col = ''
            if ($i -eq $cur) { $mark = '> '; $col = 'yellow' }
            Write-STLine "  $mark$box $($apps[$i].name)$tick$tagp" $col $(if ($i -eq $cur) { 'bold' } else { '' })
        }
        $nSel = 0; foreach ($b in $sel) { if ($b) { $nSel++ } }
        Write-STLine ''
        Write-STLine "  $nSel $(if ($Lang -eq 'en') {'selected'} else {'seleccionadas'})   (p)=$(if ($Lang -eq 'en') {'portable'} else {'portable'})   Espacio=$(T 'nav.space')  Enter=$(T 'nav.enter')  Esc=$(T 'nav.esc')" 'gray'
        $k = Read-STKey
        switch ($k.Key) {
            'Up' { $cur--; if ($cur -lt 0) { $cur = $apps.Count - 1 } }
            'Down' { $cur++; if ($cur -ge $apps.Count) { $cur = 0 } }
            'Space' { $sel[$cur] = -not $sel[$cur] }
            'Esc' { return }
            'Enter' {
                $todo = @()
                for ($i = 0; $i -lt $apps.Count; $i++) { if ($sel[$i]) { $todo += $apps[$i] } }
                if ($todo.Count -eq 0) { Read-STKey | Out-Null; continue }
                if ($Global:STDryRun) { foreach ($t in $todo) { Write-STInfo "[dry-run] winget install -e --id $($t.winget)" }; Read-STKey | Out-Null; return }
                if (-not (Read-STConfirm -Question $(if ($Lang -eq 'en') { "Install $($todo.Count) apps via winget? (y/n)" } else { "Instalar $($todo.Count) apps via winget? (s/n)" }))) { continue }
                foreach ($t in $todo) {
                    Write-STInfo "-> $($t.name)"
                    $r = Install-STWingetApp -App $t -Scope ''
                    if ($r -eq 'ok') { Write-STOk $t.name; try { $installed[$t.id] = $true } catch { } }
                    else {
                        $cod = ''; if ($r -match '^fail\.(.+)$') { $cod = " ($($matches[1]))" }
                        if ($r -eq 'notfound') { Write-STWarn "no encontrada en winget: $($t.name) [$($t.winget)]" }
                        else { Write-STErr "fallo: $($t.name)$cod" }
                    }
                }
                Write-STLine ''
                Read-STKey | Out-Null
                return
            }
        }
    }
}

# ---------- doctor ----------
function Invoke-STDoctor {
    Write-STLine ''
    Write-STLine "  $(T 'doctor.title')" 'cyan' 'bold'
    Write-STLine ''
    $issues = 0; $oks = 0
    # 1) coherencia journal (comprobable sin admin)
    $pend = @(Get-STJournalPending)
    Load-STCatalog
    $all = Get-STCatalogActions
    $known = @{}; foreach ($a in $all) { $known[$a.id] = $true }
    foreach ($e in $pend) {
        if (-not $known.ContainsKey($e.id)) { Write-STWarn "$($e.id): accion ya no existe en el catalogo (undo manual: $($e.undoCmd))"; $issues++ }
    }
    if ($pend.Count -ge 1) { Write-STOk "$($pend.Count) cambios activos, todos reconocidos"; $oks++ }
    else { Write-STInfo 'sin cambios activos en el journal' }
    # 2) espacio en C:
    $hw = Get-STHardware
    if ($hw.SpaceTotalGB -gt 0 -and $hw.SpaceFreeGB -lt 5) {
        Write-STWarn "C: solo $($hw.SpaceFreeGB) GB libres. Usa sparktune --perfil=limpieza"
        $issues++
    } elseif ($hw.SpaceTotalGB -gt 0) { Write-STOk "C: $($hw.SpaceFreeGB) GB libres"; $oks++ }
    # 3) journal grande
    $j = @(Read-STJournal)
    if ($j.Count -gt 200) { Write-STWarn "journal con $($j.Count) entradas: borra las antiguas a mano (~/.sparktune/journal.json) o usa undo" }
    Write-STLine ''
    if ($issues -eq 0 -and $oks -gt 0) { Write-STOk (T 'doctor.clean') }
    elseif ($issues -gt 0) { Write-STWarn "$(T 'doctor.issues') $issues" }
    else { Write-STInfo 'nada que comprobar' }
    if (-not (Is-STAdmin)) { Write-STInfo 'algunas comprobaciones requieren admin (ejecuta como administrador para el informe completo)' }
}

# ---------- report ----------
function Show-STReport {
    param([string]$Out = '')
    $hw = Get-STHardware
    $pend = @(Get-STJournalPending)
    $journal = @(Read-STJournal)
    $path = if ($Out) { $Out } else { Join-Path $Global:STHome "report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html" }
    $e = { param($s) "$s".Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
    $rows = ($journal | ForEach-Object { "<tr><td>$(& $e $_.seq)</td><td>$(& $e $_.id)</td><td>$(& $e $_.status)</td><td>$(& $e $_.titulo)</td></tr>" }) -join ''
    $diskRows = ($hw.Disks | ForEach-Object { "<tr><td>$(& $e $_.Model)</td><td>$($_.SizeGB) GB</td><td>$(& $e $_.Type)</td></tr>" }) -join ''
    $html = @"
<!doctype html><html><head><meta charset='utf-8'><title>SparkTune report</title>
<style>body{font-family:Segoe UI,Arial;background:#111;color:#ddd;padding:2em;max-width:900px}
h1{color:#22d3ee}h2{color:#22d3ee;margin-top:2em;border-bottom:1px solid #333}
table{border-collapse:collapse;width:100%}td,th{padding:4px 8px;border-bottom:1px solid #333;text-align:left}
.ok{color:#4ade80}.warn{color:#facc15}.bad{color:#f87171}</style></head><body>
<h1>⚡ SparkTune v$Global:STVersion</h1>
<p>Generado: $(Get-Date)</p>
<h2>Sistema</h2>
<table>
<tr><th>Sistema</th><td>$(& $e $hw.OsName) (build $($hw.Build))</td></tr>
<tr><th>CPU</th><td>$(& $e $hw.Cpu) [$($hw.CpuCores)C/$($hw.CpuThreads)T]</td></tr>
<tr><th>RAM</th><td>$($hw.RamGB) GB</td></tr>
<tr><th>GPU</th><td>$(& $e (($hw.Gpu | ForEach-Object { $_.Name }) -join ' + '))</td></tr>
<tr><th>Bateria</th><td>$(if ($hw.Battery) { "$($hw.BatteryPct)% $(if($hw.Plugged){'enchufado'}else{'bateria'})" } else { 'sobremesa' })</td></tr>
<tr><th>Disco C:</th><td>$($hw.SpaceFreeGB) GB libres de $($hw.SpaceTotalGB) GB</td></tr>
<tr><th>Plan</th><td>$(& $e $hw.PowerPlan)</td></tr>
</table>
<h2>Discos</h2><table><tr><th>Modelo</th><th>Tamaño</th><th>Tipo</th></tr>$diskRows</table>
<h2>Journal ($($journal.Count) entradas, $($pend.Count) activas)</h2>
<table><tr><th>seq</th><th>id</th><th>estado</th><th>titulo</th></tr>$rows</table>
<p style='margin-top:3em;color:#666'>SparkTune · by @josemidev1 · MIT</p>
</body></html>
"@
    [System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding($false)))
    Write-STOk "informe generado: $path"
    if (-not [string]::IsNullOrEmpty($Out)) { Write-STInfo "--out usado: $Out" }
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
