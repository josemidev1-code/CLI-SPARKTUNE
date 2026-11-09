# SparkTune catalog.ps1 — agrega modulos del catalogo y resuelve perfiles/niveles.

$script:STCatalog = $null

function Load-STCatalog {
    if ($script:STCatalog) { return }
    $all = @()
    $getters = @('Get-CleanupCatalogActions','Get-MemoryCatalogActions','Get-CpuCatalogActions',
                 'Get-GpuCatalogActions','Get-NetworkCatalogActions','Get-PrivacyCatalogActions',
                 'Get-SecurityCatalogActions',
                 'Get-OfficeCatalogActions','Get-UpdatesCatalogActions','Get-PowerCatalogActions',
                 'Get-LaptopCatalogActions')
    foreach ($m in (Get-ChildItem -Path $Global:STCatalogDir -Filter '*.ps1' | Sort-Object Name)) {
        . $m.FullName.ToString()
    }
    foreach ($g in $getters) {
        if (Get-Command $g -ErrorAction SilentlyContinue) {
            try { $all += & $g } catch { Write-STWarn "catalogo $g : $($_.Exception.Message)" }
        }
    }
    # normalizar a hashtable con por lo menos los campos del contrato
    $norm = @()
    foreach ($a in $all) {
        $h = @{}
        foreach ($k in $a.Keys) { $h[$k] = $a[$k] }
        if (-not $h.ContainsKey('perfiles')) { $h.perfiles = @() }
        if (-not $h.ContainsKey('niveles'))  { $h.niveles  = @{ suave=1; medio=1; agresivo=1 } }
        if (-not $h.ContainsKey('needsRP'))  { $h.needsRP  = ($h.riesgo -eq 'alto') }
        $norm += $h
    }
    $script:STCatalog = $norm
}

function Get-STCatalogActions { return @($script:STCatalog) }

function Test-STApplies {
    param($Action, $Hw)
    try {
        if ($Action.ContainsKey('detect') -and $Action.detect) { return [bool](& $Action.detect $Hw) }
    } catch { return $false }
    return $true
}

function Resolve-STProfile {
    param([string]$Perfil, [string]$Nivel, $Hw, [array]$All)
    $profFile = Join-Path $Global:STData 'profiles.json'
    $pconf = $null
    if (Test-Path $profFile) {
        try { $pconf = (Get-Content $profFile -Raw) | ConvertFrom-Json } catch { $pconf = $null }
    }
    $out = @()
    foreach ($a in $All) {
        $inProfile = $false
        if ($pconf -and ($pconf.PSObject.Properties.Name -contains $Perfil)) {
            $lvlObj = $pconf.$Perfil
            if ($lvlObj.PSObject.Properties.Name -contains $Nivel) {
                $ids = @($lvlObj.$Nivel)
                if ($ids -contains '*' -or $ids -contains $a.id) { $inProfile = $true }
            }
        } else {
            # fallback: campos perfiles/niveles de la accion
            if ($a.perfiles -contains $Perfil -and $a.niveles.ContainsKey($Nivel)) { $inProfile = $true }
        }
        if ($inProfile -and (Test-STApplies $a $Hw)) { $out += $a }
    }
    return $out
}
