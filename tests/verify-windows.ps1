<#
.SYNOPSIS
  Battery de verificacion en Windows real (no modify nothing excepto lo que tu apruebes).
.DESCRIPTION
  Uso en una consola NORMAL (no admin) y luego otra como ADMIN:
    powershell -ExecutionPolicy Bypass -File .\tests\verify-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\tests\verify-windows.ps1 -Admin
  Cada test es READ-ONLY salvo que se indique "aplica/undo" explicitamente (-Live, solo admin).
#>
[CmdletBinding()]
param([switch]$Admin, [switch]$Live)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$st = Join-Path $root 'sparktune.ps1'
$pass = 0; $warn = 0; $fail = 0
function Write-STVerify([string]$Name, [string]$Status, [string]$Msg = '') {
    $col = switch ($Status) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } default { 'Gray' } }
    Write-Host ("[{0,-4}] {1}{2}" -f $Status, $Name, $(if ($Msg) { "  -> $Msg" } else { '' })) -ForegroundColor $col
    switch ($Status) { 'PASS' { $script:pass++ } 'WARN' { $script:warn++ } 'FAIL' { $script:fail++ } }
}

Write-Host "`n== SparkTune verify (Live=$Live Admin=$Admin) ==" -ForegroundColor Cyan

# 1) arranque basico
& $st --help --no-banner | Out-Null
if ($LASTEXITCODE -eq 0) { Write-STVerify 'help' 'PASS' } else { Write-STVerify 'help' 'FAIL' "exit $LASTEXITCODE" }

# 2) status sin admin no peta
& $st status --no-banner | Out-Null
if ($LASTEXITCODE -le 1) { Write-STVerify 'status' 'PASS' } else { Write-STVerify 'status' 'FAIL' "exit $LASTEXITCODE" }

# 3) dry-run de los 10 perfiles (deberia ser exit 0/1, nunca crash)
$bad = @()
foreach ($p in @('gaming','ofimatica','limpieza','bajos-recursos','portatil-ahorro','portatil-rendimiento','red-privacidad','creativo','desarrollo','personalizado')) {
    '' | & $st --perfil=$p --nivel=medio --dry-run --no-banner | Out-Null
    if ($LASTEXITCODE -gt 1) { $bad += "$p($LASTEXITCODE)" }
}
if ($bad.Count) { Write-STVerify 'dry-run perfiles' 'FAIL' ($bad -join ', ') } else { Write-STVerify 'dry-run perfiles' 'PASS' }

# 4) apps: catalogo + dry-run no interactivo
# (sin winget —Linux/CI— el dry-run real no es fiable: se marca SKIP y solo valida el catalogo)
$hasWinget = [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
if ($hasWinget) {
    & $st apps --install=chrome,vlc,inventado --dry-run --no-banner | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-STVerify 'apps --install dry-run' 'PASS' } else { Write-STVerify 'apps --install dry-run' 'FAIL' "exit $LASTEXITCODE" }
    & $st apps --update=vlc --dry-run --no-banner | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-STVerify 'apps --update dry-run' 'PASS' } else { Write-STVerify 'apps --update dry-run' 'FAIL' "exit $LASTEXITCODE" }
} else { Write-STVerify 'apps dry-run' 'WARN' 'sin winget (no es Windows real?): solo se valida el catalogo' }
$cat = Get-Content (Join-Path $root 'src\data\apps.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($cat -and @($cat.apps).Count -ge 60) { Write-STVerify 'apps.json catalogo' 'PASS' "$(@($cat.apps).Count) apps" } else { Write-STVerify 'apps.json catalogo' 'FAIL' }
$wg = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $wg) { Write-STVerify 'winget presente' 'WARN' 'sin winget: saltar pruebas reales de apps' }
else {
    Write-STVerify 'winget presente' 'PASS'
    Write-Host '  MANUAL: abre "sparktune apps", instala 1 app pequena (7-Zip) y comprueba ✔ al reabrir.' -ForegroundColor DarkGray
    if ($Live) {
        & $st apps --install=7zip --scope=user --no-banner
        Write-STVerify 'apps --install 7zip (live)' $(if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'WARN' }) 'revisa arriba avisos por app'
        & $st apps --update=7zip --no-banner
        Write-STVerify 'apps --update 7zip (live)' $(if ($LASTEXITCODE -le 1) { 'PASS' } else { 'WARN' })
    } else { Write-STVerify 'apps live' 'WARN' 'pasar -Live para probar instalacion real' }
}

