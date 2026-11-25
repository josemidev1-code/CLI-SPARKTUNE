$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$Global:STHome = Join-Path ([IO.Path]::GetTempPath()) ('sparktune-power-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Global:STHome | Out-Null
. (Join-Path $root 'src\core\engine.ps1')
. (Join-Path $root 'src\catalog\power.ps1')
$script:commands = @()
$script:failSetting = $false
function Invoke-STPowerCfg([string[]]$Args2) {
    $script:commands += ,@($Args2)
    if ($Args2[0] -eq '/getactivescheme') { return 'Power Scheme GUID: 11111111-1111-1111-1111-111111111111' }
    if ($script:failSetting -and $Args2[0] -eq '/setdcvalueindex') { throw 'setting rechazado' }
}
function global:powercfg.exe { return 'Power Scheme GUID: 11111111-1111-1111-1111-111111111111' }
function Is-STAdmin { return $true }
function Get-STPlanGuid([string]$Key) { return '' }
try {
    $spec = Get-STPlanSpec 'spark-ahorro' $null
    Set-STPlanValues -Guid '22222222-2222-2222-2222-222222222222' -Ac $spec.Ac -Dc $spec.Dc
    if (@($script:commands | Where-Object { $_[0] -eq '/setdcvalueindex' -and $_[2] -eq 'SUB_PROCESSOR' -and $_[3] -eq 'PROCTHROTTLEMAX' -and $_[4] -eq '80' }).Count -ne 1) { throw 'no se aplico maximo de bateria' }
    $script:commands = @()
    $script:failSetting = $true
    $failed = $false
    try { Install-STPowerPlan -Key 'spark-ahorro' } catch { $failed = $true }
    if (-not $failed) { throw 'se ignoro un error de powercfg' }
    if (@($script:commands | Where-Object { $_[0] -eq '/delete' }).Count -ne 1) { throw 'plan incompleto no se elimino' }
    if (@($script:commands | Where-Object { $_[0] -eq '/setactive' }).Count -ne 0) { throw 'plan incompleto se activo' }
    if (Test-Path $script:STPowerGuidFile) { throw 'plan incompleto quedo registrado' }
    Write-Host 'Planes de energia simulados: OK'
} finally {
    Remove-Item -LiteralPath $Global:STHome -Recurse -Force
}
