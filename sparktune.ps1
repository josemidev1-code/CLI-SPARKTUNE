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
$Global:STSrc = Join-Path $PSScriptRoot 'src\core'
. (Join-Path $Global:STSrc 'globals.ps1')
. (Join-Path $Global:STSrc 'ui.ps1')
. (Join-Path $Global:STSrc 'banner.ps1')
. (Join-Path $Global:STSrc 'detect.ps1')
. (Join-Path $Global:STSrc 'journal.ps1')
. (Join-Path $Global:STSrc 'engine.ps1')
. (Join-Path $Global:STSrc 'catalog.ps1')

# ---- parseo manual de flags (compatible CMD + PS5.1) ----
$cmd = ''
$optPerfil = ''; $optNivel = ''; $optLang = ''; $optId = ''
$flagYes = $false; $flagDry = $false; $flagNoBanner = $false; $flagHelp = $false
foreach ($a in $RawArgs) {
    $low = "$a".ToLowerInvariant()
    $matched = $false
    switch -Regex ($low) {
        '^(--yes|-y)$'            { $flagYes = $true; $matched = $true; continue }
        '^(--dry-run|-n|--dryrun)$' { $flagDry = $true; $matched = $true; continue }
        '^(--no-banner|--nobanner)$' { $flagNoBanner = $true; $matched = $true; continue }
        '^(--help|-h|/help|/\?)$' { $flagHelp = $true; $matched = $true; continue }
        '^(--lang=.+)$' { $optLang = ($a -split '=', 2)[1]; $matched = $true; continue }
        '^(--perfil=.+|--profile=.+)$' { $optPerfil = ($a -split '=', 2)[1]; $matched = $true; continue }
        '^(--nivel=.+|--level=.+)$' { $optNivel = ($a -split '=', 2)[1]; $matched = $true; continue }
        '^(--id=.+)$' { $optId = ($a -split '=', 2)[1]; $matched = $true; continue }
        '^(--perfil|--profile)$' { Write-STWarn ("usa --perfil=valor"); $flagHelp = $true; $matched = $true; continue }
        '^(--nivel|--level)$' { Write-STWarn ("usa --nivel=valor"); $flagHelp = $true; $matched = $true; continue }
    }
    if ($matched) { continue }
    if ($low -in @('status','battery','power','undo','analyze','history','help')) { $cmd = $low; continue }
    if (-not $cmd -and -not $a.StartsWith('-')) { $cmd = $low; continue }
    if ($a.StartsWith('-')) { Write-STWarn ("flag desconocido: $a") }
}
if ($optLang -eq 'en' -or $optLang -eq 'es') { $Global:STLang = $optLang }
Set-STLang $Global:STLang
$Global:STDryRun = $flagDry

if ($flagHelp) { Show-STHelp; exit 0 }

try {
    switch ($cmd) {
        ''          { Start-STWizard -NoBanner:$flagNoBanner -Yes:$flagYes -Perfil:$optPerfil -Nivel:$optNivel }
        'status'    { Show-STStatus }
        'battery'   { Show-STBatteryReport }
        'power'     { Invoke-STPowerMenu }
        'undo'      { Invoke-STUndo -Id:$optId -Yes:$flagYes }
        'analyze'   { Invoke-STAnalyze }
        'history'   { Show-STHistory }
        'help'      { Show-STHelp }
        default     { Write-STErr ("comando desconocido: $cmd"); Show-STHelp; exit 1 }
    }
} catch {
    Write-STErr $_.Exception.Message
    if ($Global:STVerboseErr) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    exit 1
}