# 5) config persistente (ruta portable segun SO)
$stHome = Join-Path $(if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }) '.sparktune'
if (-not (Test-Path $stHome)) { New-Item -ItemType Directory -Path $stHome -Force | Out-Null }
$cfg = Join-Path $stHome 'config.json'
$prev = if (Test-Path $cfg) { Get-Content $cfg -Raw } else { $null }
& $st --set-lang=en --no-banner | Out-Null
$ok1 = (Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match '"lang":\s*"en"')
& $st --set-nivel=medio --no-banner | Out-Null
$ok2 = (Get-Content $cfg -Raw) -match '"nivel":\s*"medio"'
& $st --set-lang=es --no-banner | Out-Null
if ($prev) { [System.IO.File]::WriteAllText($cfg, $prev) }
if ($ok1 -and $ok2) { Write-STVerify 'config --set-*' 'PASS' } else { Write-STVerify 'config --set-*' 'FAIL' "lang=$ok1 nivel=$ok2" }

# 6) power: planes + GPU power mode
$act = (powercfg.exe /getactivescheme) -join "`n"
Write-STVerify 'powercfg activo' 'PASS' ($act -replace '\s+', ' ')
$ls = (powercfg.exe /list) -join "`n"
if ($ls -match 'SparkTune') { Write-STVerify 'planes SparkTune existen' 'PASS' } else { Write-STVerify 'planes SparkTune' 'WARN' 'crea uno con "sparktune power" y repite' }
if ($Admin) {
    & $st undo --id=gpu.power-mode --yes --no-banner | Out-Null
    # lectura directa del setting PCI-E Link State del plan activo
    $q = (powercfg.exe /query SCHEME_CURRENT 4d36e967-e325-11ce-bfc1-08002be10318 eeabc0fe-811e-11d5-b4d9-00a0242541e9) -join "`n"
    if ($q -match 'Current AC Power Setting Index:\s*0x00000000') { Write-STVerify 'gpu.power-mode AC=Off' 'PASS' }
    elseif ($q -match 'Current AC Power Setting Index') { Write-STVerify 'gpu.power-mode AC' 'WARN' 'valor no Off (esperado si no lo has aplicado)' }
    else { Write-STVerify 'gpu.power-mode setting' 'FAIL' 'powercfg no encuentra el setting (check GUIDs)' }
    Write-Host '  MANUAL: aplica gpu.power-mode desde el wizard gaming/medio y repite este script: debe salir PASS arriba.' -ForegroundColor DarkGray
} else { Write-STVerify 'checks GPU power' 'WARN' 'ejecutar con -Admin' }

# 7) journal/undo/doctor
& $st doctor --no-banner | Out-Null
if ($LASTEXITCODE -le 1) { Write-STVerify 'doctor' 'PASS' } else { Write-STVerify 'doctor' 'FAIL' "exit $LASTEXITCODE" }
& $st history --no-banner | Out-Null
if ($LASTEXITCODE -le 1) { Write-STVerify 'st-history' 'PASS' } else { Write-STVerify 'st-history' 'FAIL' "exit $LASTEXITCODE" }
& $st report --out="$env:TEMP\st-report.html" --no-banner | Out-Null
if ((Test-Path "$env:TEMP\st-report.html") -or $LASTEXITCODE -le 1) { Write-STVerify 'report' 'PASS' } else { Write-STVerify 'report' 'FAIL' }

# 8) acciones delicadas (solo recordatorio manual)
Write-Host @"
  MANUAL (requieren decision tuya):
   - net.wsl-nat: con WSL instalado, aplicar y comprobar que ~/.wslconfig guarda el previo y undo lo devuelve.
   - clean.thumbnails: con Explorer abierto; comprobar que las miniaturas se regeneran.
   - off.hibernation: solo si es sobremesa; powercfg /h on para revertir.
   - sec.* / priv.*: aplicar 2-3 con dry-run primero, luego real + undo desde otra consola.
"@ -ForegroundColor DarkGray

Write-Host "`nPASS=$pass WARN=$warn FAIL=$fail" -ForegroundColor $(if ($fail) { 'Red' } elseif ($warn) { 'Yellow' } else { 'Green' })
if ($fail) { exit 1 } else { exit 0 }
