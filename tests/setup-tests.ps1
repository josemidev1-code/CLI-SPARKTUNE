$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\core\globals.ps1')
. (Join-Path $root 'src\core\catalog.ps1')
. (Join-Path $root 'src\core\engine.ps1')
. (Join-Path $root 'src\core\ui.ps1')
. (Join-Path $root 'src\core\setup.ps1')

$mock = @{ Laptop = $true; Apps = @(); Adjustments = @(); Lines = @(); MenuChoices = @() }
function Get-STHardware { return @{ IsLaptop=$mock.Laptop; Battery=$mock.Laptop; Build=22631 } }
function Write-STLine($m, $color, $style) { $mock.Lines += $m }
function Write-STInfo($m) { $mock.Lines += $m }
function Write-STWarn($m) { $mock.Lines += $m }
function Write-STErr($m) { $mock.Lines += $m }
function Write-STOk($m) { $mock.Lines += $m }
function T($key) { return $key }
function STField($a, $field) { return $a[$field] }
function Show-STMenu([string]$Title, [array]$Items) {
    $choice, $mock.MenuChoices = $mock.MenuChoices
    if ($choice -eq 'esc') { return -1 }
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Items[$i].id -eq $choice) { return $i }
    }
    throw "No aparece la opción $choice en $Title."
}
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
$profiles = Get-Content -LiteralPath (Join-Path $Global:STData 'setup-profiles.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$groups = @(Get-STSetupGroups $profiles)
foreach ($profile in $profiles.PSObject.Properties) {
    if (@($groups.profiles | Where-Object { $_.id -eq $profile.Name }).Count -ne 1) { throw "Perfil sin grupo único: $($profile.Name)." }
    foreach ($isLaptop in @($true, $false)) {
        $mock.Laptop = $isLaptop
        if ((Invoke-STSetup -Perfil $profile.Name) -ne 0) { throw "Fallo simulando $($profile.Name), portátil: $isLaptop" }
    }
}
$mock.MenuChoices = @('creacion','esc','trabajo','estudios')
if ((Read-STSetupProfile -Groups $groups -OfferAI $true) -ne 'estudios') { throw 'No se pudo volver y elegir otro grupo.' }
$mock.MenuChoices = @('_ai')
if ((Read-STSetupProfile -Groups $groups -OfferAI $true) -ne '_ai') { throw 'Falta el acceso a la IA en el selector.' }
$mock.MenuChoices = @('esc')
if (Read-STSetupProfile -Groups $groups -OfferAI $false) { throw 'Escape debe cerrar el selector.' }
if ($mock.Apps.Count -or $mock.Adjustments.Count) { throw 'La simulacion produjo cambios.' }
if (($mock.Lines -join ' ') -notmatch 'Premiere Pro.*https://helpx\.adobe\.com' -or
    ($mock.Lines -join ' ') -notmatch 'spark-portatil-max') { throw 'Falta la propuesta Adobe o el plan para portatil.' }

$Global:STDryRun = $false
$mock.Laptop = $true
if ((Invoke-STSetup -Perfil 'desarrollo' -Yes) -ne 1) { throw 'Se perdio el fallo de instalacion de Git.' }
if (($mock.Apps -join ',') -ne 'vscode,git,node-lts,python,7zip') { throw 'Paquetes de programacion incorrectos.' }
if (($mock.Adjustments -join ',') -ne 'setup.start-suggestions,setup.file-extensions,power.spark-equili') { throw 'Ajustes de programacion incorrectos.' }

$mock.Laptop = $false
if ((Invoke-STSetup -Perfil 'gaming' -Plan 'spark-portatil-max' -Yes) -ne 2) { throw 'No rechazo el plan exclusivo de portatil.' }

$mock.Adjustments = @()
if ((Invoke-STSetup -Perfil 'gaming' -Plan 'ninguno' -SkipApps -Yes) -ne 0 -or
    ($mock.Adjustments -join ',') -ne 'setup.game-mode,setup.start-suggestions') { throw 'No respeto --sin-apps o --plan=ninguno.' }
Write-Host 'Perfiles, simulacion y despacho de setup: OK'
