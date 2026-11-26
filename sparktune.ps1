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
$optPerfil = ''; $optNivel = ''; $optLang = ''; $optId = ''; $optCat = ''
$setLang = ''; $setBanner = ''; $setNivel = ''
$appsInstall = ''; $appsUpdate = ''; $appsScope = ''; $appsInteractive = $false
$aiGoal = ''; $aiGoalSpecified = $false
$setupPlan = ''; $skipApps = $false; $skipTweaks = $false
$flagYes = $false; $flagDry = $false; $flagNoBanner = $false; $flagHelp = $false
foreach ($a in $RawArgs) {
    $low = "$a".ToLowerInvariant()
    $matched = $false
    switch -Regex ($low) {
        '^(--yes|-y)$'            { $flagYes = $true; $matched = $true; continue }
        '^(--dry-run|-n|--dryrun)$' { $flagDry = $true; $matched = $true; continue }
        '^(--no-banner|--nobanner)$' { $flagNoBanner = $true; $matched = $true; continue }
        '^(--help|-h|/help|/\?)$' { $flagHelp = $true; $matched = $true; continue }
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
    if ($low -in @('setup','banner','status','battery','power','undo','analyze','history','apps','doctor','report','ai','help')) { $cmd = $low; continue }
    if (-not $cmd -and -not $a.StartsWith('-')) { $cmd = $low; continue }
    Write-STErr ("argumento desconocido: $a")
    exit 2
}
if ($optLang -eq 'en' -or $optLang -eq 'es') { $Global:STLang = $optLang }

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

Set-STLang $Global:STLang
$Global:STDryRun = $flagDry

if ($flagHelp) { Show-STHelp; exit 0 }

if ($cmd -ne 'setup' -and ($setupPlan -or $skipApps -or $skipTweaks)) {
    Write-STErr '--plan, --sin-apps y --sin-ajustes se utilizan con setup.'
    exit 2
}

if ($cmd -eq 'setup' -and ($optNivel -or $optId -or $optCat -or $appsInstall -or $appsUpdate -or $appsScope -or $Global:STReportOut)) {
    Write-STErr 'setup no admite opciones de otros comandos. Consulta sparktune setup --help.'
    exit 2
}

if ($cmd -eq 'setup' -and $aiGoalSpecified -and ($flagYes -or $optPerfil -or $setupPlan -or -not $aiGoal.Trim())) {
    Write-STErr 'En setup, usa --objetivo con texto y sin --perfil, --plan ni --yes.'
    exit 2
}

try {
    switch ($cmd) {
        ''          { Start-STWizard -NoBanner:$flagNoBanner -Yes:$flagYes -Perfil:$optPerfil -Nivel:$optNivel }

        'banner'    { Show-STBanner -NoBanner:$flagNoBanner }
        'setup'     {
            if ($script:STConsole -and -not ($flagDry -or $flagYes -or $flagNoBanner) -and $Global:STBanner) {
                Show-STBanner
            }
            if ($flagDry -and $aiGoalSpecified) {
                Invoke-STSetup -Goal $aiGoal -SkipApps:$skipApps -SkipTweaks:$skipTweaks
                exit 0
            }
            exit (Invoke-STSetup -Perfil $optPerfil -Plan $setupPlan -Goal $aiGoal -SkipApps:$skipApps -SkipTweaks:$skipTweaks -Interactive:$appsInteractive -Yes:$flagYes)
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
        'help'      { Show-STHelp }
        default     { Write-STErr ("comando desconocido: $cmd"); Show-STHelp; exit 1 }
    }
} catch {
    Write-STErr $_.Exception.Message
    if ($Global:STVerboseErr) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    exit 1
}
