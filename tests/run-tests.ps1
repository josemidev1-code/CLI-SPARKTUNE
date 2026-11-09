# SparkTune run-tests.ps1 — tests de contrato del catalogo sin dependencias externas.
# Ejecuta en PowerShell 5.1+ (Windows) o pwsh (para checks de metadatos).
#   - Estructura: BOM, JSON valido, campos obligatorios por accion
#   - Logica: deteccion de hardware simulada, coherencia profiles.json <-> catalogo,
#     no duplicados de id, diccionarios ES/EN simetricos, specs de planes de energia
# Los bloques apply/undo no se ejecutan (solo se metadatean): requieren Windows real.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'sparktune.ps1'))) { $root = $PSScriptRoot }

$fails = @()
function Check([string]$Name, [scriptblock]$Body) {
    try {
        & $Body
        Write-Host "  ok    $Name" -ForegroundColor Green
    } catch {
        $ex = $_
        $msg = ''
        try { $msg = $ex.Exception.ToString() } catch { }
        if (-not $msg) { try { $msg = "$($ex.ErrorDetails.Message) $($ex.InvocationInfo.PositionMessage)" } catch { $msg = 'error desconocido' } }
        Write-Host "  FAIL  $Name : $msg" -ForegroundColor Red
        $script:fails += $Name
    }
}

Write-Host "SparkTune contract tests" -ForegroundColor Cyan
$files = @(Get-ChildItem -Recurse -Path $root -Include *.ps1 -File | Where-Object { $_.FullName -notlike '*\tests\*' -or $_.Name -ne 'run-tests.ps1' })

Check 'ps1 files carry UTF-8 BOM' {
    foreach ($f in $files) {
        $b = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($b.Length -lt 3 -or $b[0] -ne 0xEF -or $b[1] -ne 0xBB -or $b[2] -ne 0xBF) { throw "$($f.Name) sin BOM" }
    }
}

Check 'profiles.json valid JSON' {
    $j = (Get-Content (Join-Path $root 'src\data\profiles.json') -Raw -Encoding UTF8) | ConvertFrom-Json
    if (-not $j) { throw 'null' }
}

# ---- entorno minimo para cargar el catalogo sin Windows ----
# stubs: globals.ps1 usa New-Item; catalog.ps1 usa Write-STWarn en carga
if (-not (Get-Command New-Item -ErrorAction SilentlyContinue)) {
    function global:New-Item { param([string]$ItemType,[string]$Path,[switch]$Force) return $null }
}
function Write-STWarn([string]$m) { }
function Is-STAdmin { return $false }
. (Join-Path $root 'src\core\globals.ps1')
. (Join-Path $root 'src\core\catalog.ps1')

$all = $null
Check 'catalog loads' {
    Load-STCatalog
    $script:all = @(Get-STCatalogActions)
    if ($all.Count -lt 40) { throw "solo $($all.Count) acciones" }
}

Check 'unique ids' {
    $dups = $all | Group-Object id | Where-Object { $_.Count -gt 1 }
    if ($dups) { throw (($dups | ForEach-Object { $_.Name }) -join ', ') }
}

Check 'required fields per action' {
    foreach ($a in $all) {
        foreach ($k in @('id','titulo','titulo_en','descripcion','descripcion_en','categoria','riesgo','reversible','admin','reinicio','perfiles','niveles','detect','preview','apply','undo','undoCmd')) {
            if (-not $a.ContainsKey($k) -or $null -eq $a[$k]) { throw "$($a.id): falta $k" }
        }
        if ($a.riesgo -notin @('sin','bajo','medio','alto')) { throw "$($a.id): riesgo invalido $($a.riesgo)" }
    }
}

