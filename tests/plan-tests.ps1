$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src/core/setup.ps1')
$cli = Join-Path $root 'sparktune.ps1'
$directory = Join-Path ([IO.Path]::GetTempPath()) ("sparktune-tests-" + [guid]::NewGuid())
$planPath = Join-Path $directory 'Preparación del portátil.json'
$fixture = '{"version":1,"perfil":"desarrollo","apps":["git"],"ajustes":[],"energia":"ninguno","manual":false}'

function Assert-Rejected([string]$Name, [string]$Path) {
    try {
        Read-STSetupPlan $Path | Out-Null
    } catch {
        Write-Host "  OK  $Name"
        return
    }
    throw "Se aceptó un plan inválido ($Name)."
}

New-Item -Path $directory -ItemType Directory | Out-Null
try {
    $invalid = [ordered]@{
        'archivo vacío' = ''
        'JSON incompleto' = '{'
        'objeto nulo' = 'null'
        'objeto envuelto en lista' = "[$fixture]"
        'campo adicional' = $fixture.Replace('"manual":false', '"manual":false,"comando":"powercfg"')
        'nombre de campo con mayúsculas' = $fixture.Replace('"perfil"', '"Perfil"')
        'versión ausente' = $fixture.Replace('"version":1,', '')
        'versión futura' = $fixture.Replace('"version":1', '"version":2')
        'versión como texto' = $fixture.Replace('"version":1', '"version":"1"')
        'confirmación manual como texto' = $fixture.Replace('"manual":false', '"manual":"false"')
        'perfil con salto de línea' = $fixture.Replace('"desarrollo"', '"desarrollo\n"')
        'energía vacía' = $fixture.Replace('"ninguno"', '""')
        'apps como valor escalar' = $fixture.Replace('["git"]', '"git"')
        'ajustes nulos' = $fixture.Replace('"ajustes":[]', '"ajustes":null')
        'ID numérico' = $fixture.Replace('["git"]', '[7]')
        'ID de ajuste con salto de línea' = $fixture.Replace('"ajustes":[]', '"ajustes":["setup.file-extensions\n"]')
        'ID de app duplicado' = $fixture.Replace('["git"]', '["git","git"]')
        'archivo mayor de 64 KB' = $fixture.PadRight(65537)
    }
    Assert-Rejected 'archivo inexistente' $planPath
    Assert-Rejected 'ruta de un directorio' $directory
    foreach ($case in $invalid.GetEnumerator()) {
        [IO.File]::WriteAllText($planPath, $case.Value)
        Assert-Rejected $case.Key $planPath
    }

    $savedPath = Join-Path $directory 'Plan compartido.json'
    & $cli setup --perfil=desarrollo --plan=ninguno --sin-ajustes "--guardar-plan=$savedPath" --no-banner
    if ($LASTEXITCODE -ne 0) { throw "No se pudo exportar el plan (código $LASTEXITCODE)." }
    $plan = Read-STSetupPlan $savedPath
    if ($plan.perfil -cne 'desarrollo' -or ($plan.apps -join ',') -cne 'vscode,git,node-lts,python,7zip' -or
        $plan.energia -cne 'ninguno' -or $plan.ajustes.Count -ne 0 -or $plan.manual) {
        throw 'El plan exportado no conserva la selección y el orden de las apps.'
    }
    Write-Host '  OK  exportación con espacios y orden de apps'

    $original = [IO.File]::ReadAllText($savedPath)
    & $cli setup --perfil=gaming "--guardar-plan=$savedPath" --no-banner
    if ($LASTEXITCODE -ne 1 -or [IO.File]::ReadAllText($savedPath) -cne $original -or
        @(Get-ChildItem -LiteralPath $directory -Force -Filter '*.tmp').Count) {
        throw 'Exportar sobre un archivo existente debe fallar y conservar el original sin dejar archivos temporales.'
    }
    Write-Host '  OK  protección contra sobrescritura'

    & $cli validar "--cargar-plan=$savedPath"
    if ($LASTEXITCODE -ne 0) { throw "La validación de un plan exportado falló (código $LASTEXITCODE)." }
    Write-Host '  OK  validación del plan exportado'

    & $cli setup "--cargar-plan=$savedPath" --dry-run
    if ($LASTEXITCODE -ne 0) { throw "La simulación de un plan exportado falló (código $LASTEXITCODE)." }
    Write-Host '  OK  simulación del plan exportado'

    [IO.File]::WriteAllText($planPath, $fixture.Replace('"git"', '"spark-app-inexistente"'))
    & $cli validar "--cargar-plan=$planPath"
    if ($LASTEXITCODE -ne 3) { throw "Una app fuera del catálogo debe producir el código 3 (obtenido $LASTEXITCODE)." }
    Write-Host '  OK  rechazo de una app fuera del catálogo'

    [IO.File]::WriteAllText($planPath, "[$fixture]")
    & $cli setup "--cargar-plan=$planPath" --dry-run
    if ($LASTEXITCODE -ne 3) { throw "Un plan con formato inválido debe producir el código 3 (obtenido $LASTEXITCODE)." }
    Write-Host '  OK  rechazo de un formato inválido desde setup'
} finally {
    Remove-Item -LiteralPath $directory -Recurse -Force
}
exit 0
