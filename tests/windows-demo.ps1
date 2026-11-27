param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'Esta demo se ejecuta en una VM Windows temporal de GitHub Actions.'
}

$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Save-Scene {
    param([string]$Name, [string]$Title, [scriptblock]$Body)
    $file = Join-Path $OutputDirectory "$Name.txt"
    Set-Content -LiteralPath $file -Value $Title -Encoding UTF8
    try {
        & $Body *>&1 | ForEach-Object {
            Add-Content -LiteralPath $file -Value ([string]$_) -Encoding UTF8
            Write-Host $_
        }
    } catch {
        Add-Content -LiteralPath $file -Value "ERROR: $($_.Exception.Message)" -Encoding UTF8
        $script:failed += $Name
        Write-Warning "$($Name): $($_.Exception.Message)"
    }
}

function Invoke-DemoCli {
    "> sparktune $($args -join ' ')"
    & $script:installed @args 6>&1
    if ($LASTEXITCODE -ne 0) { throw "SparkTune devolvió el código $LASTEXITCODE." }
}

$script:failed = @()
$script:installed = Join-Path $env:LOCALAPPDATA 'SparkTune\sparktune.ps1'
Save-Scene '01-instalacion' 'Instalación de SparkTune en Windows' {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    "$($os.Caption) · build $($os.BuildNumber) · Windows PowerShell $($PSVersionTable.PSVersion)"
    '> powershell.exe -NoProfile -File .\install.ps1 -Force'
    & powershell.exe -NoProfile -File (Join-Path $root 'install.ps1') -Force
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $script:installed)) { throw 'La instalación falló.' }
    '> sparktune.cmd --help --no-banner'
    & (Join-Path (Split-Path -Parent $script:installed) 'sparktune.cmd') --help --no-banner
    if ($LASTEXITCODE -ne 0) { throw 'Falló la ayuda desde el lanzador instalado.' }
}

Save-Scene '00-ayuda' 'Guía de comandos en español e inglés' {
    Invoke-DemoCli ayuda --lang=es
    Invoke-DemoCli help --lang=en
    Invoke-DemoCli ayuda preparar --lang=es
}

Save-Scene '02-estado' 'Estado de la VM Windows' {
    Invoke-DemoCli status --no-banner
    Invoke-DemoCli doctor
}

Save-Scene '03-perfiles' 'Perfiles de SparkTune por tipo de uso' {
    Invoke-DemoCli perfiles
}

$profiles = Get-Content -LiteralPath (Join-Path $root 'src/data/setup-profiles.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($profile in $profiles.PSObject.Properties.Name) {
    Save-Scene "03-$profile" "Perfil $profile · simulación de SparkTune" {
        Invoke-DemoCli setup "--perfil=$profile" --dry-run
    }
}

Save-Scene '04-winget' 'WinGet · instalación de una aplicación de prueba' {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        'WinGet no está disponible en esta imagen de Windows.'
        'Comprobación alternativa: simulación de WinGet con el paquete 7-Zip.'
        Invoke-DemoCli apps --install=7zip --dry-run
        return
    }
    & winget.exe --version
    if ($LASTEXITCODE -ne 0) { throw 'WinGet está instalado, pero no se puede ejecutar.' }
    function Test-DemoPackage([string]$Id) {
        $listing = (& winget.exe list --id $Id -e --source winget --accept-source-agreements --disable-interactivity 2>&1) -join "`n"
        return ($LASTEXITCODE -eq 0 -and $listing -match [regex]::Escape($Id))
    }
    $originallyInstalled = Test-DemoPackage '7zip.7zip'
    "7-Zip ya estaba presente antes de probar: $originallyInstalled"
    Invoke-DemoCli apps --install=7zip
    if (-not (Test-DemoPackage '7zip.7zip')) { throw 'WinGet no confirmó 7-Zip.' }

    $candidates = @(
        @{ id = 'vlc'; package = 'VideoLAN.VLC' }
        @{ id = 'notepadpp'; package = 'Notepad++.Notepad++' }
        @{ id = 'audacity'; package = 'Audacity.Audacity' }
    )
    foreach ($candidate in $candidates) {
        if (Test-DemoPackage $candidate.package) { continue }
        "No instalada antes de la prueba: $($candidate.package)"
        try { Invoke-DemoCli apps "--install=$($candidate.id)" }
        catch { Write-Warning $_.Exception.Message; continue }
        "> winget list -e --id $($candidate.package) --source winget"
        & winget.exe list -e --id $candidate.package --source winget --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0 -and (Test-DemoPackage $candidate.package)) {
            'Verificado: WinGet detecta la aplicación recién instalada.'
            return
        }
        Write-Warning "WinGet no confirmó $($candidate.package) tras la instalación."
    }
    throw 'No se pudo verificar una instalación nueva con WinGet.'
}

Save-Scene '05-ajustes-y-undo' 'Cambios de Gaming y restauración · registro real' {
    '> tests/setup-windows-integration.ps1'
    & (Join-Path $PSScriptRoot 'setup-windows-integration.ps1')
}

Save-Scene '06-energia' 'Ahorro y Portátil Máximo · planes reales de Windows' {
    '> tests/power-windows-integration.ps1 -ShowEvidence'
    & (Join-Path $PSScriptRoot 'power-windows-integration.ps1') -ShowEvidence
}

Save-Scene '07-ia-simulada' 'IA por objetivo · respuesta simulada, sin conexión a OpenAI' {
    '> tests/ai-tests.ps1 -ShowSetupExample'
    & (Join-Path $PSScriptRoot 'ai-tests.ps1') -ShowSetupExample
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas de IA.' }
}

Save-Scene '08-analisis' 'Análisis de almacenamiento · solo lectura' {
    Invoke-DemoCli analyze
}

Save-Scene '09-bateria' 'Batería · detección en la máquina virtual' {
    Invoke-DemoCli battery
}

Save-Scene '10-informe' 'Informe de diagnóstico · HTML adjunto' {
    Invoke-DemoCli report "--out=$(Join-Path $OutputDirectory 'diagnostico.html')"
    if (-not (Test-Path -LiteralPath (Join-Path $OutputDirectory 'diagnostico.html'))) {
        throw 'No se generó el informe.'
    }
}

Save-Scene '11-desinstalacion' 'Desinstalación de SparkTune' {
    '> powershell.exe -NoProfile -File .\uninstall.ps1'
    & powershell.exe -NoProfile -File (Join-Path $root 'uninstall.ps1')
    if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $script:installed)) { throw 'La desinstalación falló.' }
    'Verificado: el lanzador instalado se ha retirado.'
}
if ($script:failed.Count) { throw "Escenas con fallos: $($script:failed -join ', ')." }