Check 'profiles reference existing ids' {
    $j = (Get-Content (Join-Path $root 'src\data\profiles.json') -Raw -Encoding UTF8) | ConvertFrom-Json
    $ids = @{}; foreach ($a in $all) { $ids[$a.id] = $true }
    foreach ($p in $j.PSObject.Properties) {
        foreach ($l in $p.Value.PSObject.Properties) {
            foreach ($id in @($l.Value)) {
                if ($id -eq '*') { continue }
                if ($id -like 'power.spark-*') { continue }   # ids dinamicos del catalogo power
                if (-not $ids.ContainsKey($id)) { throw "$($p.Name).$($l.Name): id inexistente $id" }
            }
        }
    }
}

Check 'wizard menu matches profiles.json' {
    $eng = Get-Content (Join-Path $root 'src\core\engine.ps1') -Raw
    $menu = @([regex]::Matches($eng, "id='([a-z0-9-]+)'[^}]*icon") | ForEach-Object { $_.Groups[1].Value })
    $j = (Get-Content (Join-Path $root 'src\data\profiles.json') -Raw -Encoding UTF8) | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties.Name) { if ($menu -notcontains $p) { throw "perfil $p sin entrada de menu" } }
}

Check 'ui dictionary ES/EN symmetric' {
    $ui = Get-Content (Join-Path $root 'src\core\ui.ps1') -Raw
    $es = [regex]::Matches($ui, "'([\w.\-]+)'\s*=").ForEach({$_.Groups[1].Value})
    $a = ($ui -split '\$script:ST_ES')[1] -split '\$script:ST_EN'
    $b = (($ui -split '\$script:ST_EN')[1] -split 'function Set-STLang')[0]
    $kEs = @([regex]::Matches($a, "'([\w.\-]+)'\s*=") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $kEn = @([regex]::Matches($b, "'([\w.\-]+)'\s*=") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $diff = Compare-Object $kEs $kEn
    if ($diff) { throw (($diff | ForEach-Object { "$($_.InputObject) ($($_.SideIndicator))" }) -join ', ') }
}

Check 'apps.json valid' {
    $j = (Get-Content (Join-Path $root 'src\data\apps.json') -Raw -Encoding UTF8) | ConvertFrom-Json
    $cats = @($j.categories | ForEach-Object { $_.id })
    foreach ($a in $j.apps) {
        if (-not $a.id -or -not $a.name -or -not $a.winget -or -not $a.cat) { throw "app incompleta: $($a.id)" }
        if ($cats -notcontains $a.cat) { throw "$($a.id): categoria desconocida $($a.cat)" }
    }
    $dups = $j.apps | Group-Object id | Where-Object { $_.Count -gt 1 }
    if ($dups) { throw ($dups | ForEach-Object { $_.Name }) -join ', ' }
}

Check 'detect blocks run with fake hw' {
    $hw = @{ IsLaptop=$false; Battery=$false; BatteryPct=-1; Plugged=$true; HasSSD=$true; HasHDD=$false
             HasNvidia=$false; HasAmd=$false; HasIntelGpu=$true; HasDgpu=$false; Gpu=@(); RamGB=16; Build=22631; Admin=$true }
    foreach ($a in $all) {
        try { $null = (& $a.detect $hw) } catch { throw "$($a.id).detect : $($_.Exception.Message)" }
    }
}

Check 'power plan specs resolve' {
    . (Join-Path $root 'src\catalog\power.ps1')
    foreach ($k in @('spark-ultra','spark-ahorro','spark-equili','spark-rendi','spark-turbo','spark-max')) {
        $spec = Get-STPlanSpec $k $null
        if (-not $spec.Ac -and -not $spec.Dc) { throw "$k spec vacia" }
        foreach ($kv in @($spec.Ac.Keys) + @($spec.Dc.Keys)) {
            if ($kv -notmatch '^[0-9a-fA-F-]{36}\|[0-9a-fA-F-]{36}$') { throw "$k par malformado: $kv" }
        }
    }
}

Write-Host ''
if ($fails.Count) {
    Write-Host "FALLOS: $($fails.Count)" -ForegroundColor Red
    exit 1
}
Write-Host 'todos los tests OK' -ForegroundColor Green
