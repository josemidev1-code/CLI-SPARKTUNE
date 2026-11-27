# SparkTune catalog.ps1 — agrega modulos del catalogo y resuelve perfiles/niveles.

$script:STCatalog = $null

# Acciones en revisión: se declaran reversibles, pero su undo no restaura el estado anterior
# real. Escriben un valor fijo (por ejemplo, un servicio vuelve siempre a Auto), borran
# valores que podían existir antes o crean valores que no existían. Siguen en el catálogo
# para que undo pueda deshacer aplicaciones anteriores, pero no se ofrecen en ningún flujo.
# Para sacar una de la lista, su apply debe guardar el estado previo con Set-STStateFile y
# su undo restaurarlo. Véase docs/REVISION.md.
$script:STEnRevision = @(
    'cpu.fgboost','cpu.visualeffects','cpu.spectre','cpu.hpet','cpu.idlestates','cpu.coreparking-off',
    'gpu.hags','gamemode','gamebar.dvr','gpu.power-mode',
    'lap.wifi-powersave','lap.dgpu-off-batt','lap.adaptive','lap.hibernate-fast','lap.bluetooth-idle',
    'svc.sysmain','svc.sysmain-hdd-off','svc.wsearch','mem.compact','svc.diagsvc','svc.xbox',
    'net.nla','net.tcp-autotune','net.latin','net.wol-off','net.netbios-off','net.llmnr-off','net.smb-hardening',
    # net.doh: undo borra entradas DoH que ya existían y un fallo con dos adaptadores no deja estado.
    # net.wsl-nat: si ~/.wslconfig ya tiene [wsl2], lo reescribe y se pierden sus otras opciones.
    'net.doh','net.wsl-nat',
    'off.classic-menu','off.spooler','off.netindex','off.storage-sense','off.hibernation',
    'priv.teletrack','priv.diagsvc-off','priv.tips','priv.activity','priv.cortana','priv.deep-telemetry',
    'priv.ads','priv.input-personalization','priv.preapps','priv.cloud-content','priv.feedback-all-off',
    'sec.pua-protection','sec.autostart-notifs','sec.firewall-log','sec.smb1-off',
    'upd.pause','upd.forced-reboot'
)

# Las acciones se ejecutan después de que termine Load-STCatalog.
foreach ($catalogFile in (Get-ChildItem -LiteralPath $Global:STCatalogDir -Filter '*.ps1' -File | Sort-Object Name)) {
    . $catalogFile.FullName
}

function Load-STCatalog {
    if ($script:STCatalog) { return }
    $all = @()
    $getters = @('Get-CleanupCatalogActions','Get-MemoryCatalogActions','Get-CpuCatalogActions',
                 'Get-GpuCatalogActions','Get-NetworkCatalogActions','Get-PrivacyCatalogActions',
                 'Get-SecurityCatalogActions',
                 'Get-OfficeCatalogActions','Get-UpdatesCatalogActions','Get-PowerCatalogActions',
                 'Get-LaptopCatalogActions')
    foreach ($g in $getters) {
        if (Get-Command $g -ErrorAction SilentlyContinue) {
            try { $all += & $g } catch { Write-STWarn "catalogo $g : $($_.Exception.Message)" }
        }
    }
    $all += Get-SetupCatalogActions
    # normalizar a hashtable con por lo menos los campos del contrato
    $norm = @()
    foreach ($a in $all) {
        $h = @{}
        foreach ($k in $a.Keys) { $h[$k] = $a[$k] }
        if (-not $h.ContainsKey('perfiles')) { $h.perfiles = @() }
        if (-not $h.ContainsKey('niveles'))  { $h.niveles  = @{ suave=1; medio=1; agresivo=1 } }
        if (-not $h.ContainsKey('needsRP'))  { $h.needsRP  = ($h.riesgo -eq 'alto') }
        $h.enRevision = ($script:STEnRevision -contains $h.id)
        $norm += $h
    }
    $script:STCatalog = $norm
}

function Get-STCatalogActions { return @($script:STCatalog) }

function Test-STApplies {
    param($Action, $Hw)
    # Todos los flujos (asistente, perfiles, setup, ejecutar e IA) pasan por aquí.
    if ($Action.enRevision) { return $false }
    try {
        if ($Action.ContainsKey('detect') -and $Action.detect) { return [bool](& $Action.detect $Hw $Action) }
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
