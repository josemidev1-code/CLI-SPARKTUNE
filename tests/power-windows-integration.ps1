# Prueba real en un runner Windows desechable. No usar en un PC de trabajo.
param([switch]$ShowEvidence)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$Global:STHome = Join-Path $env:RUNNER_TEMP ('sparktune-power-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Global:STHome | Out-Null
. (Join-Path $root 'src\core\engine.ps1')
. (Join-Path $root 'src\catalog\power.ps1')
function Is-STAdmin { return $true }
$original = Get-STActivePowerGuid
if ($ShowEvidence) { Write-Host "Plan original: $original" }
try {
    $created = Install-STPowerPlan -Key 'spark-ahorro'
    if ($ShowEvidence) { Write-Host "Ahorro se activó: $created" }
    if ((Get-STActivePowerGuid) -ne $created) { throw 'El plan creado no esta activo.' }
    $query = Invoke-STPowerCfg @('/query', $created, 'SUB_PROCESSOR', 'PROCTHROTTLEMAX')
    if ($query -notmatch '0x0*50\b') { throw "No aparece 80% como limite del procesador en bateria: $query" }
    Invoke-STPowerCfg @('/setactive', $original) | Out-Null
    if ((Get-STActivePowerGuid) -ne $original) { throw 'No se restauro el plan original.' }
    Remove-STPowerPlans
    $list = Invoke-STPowerCfg @('/list')
    if ($list -match [regex]::Escape($created)) { throw 'El plan de prueba no se elimino.' }
    $laptop = @(Get-PowerCatalogActions | Where-Object id -eq 'power.spark-portatil-max')[0]
    & $laptop.apply $laptop
    $laptopGuid = Get-STPlanGuid 'spark-portatil-max'
    if ((Get-STActivePowerGuid) -ne $laptopGuid) { throw 'El plan Portátil Máximo no está activo.' }
    $query = Invoke-STPowerCfg @('/query', $laptopGuid, 'SUB_PROCESSOR', 'PROCTHROTTLEMAX')
    $indices = @([regex]::Matches($query, '0x[0-9a-fA-F]+') | ForEach-Object { [Convert]::ToInt32($_.Value.Substring(2), 16) })
    if ($indices.Count -lt 2 -or $indices[-2] -ne 100 -or $indices[-1] -ne 80) {
        throw "El plan Portátil Máximo no guardó los límites CA/CC esperados: $query"
    }
    if ($ShowEvidence) {
        Write-Host "Portátil Máximo activo: $laptopGuid"
        Write-Host "Máximo de CPU verificado: $($indices[-2])% enchufado / $($indices[-1])% en batería"
    }
    & $laptop.undo $laptop
    if ((Get-STActivePowerGuid) -ne $original) { throw 'undo del plan Portátil Máximo no restauró el original.' }
    Remove-STPowerPlans
    if ($ShowEvidence) { Write-Host "Plan original restaurado: $(Get-STActivePowerGuid)" }
    # Comprobar todos los valores declarados, tanto enchufado como con batería.
    foreach ($key in @('spark-ultra','spark-ahorro','spark-equili','spark-rendi','spark-turbo','spark-max','spark-portatil-max')) {
        $guid = Install-STPowerPlan -Key $key
        if ((Get-STActivePowerGuid) -ne $guid) { throw "No se activó $key." }
        $spec = Get-STPlanSpec $key $null
        foreach ($pair in @($spec.Ac.Keys | Sort-Object -Unique)) {
            $parts = $pair.Split('|')
            $query = Invoke-STPowerCfg @('/query', $guid, $parts[0], $parts[1])
            $indices = @([regex]::Matches($query, '0x[0-9a-fA-F]+') | ForEach-Object { [Convert]::ToInt32($_.Value.Substring(2), 16) })
            if ($indices.Count -lt 2 -or $indices[-2] -ne $spec.Ac[$pair] -or $indices[-1] -ne $spec.Dc[$pair]) {
                throw "Valores CA/CC incorrectos en $key ${pair}: $query"
            }
        }
        foreach ($pair in @($spec.Dc.Keys | Where-Object { -not $spec.Ac.ContainsKey($_) })) {
            $parts = $pair.Split('|')
            $query = Invoke-STPowerCfg @('/query', $guid, $parts[0], $parts[1])
            $indices = @([regex]::Matches($query, '0x[0-9a-fA-F]+') | ForEach-Object { [Convert]::ToInt32($_.Value.Substring(2), 16) })
            if ($indices.Count -lt 2 -or $indices[-1] -ne $spec.Dc[$pair]) { throw "Valor de batería incorrecto en $key ${pair}: $query" }
        }
        Invoke-STPowerCfg @('/setactive', $original) | Out-Null
        Remove-STPowerPlans
        if ($ShowEvidence) { Write-Host "$key`: valores CA/CC verificados y plan anterior restaurado." }
    }
    Write-Host 'Todos los planes: valores CA/CC comprobados y plan original restaurado en Windows.'
} finally {
    try { Invoke-STPowerCfg @('/setactive', $original) | Out-Null } catch { Write-Warning $_ }
    if (Test-Path $script:STPowerGuidFile) {
        try { Remove-STPowerPlans } catch { Write-Warning $_ }
    }
    Remove-Item -LiteralPath $Global:STHome -Recurse -Force -ErrorAction SilentlyContinue
}
