function Invoke-STSetup {
    param([string]$Perfil, [string]$Plan, [string]$Goal, [switch]$SkipApps, [switch]$SkipTweaks, [switch]$Interactive, [switch]$Yes)

    $en = $Global:STLang -eq 'en'
    $file = Join-Path $Global:STData 'setup-profiles.json'
    $profiles = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    $keys = @($profiles.PSObject.Properties.Name)
    if (-not $Perfil -and -not $Goal) {
        if ($Yes) { throw 'Indica --perfil para usar --yes.' }
        if ($Global:STDryRun -or [Console]::IsInputRedirected) {
            Write-STHeader -Title $(if ($en) { 'Setup profiles' } else { 'Perfiles de preparación' })
            Write-STInfo "sparktune setup --perfil=$($keys[0]) --dry-run"
            foreach ($key in $keys) {
                $label = if ($en) { $profiles.$key.nombre_en } else { $profiles.$key.nombre }
                Write-STInfo "$key - $label"
            }
            return 0
        }
        $items = @(
            if (-not $Plan) {
                [pscustomobject]@{ id = '_ai'; label = $(if ($en) { 'Describe your goal to AI' } else { 'Cuéntale tu objetivo a la IA' }) }
            }
            foreach ($key in $keys) {
                [pscustomobject]@{ id = $key; label = $(if ($en) { $profiles.$key.nombre_en } else { $profiles.$key.nombre }) }
            }
        )
        $index = Show-STMenu -Title $(if ($en) { 'Set up your new PC' } else { 'Prepara tu PC nuevo' }) -Items $items
        if ($index -lt 0) { return 0 }
        if ($items[$index].id -eq '_ai') {
            $Goal = ([string](Read-Host $(if ($en) { 'What do you want to optimize?' } else { '¿Qué quieres optimizar?' }))).Trim()
            if (-not $Goal) { return 0 }
        } else { $Perfil = $items[$index].id }
    }

    $hw = Get-STHardware
    Load-STCatalog
    $actions = @{}
    foreach ($action in (Get-STCatalogActions)) { $actions[$action.id] = $action }

    $fromAI = [bool]$Goal
    if ($fromAI) {
        $Goal = $Goal.Trim()
        if (-not $Goal -or $Goal.Length -gt 500) { throw (T 'ai.goalLength') }
        $context = @{
            goal = $Goal
            laptop = [bool]$hw.IsLaptop
            has_battery = [bool]$hw.Battery
            plugged_in = if ($hw.Battery) { [bool]$hw.Plugged } else { $null }
            apps_allowed = -not $SkipApps
            tweaks_allowed = -not $SkipTweaks
            profiles = @(
                foreach ($key in $keys) {
                    if ($key -eq 'ninguno' -or $key -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw "ID de perfil no válido: $key" }
                    $entry = $profiles.$key
                    $defaultPlan = if ($hw.IsLaptop) { $entry.'plan-portatil' } else { $entry.'plan-sobremesa' }
                    @{
                        id = $key
                        name = if ($en) { $entry.nombre_en } else { $entry.nombre }
                        apps = @(if (-not $SkipApps) { $entry.apps })
                        tweaks = @(
                            if (-not $SkipTweaks) {
                                foreach ($id in $entry.ajustes) {
                                    $action = $actions[$id]
                                    if ($action -and $action.setupSafe -and (Test-STApplies $action $hw)) {
                                        STField $action 'titulo'
                                    }
                                }
                            }
                        )
                        default_plan = $defaultPlan
                    }
                }
            )
            plans = @(
                @{ id = 'ninguno'; description = 'Keep the current power plan' }
                foreach ($action in $actions.Values | Sort-Object id) {
                    if ($action.planKey -and $action.reversible -and (Test-STApplies $action $hw)) {
                        @{ id = $action.planKey; description = STField $action 'descripcion' }
                    }
                }
            )
        }
        if ($Global:STDryRun) {
            ConvertTo-Json -InputObject $context -Depth 8
            return
        }
        try { $recommendation = Get-STAISetupRecommendation -Context $context }
        catch {
            Write-STErr $_.Exception.Message
            Write-STInfo $(if ($en) { 'Continue without AI with sparktune setup.' } else { 'Para seguir sin IA, elige un perfil desde sparktune setup.' })
            return 1
        }
        Write-STInfo $recommendation.reason
        if ($recommendation.profile -eq 'ninguno') { return 0 }

        $Perfil = $recommendation.profile
        $Plan = $recommendation.plan
        $SkipApps = $SkipApps -or -not $recommendation.apps
        $SkipTweaks = $SkipTweaks -or -not $recommendation.tweaks
    }
    if ($Perfil -notin $keys) {
        Write-STErr "Perfil de setup desconocido: $Perfil. Disponibles: $($keys -join ', ')."
        return 2
    }
    $profile = $profiles.$Perfil

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
    $mode = if ($Global:STDryRun) {
        if ($en) { 'PREVIEW · No changes' } else { 'SIMULACIÓN · Sin cambios' }
    } elseif ($fromAI) {
        if ($en) { 'AI recommendation' } else { 'Recomendación de IA' }
    } else {
        if ($en) { 'Setup plan' } else { 'Plan de preparación' }
    }
    Write-STHeader -Title "$name [$Perfil]" -Detail $mode
    if ($apps.Count) {
        $section = if ($en) { 'Apps via WinGet' } else { 'Aplicaciones vía WinGet' }
        Write-STSection "$section ($($apps.Count))"
        foreach ($app in $apps) { Write-STLine "    • $($app.name) [$($app.winget)]" }
    }
    if (-not $SkipApps -and $profile.manual) {
        Write-STSection $(if ($en) { 'Manual installation' } else { 'Instalación manual' })
        foreach ($manual in $profile.manual) {
            Write-STLine "    • $($manual.nombre)" '' 'bold'
            Write-STLine ("      " + $(if ($en) { $manual.instrucciones_en } else { $manual.instrucciones }))
            Write-STLine "      $($manual.url)" 'gray'
        }
    }
    if ($tweaks.Count) {
        $section = if ($en) { 'Windows settings' } else { 'Ajustes de Windows' }
        Write-STSection "$section ($($tweaks.Count))"
        foreach ($action in $tweaks) {
            Write-STLine "    • $(STField $action 'titulo') [$($action.id)]" '' 'bold'
            Write-STLine "      $(STField $action 'descripcion')"
        }
    }
    if ($power) {
        Write-STSection $(if ($en) { 'Power plan' } else { 'Plan de energía' })
        Write-STLine "    • $(STField $power 'titulo') [$Plan]" '' 'bold'
        Write-STLine "      $(STField $power 'descripcion')"
    }
    Write-STLine ''
    if ($Global:STDryRun) { return 0 }

    if ($fromAI -and [Console]::IsInputRedirected) {
        $command = "sparktune setup --perfil=$Perfil --plan=$Plan"
        if ($SkipApps) { $command += ' --sin-apps' }
        if ($SkipTweaks) { $command += ' --sin-ajustes' }
        Write-STInfo $command
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
        elseif ($status -eq 'present') {
            Write-STInfo $(if ($en) { "$($app.name) is already installed." } else { "$($app.name) ya está instalada." })
        }
        else { Write-STErr "$($app.name) [$($app.winget)]: $status"; $result = 1 }
    }
    foreach ($action in @($tweaks) + @($power)) {
        if (-not $action) { continue }
        $status = Invoke-STApply -Action $action -Yes $Yes.IsPresent
        if ($status -eq 'fail') { $result = 1 }
    }
    return $result
}
