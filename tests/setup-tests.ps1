$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\core\globals.ps1')
. (Join-Path $root 'src\core\catalog.ps1')
. (Join-Path $root 'src\core\engine.ps1')
. (Join-Path $root 'src\core\ui.ps1')
. (Join-Path $root 'src\core\setup.ps1')

$mock = @{ Laptop = $true; Apps = @(); Adjustments = @(); Lines = @() }
function Get-STHardware { return @{ IsLaptop=$mock.Laptop; Battery=$mock.Laptop; Build=22631 } }
function Write-STLine($m, $color, $style) { $mock.Lines += $m }
function Write-STInfo($m) { $mock.Lines += $m }
function Write-STWarn($m) { $mock.Lines += $m }
function Write-STErr($m) { $mock.Lines += $m }
function Write-STOk($m) { $mock.Lines += $m }
function T($key) { return $key }
function STField($a, $field) { return $a[$field] }
function Test-STWinget { return $true }
function Install-STWingetApp($App, $Source, [bool]$Interactive) {
    if ($Source -ne 'winget') { throw 'El instalador debe usar la fuente winget.' }
    $mock.Apps += $App.id
    if ($App.id -eq 'git') { return 'fail' }
    return 'ok'
}
function Invoke-STApply($Action, [bool]$Yes) {
    if (-not $Yes) { throw 'Se perdio --yes.' }
    $mock.Adjustments += $Action.id
    return 'ok'
}

$Global:STDryRun = $true
foreach ($profile in @('desarrollo','video-adobe','video-libre','gaming','ofimatica')) {
    if ((Invoke-STSetup -Perfil $profile) -ne 0) { throw "Fallo simulando el perfil $profile" }
}
if ($mock.Apps.Count -or $mock.Adjustments.Count) { throw 'La simulacion produjo cambios.' }
if (($mock.Lines -join ' ') -notmatch 'Premiere Pro.*https://helpx\.adobe\.com' -or
    ($mock.Lines -join ' ') -notmatch 'spark-portatil-max') { throw 'Falta la propuesta Adobe o el plan para portatil.' }

$Global:STDryRun = $false
if ((Invoke-STSetup -Perfil 'desarrollo' -Yes) -ne 1) { throw 'Se perdio el fallo de instalacion de Git.' }
if (($mock.Apps -join ',') -ne 'vscode,git,node-lts,python,7zip') { throw 'Paquetes de programacion incorrectos.' }
if (($mock.Adjustments -join ',') -ne 'setup.start-suggestions,power.spark-equili') { throw 'Ajustes de programacion incorrectos.' }

$mock.Laptop = $false
if ((Invoke-STSetup -Perfil 'gaming' -Plan 'spark-portatil-max' -Yes) -ne 2) { throw 'No rechazo el plan exclusivo de portatil.' }

$mock.Adjustments = @()
if ((Invoke-STSetup -Perfil 'gaming' -Plan 'ninguno' -SkipApps -Yes) -ne 0 -or
    ($mock.Adjustments -join ',') -ne 'setup.game-mode,setup.start-suggestions') { throw 'No respeto --sin-apps o --plan=ninguno.' }
Write-Host 'Perfiles, simulacion y despacho de setup: OK'
