# Pruebas aisladas: no modifican configuracion ni servicios de Windows.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\core\engine.ps1')
$Global:STDryRun = $false
$script:applied = 0
$script:undone = 0
$script:journalWrites = 0
$script:typed = 0
function Write-STInfo($m) { }
function Write-STWarn($m) { }
function Write-STErr($m) { }
function Write-STOk($m) { }
function Write-STLine($m, $color, $style) { }
function Write-STProgress($Pct, $Label) { }
function STField($a, $field) { return $a[$field] }
function T($key) { return $key }
function Is-STAdmin { return $true }
function Add-STJournalEntry { $script:journalWrites++ }
function Read-STTypedYes { $script:typed++; return $false }
function Show-STCard($Action) { }
function Get-STJournalPending { if ($Global:STDryRun) { return @([pscustomobject]@{seq='1'; id='test'; titulo='Test'; categoria='test'; reversible=$true}) }; return @() }
function Load-STCatalog { }
function Get-STCatalogActions { return @($script:action) }
function Mark-STJournalUndone($Seq) { $script:journalWrites++ }
$script:action = @{
    id='test'; titulo='Test'; categoria='test'; riesgo='alto'; reversible=$true
    admin=$false; needsRP=$false; preview={ 'antes' }
    apply={ $script:applied++ }; undo={ $script:undone++ }
}
$Global:STDryRun = $true
$result = Invoke-STApply -Action $script:action -Yes $true
if ($result -ne 'dry' -or $script:applied -ne 0 -or $script:journalWrites -ne 0) { throw 'apply dry-run modifico estado' }
Invoke-STUndo -Yes
if ($script:undone -ne 0 -or $script:journalWrites -ne 0) { throw 'undo dry-run modifico estado' }
$Global:STDryRun = $false
$result = Invoke-STApply -Action $script:action -NoConfirm
if ($result -ne 'skip' -or $script:typed -ne 1 -or $script:applied -ne 0) { throw 'riesgo alto no pidio confirmacion individual' }
Write-Host 'Pruebas de seguridad: OK'

# Crear un plan debe pasar GUIDs a /duplicatescheme y nombrarlo despues.
$Global:STHome = [IO.Path]::GetTempPath()
. (Join-Path $root 'src\catalog\power.ps1')
$script:commands = @()
function Invoke-STPowerCfg([string[]]$Args2) { $script:commands += ,@($Args2) }
function Set-STPlanGuid([string]$Key, [string]$Guid) { $script:savedGuid = $Guid }
$created = New-STPowerPlan 'spark-ultra'
$parsed = [guid]::Empty
if ($script:commands.Count -ne 2 -or $script:commands[0][0] -ne '/duplicatescheme' -or
    -not [guid]::TryParse($script:commands[0][1], [ref]$parsed) -or
    -not [guid]::TryParse($script:commands[0][2], [ref]$parsed) -or
    $script:commands[1][0] -ne '/changename' -or $script:commands[1][1] -ne $created -or
    $script:commands[1][2] -ne 'SparkTune Ultra Ahorro') { throw 'creacion de plan powercfg incorrecta' }
Write-Host 'Creacion de plan simulada: OK'

# Un punto antiguo no confirma que Windows haya creado uno nuevo.
$Global:STVersion = 'test'
$script:restoreMode = 'old'
$script:restoreCalls = 0
function Test-STRestoreEnabled { return $true }
function Start-Sleep { param($Seconds) }
function Checkpoint-Computer { param($Description, $RestorePointType) }
function Get-ComputerRestorePoint {
    $script:restoreCalls++
    [pscustomobject]@{ SequenceNumber=1; Description='SparkTune test' }
    if ($script:restoreMode -eq 'new' -and $script:restoreCalls -gt 1) {
        [pscustomobject]@{ SequenceNumber=2; Description='SparkTune test' }
    }
}
if (New-STRestorePoint) { throw 'Un punto anterior no debe contar como nuevo.' }
$script:restoreMode = 'new'; $script:restoreCalls = 0
if (-not (New-STRestorePoint)) { throw 'No se reconoció el punto nuevo.' }
Write-Host 'Verificación de punto de restauración: OK'

# Una acción en revisión ya no se ofrece, pero undo debe seguir deshaciendo lo que se
# aplicó con una versión anterior. Se carga el catálogo real sin globals.ps1 para no
# crear ~/.sparktune, y se sustituye el undo de net.doh para no tocar el equipo.
$Global:STData = Join-Path $root 'src\data'
$Global:STCatalogDir = Join-Path $root 'src\catalog'
. (Join-Path $root 'src\core\catalog.ps1')
Load-STCatalog
$enRevision = @(Get-STCatalogActions | Where-Object { $_.id -eq 'net.doh' })[0]
if (-not $enRevision -or -not $enRevision.enRevision) { throw 'net.doh debe seguir en el catálogo y marcada en revisión.' }
if (Test-STApplies $enRevision @{}) { throw 'Una acción en revisión no debe ofrecerse.' }
$script:undoneIds = @()
$script:markedSeqs = @()
$enRevision.undo = { param($a) $script:undoneIds += $a.id }
function Get-STJournalPending { return @([pscustomobject]@{seq='7'; id='net.doh'; titulo='DoH'; categoria='network'; reversible=$true}) }
function Mark-STJournalUndone($Seq) { $script:markedSeqs += $Seq }
Invoke-STUndo -Id 'net.doh' -Yes
if ($script:undoneIds -notcontains 'net.doh' -or $script:markedSeqs -notcontains '7') {
    throw 'undo no deshizo una acción en revisión aplicada con una versión anterior.'
}
Write-Host 'Undo de una acción en revisión: OK'
