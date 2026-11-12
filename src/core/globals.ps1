# SparkTune globals — cargado por sparktune.ps1 antes que nada
$Global:STSrc = $PSScriptRoot                       # .../src/core
$Global:STProjRoot = Split-Path -Parent (Split-Path -Parent $Global:STSrc)   # raiz del repo (contiene sparktune.ps1)
if (-not $Global:STProjRoot -or -not (Test-Path (Join-Path $Global:STProjRoot 'sparktune.ps1'))) {
    # fallback: estructura src/ delante (ej. ejecutado desde src/core o via & .\src\core\globals.ps1)
    $cand = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Global:STSrc))
    if (Test-Path (Join-Path $cand 'sparktune.ps1')) { $Global:STProjRoot = $cand }
}
$Global:STVersion = '1.6.0'
$homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { [Environment]::GetFolderPath('UserProfile') }
$Global:STHome = Join-Path $homeDir '.sparktune'
if (-not (Test-Path $Global:STHome)) { New-Item -ItemType Directory -Path $Global:STHome -Force | Out-Null }
# data/ y catalog/ viven junto a core/ dentro de src/
$Global:STData = Join-Path (Split-Path -Parent $Global:STSrc) 'data'          # .../src/data
$Global:STCatalogDir = Join-Path (Split-Path -Parent $Global:STSrc) 'catalog' # .../src/catalog
$Global:STJournalPath = Join-Path $Global:STHome 'journal.json'
$Global:STConfigPath  = Join-Path $Global:STHome 'config.json'
$Global:STConfig = $null
if (Test-Path $Global:STConfigPath) {
    try { $Global:STConfig = (Get-Content $Global:STConfigPath -Raw -Encoding UTF8) | ConvertFrom-Json } catch { $Global:STConfig = $null }
}
$Global:STLang = 'es'
if ($Global:STConfig -and $Global:STConfig.lang) { $Global:STLang = "$($Global:STConfig.lang)" }
$Global:STBanner = $true
if ($Global:STConfig -and ($Global:STConfig.PSObject.Properties.Name -contains 'banner') -and ($Global:STConfig.banner -eq $false)) { $Global:STBanner = $false }
$Global:STNivelDefault = ''
if ($Global:STConfig -and $Global:STConfig.nivel) { $Global:STNivelDefault = "$($Global:STConfig.nivel)" }
$Global:STDryRun = $false
