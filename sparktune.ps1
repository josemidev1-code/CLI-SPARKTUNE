<#
.SYNOPSIS
  SparkTune — CLI de optimizacion de Windows. by @josemidev1
.DESCRIPTION
  Punto de entrada. Enruta comandos y flags. PowerShell 5.1+.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RawArgs = @()
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Global:STVerboseErr = ($env:SPARKTUNE_DEBUG -eq '1')
$Global:STReportOut = ''
$Global:STConfigPath = $null
$Global:STSrc = Join-Path $PSScriptRoot 'src\core'
. (Join-Path $Global:STSrc 'globals.ps1')
. (Join-Path $Global:STSrc 'ui.ps1')
. (Join-Path $Global:STSrc 'banner.ps1')
. (Join-Path $Global:STSrc 'detect.ps1')
. (Join-Path $Global:STSrc 'journal.ps1')
. (Join-Path $Global:STSrc 'engine.ps1')
. (Join-Path $Global:STSrc 'catalog.ps1')
. (Join-Path $Global:STSrc 'ai.ps1')
. (Join-Path $Global:STSrc 'setup.ps1')

# ---- parseo manual de flags (compatible CMD + PS5.1) ----
$cmd = ''
$words = @()
$aliases = @{
    ayuda = 'help'; preparar = 'setup'; optimizar = 'wizard'; energia = 'power'; energía = 'power'
    bateria = 'battery'; batería = 'battery'; estado = 'status'; espacio = 'analyze'
    historial = 'history'; deshacer = 'undo'; ia = 'ai'; informe = 'report'
}
$commands = 'setup','wizard','version','validar','acciones','ejecutar','banner','status','battery','power','undo','analyze','history','apps','doctor','report','ai','help'
$optPerfil = ''; $optNivel = ''; $optLang = ''; $optId = ''; $optCat = ''
$setLang = ''; $setBanner = ''; $setNivel = ''
$appsInstall = ''; $appsUpdate = ''; $appsScope = ''; $appsInteractive = $false
$aiGoal = ''; $aiGoalSpecified = $false
$setupPlan = ''; $saveSetupPath = ''; $loadSetupPath = ''; $skipApps = $false; $skipTweaks = $false
$flagJson = $false; $flagYes = $false; $flagDry = $false; $flagNoBanner = $false; $flagHelp = $false
foreach ($a in $RawArgs) {
    $low = "$a".ToLowerInvariant()
    $matched = $false
    switch -Regex ($low) {
        '^(--yes|-y)$'            { $flagYes = $true; $matched = $true; continue }
        '^(--dry-run|-n|--dryrun|--simular)$' { $flagDry = $true; $matched = $true; continue }
        '^(--no-banner|--nobanner)$' { $flagNoBanner = $true; $matched = $true; continue }
        '^--json$'              { $flagJson = $true; $matched = $true; continue }
        '^--version$'           { $cmd = 'version'; $matched = $true; continue }
        '^(--help|--ayuda|-h|/help|/\?)$' { $flagHelp = $true; $matched = $true; continue }
        '^(--lang=.+)$' { $optLang = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--set-lang=.+)$' { $setLang = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--set-banner=(0|1|on|off|true|false))$' { $setBanner = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--set-nivel=.+|--set-level=.+)$' { $setNivel = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--perfil=.+|--profile=.+)$' { $optPerfil = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--nivel=.+|--level=.+)$' { $optNivel = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--id=.+)$' { $optId = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--category=.+|--cat=.+)$' { $optCat = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--objetivo|--goal)=.*$' { $aiGoal = $a.Substring($a.IndexOf('=') + 1); $aiGoalSpecified = $true; $matched = $true; continue }
        '^--plan=.+$' { $setupPlan = $a.Substring($a.IndexOf('=') + 1).ToLowerInvariant(); $matched = $true; continue }
        '^--(guardar-plan|save-plan)=.+$' { $saveSetupPath = $a.Substring($a.IndexOf('=') + 1); $matched = $true; continue }
        '^--(cargar-plan|load-plan)=.+$' { $loadSetupPath = $a.Substring($a.IndexOf('=') + 1); $matched = $true; continue }
        '^--sin-apps$' { $skipApps = $true; $matched = $true; continue }
        '^--sin-ajustes$' { $skipTweaks = $true; $matched = $true; continue }
        '^(--out=.+)$' { $Global:STReportOut = ($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--install=.+)$' { $appsInstall = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--update=.+)$' { $appsUpdate = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--scope=.+)$' { $appsScope = $($a.Substring($a.IndexOf('=') + 1)); $matched = $true; continue }
        '^(--interactive)$' { $appsInteractive = $true; $matched = $true; continue }
        '^(--perfil|--profile)$' { Write-STWarn ("usa --perfil=valor"); $flagHelp = $true; $matched = $true; continue }
        '^(--nivel|--level)$' { Write-STWarn ("usa --nivel=valor"); $flagHelp = $true; $matched = $true; continue }
    }
    if ($matched) { continue }
    if ($a.StartsWith('-')) {
        Write-STErr "Opción desconocida: $a. Consulta sparktune ayuda."
        exit 2
    }
    $words += $a
}
if ($optLang -eq 'en' -or $optLang -eq 'es') { $Global:STLang = $optLang }
Set-STLang $Global:STLang

if ($words.Count) {
    $name = $words[0]
    if ($cmd) {
        Write-STErr 'Indica un solo comando. Consulta sparktune ayuda.'
        exit 2
    }
    $cmd = if ($aliases.ContainsKey($name)) { $aliases[$name] } else { $name.ToLowerInvariant() }
}
if ($cmd -and $cmd -notin $commands) {
    Write-STErr "Comando desconocido: $name. Consulta sparktune ayuda."
    exit 2
}
if ($cmd -eq 'help' -or $flagHelp) {
    if ($cmd -eq 'help' -and $words.Count -gt 2) {
        Write-STErr 'Usa sparktune ayuda o sparktune ayuda preparar.'
        exit 2
    }
    $topic = if ($cmd -ne 'help') { $cmd } elseif ($words.Count -eq 2) { $words[1] }
    if ($topic -and $aliases.ContainsKey($topic)) { $topic = $aliases[$topic] }
    if ($topic -and $topic -notin $commands) {
        Write-STErr "Comando desconocido: $topic. Consulta sparktune ayuda."
        exit 2
    }
    Show-STHelp -Topic $topic
    exit 0
}
if ($words.Count -gt 1) {
    if ($words.Count -eq 2 -and $cmd -eq 'setup' -and -not $optPerfil) {
        $optPerfil = $words[1]
    } elseif ($words.Count -eq 2 -and $cmd -eq 'ai' -and -not $aiGoalSpecified) {
        $aiGoal = $words[1]
        $aiGoalSpecified = $true
    } else {
        Write-STErr "Argumentos inesperados. Consulta sparktune ayuda $name."
        exit 2
    }
}

# Algunos comandos escriben fuera del motor; no aceptar una simulacion que no pueden respetar.
if ($flagDry -and (($setLang -or $setBanner -or $setNivel) -or $cmd -in @('power','report','battery'))) {
    Write-STErr '--dry-run no esta disponible para este comando o cambio de configuracion; no se ha ejecutado.'
    exit 2
}

# config persistente: --set-lang / --set-banner / --set-nivel
if ($setLang -or $setBanner -or $setNivel) {
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { [Environment]::GetFolderPath('UserProfile') }
    $stHome = Join-Path $homeDir '.sparktune'
    if (-not (Test-Path $stHome)) { New-Item -ItemType Directory -Path $stHome -Force | Out-Null }
    $cfgPath = if ($Global:STConfigPath) { $Global:STConfigPath } else { Join-Path $stHome 'config.json' }
    $cfg = @{}
    if (Test-Path $cfgPath) {
        try { $c = (Get-Content $cfgPath -Raw -Encoding UTF8) | ConvertFrom-Json; foreach ($p in $c.PSObject.Properties) { $cfg[$p.Name] = $p.Value } } catch { }
    }
    if ($setLang -eq 'en' -or $setLang -eq 'es') { $cfg['lang'] = $setLang }
    if ($setBanner) {
        $b = "$setBanner".ToLowerInvariant()
        $cfg['banner'] = ($b -in @('1','on','true'))
    }
    if ($setNivel -in @('suave','medio','agresivo')) { $cfg['nivel'] = $setNivel }
    $json = ConvertTo-Json $cfg
    [System.IO.File]::WriteAllText($cfgPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-STOk "config guardada: $cfgPath"
    exit 0
}

$Global:STDryRun = $flagDry
if (-not $cmd -and ($optPerfil -or $optNivel -or $flagDry -or $flagYes)) { $cmd = 'wizard' }

if ($cmd -ne 'setup' -and ($setupPlan -or $skipApps -or $skipTweaks -or $saveSetupPath -or ($loadSetupPath -and $cmd -ne 'validar'))) {
    Write-STErr 'Las opciones de plan y selección se usan con sparktune preparar.'
    exit 2
}

if ($cmd -eq 'setup' -and ($optNivel -or $optId -or $optCat -or $appsInstall -or $appsUpdate -or $appsScope -or $Global:STReportOut)) {
    Write-STErr 'Consulta sparktune ayuda preparar para ver sus opciones.'
    exit 2
}

if ($cmd -eq 'setup' -and $aiGoalSpecified -and ($flagYes -or $optPerfil -or $setupPlan -or -not $aiGoal.Trim())) {
    Write-STErr 'En setup, usa --objetivo con texto y sin --perfil, --plan ni --yes.'
    exit 2
}

if ($saveSetupPath -and ($loadSetupPath -or $flagDry -or $flagYes -or $appsInteractive -or -not ($optPerfil -or $aiGoalSpecified))) {
    Write-STErr '--guardar-plan requiere un perfil u objetivo y solo exporta el JSON.'
    exit 2
}
if ($loadSetupPath -and ($optPerfil -or $aiGoalSpecified -or $setupPlan)) {
    Write-STErr '--cargar-plan ya indica el perfil y el plan de energía.'
    exit 2
}

if ($cmd -eq 'validar' -and ($flagYes -or $appsInteractive -or $optPerfil -or $aiGoalSpecified)) {
    Write-STErr 'Usa sparktune validar o sparktune validar --cargar-plan=archivo.json.'
    exit 2
}
if ($flagJson -and $cmd -ne 'acciones') {
    Write-STErr '--json se utiliza con el comando acciones.'
    exit 2
}
if ($cmd -eq 'ejecutar' -and -not $optId) {
    Write-STErr 'Usa sparktune ejecutar --id=setup.nombre [--dry-run|--yes].'
    exit 2
}

try {
    switch ($cmd) {
        ''          {
            if ($script:STConsole -and $Global:STBanner -and -not $flagNoBanner) { Show-STBanner }
            Show-STHelp
            exit 0
        }
        'wizard'   { Start-STWizard -NoBanner:$flagNoBanner -Yes:$flagYes -Perfil:$optPerfil -Nivel:$optNivel }

        'version'   { Write-Output $Global:STVersion; exit 0 }
        'validar'   {
            if ($loadSetupPath) { exit (Invoke-STSetup -LoadPath $loadSetupPath -ValidateOnly) }
            exit (Invoke-STActionCatalog -ValidateOnly)
        }
        'acciones'  {
            if ($flagJson) {
                $catalogJson = Invoke-STActionCatalog -Json
                if ($catalogJson -is [int]) { exit $catalogJson }
                Write-Output $catalogJson
                exit 0
            }
            exit (Invoke-STActionCatalog)
        }
        'ejecutar'  { exit (Invoke-STActionCatalog -Id $optId -Yes:$flagYes) }
        'banner'    { Show-STBanner -NoBanner:$flagNoBanner }
        'setup'     {
            if ($script:STConsole -and -not ($flagDry -or $flagYes -or $flagNoBanner) -and $Global:STBanner) {
                Show-STBanner
            }
            if ($flagDry -and $aiGoalSpecified) {
                Invoke-STSetup -Goal $aiGoal -SkipApps:$skipApps -SkipTweaks:$skipTweaks
                exit 0
            }
            exit (Invoke-STSetup -Perfil $optPerfil -Plan $setupPlan -Goal $aiGoal -SkipApps:$skipApps -SkipTweaks:$skipTweaks -Interactive:$appsInteractive -Yes:$flagYes -SavePath $saveSetupPath -LoadPath $loadSetupPath)
        }
        'status'    { Show-STStatus }
        'battery'   { Show-STBatteryReport }
        'power'     { Invoke-STPowerMenu }
        'undo'      { Invoke-STUndo -Id:$optId -Category:$optCat -Yes:$flagYes }
        'analyze'   { Invoke-STAnalyze }
        'history'   { Show-STHistory }
        'apps'     {
            if ($appsInstall -and $appsUpdate) { Write-STErr 'apps: usa --install o --update, no ambos'; exit 1 }
            if ($appsInstall) { Invoke-STAppsInstall -List $appsInstall -Scope $appsScope -Interactive $appsInteractive; exit 0 }
            elseif ($appsUpdate) { Invoke-STAppsInstall -List $appsUpdate -Scope $appsScope -Interactive $appsInteractive -Mode update; exit 0 }
            elseif ($appsScope -or $appsInteractive) { Write-STErr 'apps: --scope/--interactive requieren --install=lista o --update=lista'; exit 1 }
            else { Invoke-STAppsMenu }
        }
        'doctor'   { Invoke-STDoctor }
        'report'   { Show-STReport -Out $Global:STReportOut }
        'ai'        {
            Invoke-STAIAdvisor -Goal $aiGoal -Perfil $optPerfil -Nivel $optNivel -DryRun:$flagDry
            exit 0
        }
    }
} catch {
    Write-STErr $_.Exception.Message
    if ($Global:STVerboseErr) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    exit 1
}
