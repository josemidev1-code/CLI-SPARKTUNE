# Ejecutar únicamente en un runner Windows desechable.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$entry = Join-Path $root 'sparktune.ps1'
. (Join-Path $root 'src\catalog\setup.ps1')
$gameBar = 'Software\Microsoft\GameBar'
$gameMode = 'AutoGameModeEnabled'
$previous = Get-STSetupRegistryValue $gameBar $gameMode
$oldProfile = $env:USERPROFILE
$testProfile = Join-Path $env:RUNNER_TEMP ('sparktune-setup-' + [guid]::NewGuid().ToString('N'))
try {
    $env:USERPROFILE = $testProfile
    Set-STSetupRegistryValue $gameBar $gameMode 0
    & $entry setup --perfil=gaming --plan=ninguno --sin-apps --dry-run
    if ($LASTEXITCODE -ne 0 -or (Get-STSetupRegistryValue $gameBar $gameMode) -ne 0) {
        throw 'La simulación falló o modificó el registro.'
    }
    & $entry setup --perfil=gaming --plan=ninguno --sin-apps --yes
    if ($LASTEXITCODE -ne 0 -or (Get-STSetupRegistryValue $gameBar $gameMode) -ne 1) {
        throw 'El asistente no activó el Modo Juego en Windows.'
    }
    & $entry undo --category=setup --yes
    if ($LASTEXITCODE -ne 0 -or (Get-STSetupRegistryValue $gameBar $gameMode) -ne 0) {
        throw 'El asistente no restauró el valor previo del Modo Juego.'
    }
    $entries = (Get-Content -LiteralPath (Join-Path $testProfile '.sparktune\journal.json') -Raw | ConvertFrom-Json).entries
    if (@($entries | Where-Object status -eq 'failed').Count -or @($entries | Where-Object status -eq 'undo').Count -ne 2) {
        throw 'El historial no refleja los dos ajustes restaurados.'
    }
    Write-Host 'Simulación, aplicación y undo del registro: OK'
} finally {
    Set-STSetupRegistryValue $gameBar $gameMode $previous
    $env:USERPROFILE = $oldProfile
    if (Test-Path -LiteralPath $testProfile) { Remove-Item -LiteralPath $testProfile -Recurse -Force }
}
