$ErrorActionPreference = 'Stop'
$cli = Join-Path (Split-Path -Parent $PSScriptRoot) 'sparktune.ps1'
$hostPath = (Get-Process -Id $PID).Path

function Assert-CLI([string[]]$Arguments, [int]$Code, [string[]]$Expected) {
    $output = & $hostPath -NoProfile -File $cli @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne $Code) {
        throw "Exit $LASTEXITCODE, se esperaba $Code con $Arguments. $output"
    }
    foreach ($line in $Expected) {
        if (-not $output.Contains($line)) { throw "Falta '$line' en la salida de $Arguments. $output" }
    }
    Write-Host "OK $Arguments"
}

Assert-CLI @('ayuda','--lang=es') 0 @('SparkTune prepara y optimiza', 'punto de restauraci', 'sparktune optimizar', 'sparktune energia', 'sparktune --set-lang=en')
Assert-CLI @('--no-banner','--lang=es') 0 @('SparkTune prepara y optimiza', 'sparktune preparar')
Assert-CLI @('help','--lang=en') 0 @('SparkTune sets up and tunes', 'Windows restore point', 'sparktune setup', 'sparktune --set-lang=es')
Assert-CLI @('ayuda','preparar','--lang=es') 0 @('sparktune preparar desarrollo --simular', '--guardar-plan=plan.json')
Assert-CLI @('setup','--help','--lang=en') 0 @('sparktune setup desarrollo --dry-run', '--save-plan=plan.json')
Assert-CLI @('preparar','--ayuda','--lang=es') 0 @('sparktune preparar desarrollo --simular')
Assert-CLI @('preparar','desarrollo','--simular') 0 @('Visual Studio Code','Git.Git')
Assert-CLI @('setup','--perfil=desarrollo','--dry-run') 0 @('Visual Studio Code','Git.Git')
Assert-CLI @('preparar','desarrollo','--perfil=gaming','--simular') 2 @('sparktune ayuda preparar')
Assert-CLI @('energua') 2 @('sparktune ayuda')
Assert-CLI @('ayuda','energua') 2 @('sparktune ayuda')
Assert-CLI @('optimizar','--perfil=gaming','--nivel=medio','--simular','--no-banner') 0 @()
