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
    New-Item -ItemType Directory -Path $testProfile -Force | Out-Null
    $file = Join-Path $testProfile 'Mi plan.json'
    & $entry setup --perfil=gaming --plan=ninguno --sin-apps "--guardar-plan=$file"
    if ($LASTEXITCODE -ne 0 -or (Get-STSetupRegistryValue $gameBar $gameMode) -ne 0) {
        throw 'Guardar el plan falló o modificó el registro.'
    }
    $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    if ($saved.apps.Count -ne 0 -or $saved.ajustes.Count -ne 2 -or $saved.energia -ne 'ninguno') {
        throw 'El archivo no conserva las opciones elegidas.'
    }
    $version = & $entry --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^\d+\.\d+\.\d+$') { throw 'No se pudo leer la versión desde la CLI.' }
    & $entry validar "--cargar-plan=$file"
    if ($LASTEXITCODE -ne 0 -or (Get-STSetupRegistryValue $gameBar $gameMode) -ne 0) {
        throw 'Validar un plan aplicó cambios o rechazó un archivo válido.'
    }
    $hash = (Get-FileHash -LiteralPath $file).Hash
    & $entry setup --perfil=ofimatica --plan=ninguno --sin-apps "--guardar-plan=$file"
    if ($LASTEXITCODE -eq 0 -or (Get-FileHash -LiteralPath $file).Hash -ne $hash) {
        throw 'Se sobrescribió un plan guardado.'
    }
    $bad = Join-Path $testProfile 'Plan incompatible.json'
    $saved.ajustes += 'priv.tips'
    ConvertTo-Json $saved | Set-Content -LiteralPath $bad -Encoding UTF8
    & $entry validar "--cargar-plan=$bad"
    if ($LASTEXITCODE -ne 3) { throw 'Validar debe devolver 3 para un plan inválido.' }
    & $entry setup "--cargar-plan=$bad" --yes
    if ($LASTEXITCODE -ne 3 -or (Get-STSetupRegistryValue $gameBar $gameMode) -ne 0) {
        throw 'Se aplicaron cambios antes de rechazar un ajuste ajeno al catálogo de setup.'
    }
    & $entry setup "--cargar-plan=$file" --dry-run
    if ($LASTEXITCODE -ne 0 -or (Get-STSetupRegistryValue $gameBar $gameMode) -ne 0) {
        throw 'La simulación falló o modificó el registro.'
    }
    & $entry setup "--cargar-plan=$file" --yes
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
    Write-Host 'Exportación, importación, simulación, aplicación y undo del registro: OK'
} finally {
    Set-STSetupRegistryValue $gameBar $gameMode $previous
    $env:USERPROFILE = $oldProfile
    if (Test-Path -LiteralPath $testProfile) { Remove-Item -LiteralPath $testProfile -Recurse -Force }
}
