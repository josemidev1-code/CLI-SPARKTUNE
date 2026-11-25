function Invoke-STSetup {
    param([string]$Perfil, [string]$Plan, [switch]$SkipApps, [switch]$SkipTweaks, [switch]$Interactive, [switch]$Yes)

    $en = $Global:STLang -eq 'en'
    $file = Join-Path $Global:STData 'setup-profiles.json'
    $profiles = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    $keys = @($profiles.PSObject.Properties.Name)
    if (-not $Perfil) {
        if ($Yes) { throw 'Indica --perfil para usar --yes.' }
        if ($Global:STDryRun -or [Console]::IsInputRedirected) {
            Write-STInfo "setup --perfil=$($keys[0]) --dry-run"
            foreach ($key in $keys) {
                $label = if ($en) { $profiles.$key.nombre_en } else { $profiles.$key.nombre }
                Write-STInfo "$key - $label"
            }
            return 0
        }
        $items = @(
            foreach ($key in $keys) {
                [pscustomobject]@{ id = $key; label = $(if ($en) { $profiles.$key.nombre_en } else { $profiles.$key.nombre }) }
            }
        )
        $index = Show-STMenu -Title $(if ($en) { 'Set up your new PC' } else { 'Prepara tu PC nuevo' }) -Items $items
        if ($index -lt 0) { return 0 }
        $Perfil = $items[$index].id
    }
    if ($Perfil -notin $keys) {
        Write-STErr "Perfil de setup desconocido: $Perfil. Disponibles: $($keys -join ', ')."
        return 2
    }
    $profile = $profiles.$Perfil
    $hw = Get-STHardware
    Load-STCatalog

    $apps = @()
    if (-not $SkipApps) {
        $catalog = Get-STAppsCatalog
        if (-not $catalog) { throw 'No se pudo cargar el catálogo de aplicaciones.' }
        $apps = @(
            foreach ($id in ($profile.apps | Select-Object -Unique)) {
                $app = $catalog.apps | Where-Object { $_.id -eq $id } | Select-Object -First 1
                if (-not $app) { throw "Aplicación desconocida en ${Perfil}: $id" }
                $app
            }
        )
    }

    $actions = @{}
    foreach ($action in (Get-STCatalogActions)) { $actions[$action.id] = $action }
    $tweaks = @()
    if (-not $SkipTweaks) {
        $tweaks = @(
            foreach ($id in ($profile.ajustes | Select-Object -Unique)) {
                $action = $actions[$id]
                if (-not $action -or -not $action.setupSafe) { throw "Ajuste de setup desconocido en ${Perfil}: $id" }
                if (Test-STApplies $action $hw) { $action }
            }
        )
    }
    $power = $null
    if (-not $Plan) { $Plan = if ($hw.IsLaptop) { $profile.'plan-portatil' } else { $profile.'plan-sobremesa' } }
    if ($Plan -ne 'ninguno') {
        if (-not $Plan) { throw "Falta un plan de energía para $Perfil." }
        $power = $actions["power.$Plan"]
        if (-not $power -or -not $power.reversible -or -not (Test-STApplies $power $hw)) {
            Write-STErr "Plan desconocido o no compatible con el equipo: $Plan. Usa sparktune power para ver los planes."
            return 2
        }
    }

    $name = if ($en) { $profile.nombre_en } else { $profile.nombre }
    Write-STLine "$name [$Perfil]" 'cyan' 'bold'
    if ($apps.Count) {
        Write-STLine $(if ($en) { 'Applications via WinGet' } else { 'Aplicaciones vía WinGet' })
        foreach ($app in $apps) { Write-STInfo "$($app.name) [$($app.winget)]" }
    }
    if (-not $SkipApps) {
        foreach ($manual in $profile.manual) {
            Write-STInfo "$($manual.nombre) ($(if ($en) { 'manual installation' } else { 'instalación manual' }))"
            Write-STLine $(if ($en) { $manual.instrucciones_en } else { $manual.instrucciones })
            Write-STLine $manual.url
        }
    }
    foreach ($action in $tweaks) {
        Write-STInfo "$(STField $action 'titulo') [$($action.id)]"
        Write-STLine "  $(STField $action 'descripcion')"
    }
    if ($power) {
        Write-STInfo "$(STField $power 'titulo') [$Plan]"
        Write-STLine "  $(STField $power 'descripcion')"
    }
    if ($Global:STDryRun) {
        Write-STInfo (T 'dryrun')
        return 0
    }

    $result = 0
    foreach ($app in $apps) {
        $question = if ($en) { "Install $($app.name)?" } else { "¿Instalar $($app.name)?" }
        if (-not $Yes -and -not (Read-STConfirm -Question $question)) { continue }
        if (-not (Test-STWinget)) {
            Write-STErr $(if ($en) { 'WinGet is unavailable. Install App Installer to continue with apps.' } else { 'WinGet no está disponible. Instala App Installer para poder instalar las aplicaciones.' })
            $result = 1
            break
        }
        $status = Install-STWingetApp -App $app -Source 'winget' -Interactive:$Interactive
        if ($status -eq 'ok') { Write-STOk $app.name }
        else { Write-STErr "$($app.name) [$($app.winget)]: $status"; $result = 1 }
    }
    foreach ($action in @($tweaks) + @($power)) {
        if (-not $action) { continue }
        $status = Invoke-STApply -Action $action -Yes $Yes.IsPresent
        if ($status -eq 'fail') { $result = 1 }
    }
    return $result
}
