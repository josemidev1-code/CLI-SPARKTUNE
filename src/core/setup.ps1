# Planes de setup v1. El archivo solo contiene referencias al catálogo.
function Read-STSetupPlan([string]$Path) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item -isnot [IO.FileInfo] -or $item.Length -gt 65536) { throw 'El plan debe ser un archivo JSON de hasta 64 KB.' }
    $json = Get-Content -LiteralPath $item.FullName -Raw -Encoding UTF8 -ErrorAction Stop
    if (-not $json -or -not $json.TrimStart().StartsWith('{')) {
        throw 'El plan debe contener un objeto JSON.'
    }
    $doc = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    $fields = @('version','perfil','apps','ajustes','energia','manual')
    if ($doc -isnot [pscustomobject] -or
        @($doc.PSObject.Properties.Name | Where-Object { $_ -cnotin $fields }).Count -or
        ($doc.version -isnot [int] -and $doc.version -isnot [long]) -or $doc.version -ne 1 -or $doc.manual -isnot [bool]) {
        throw 'Formato de plan de SparkTune no válido (versión 1).'
    }
    foreach ($field in @('perfil','energia')) {
        if ($doc.$field -isnot [string] -or $doc.$field -cnotmatch '\A[a-z0-9]+(-[a-z0-9]+)*\z') {
            throw "Campo no válido en el plan: $field."
        }
    }
    foreach ($field in @('apps','ajustes')) {
        if ($doc.$field -isnot [array]) { throw "El campo $field debe ser una lista de IDs." }
        $seen = @{}
        foreach ($id in $doc.$field) {
            if ($id -isnot [string] -or $id -cnotmatch '\A[a-z0-9]+([.-][a-z0-9]+)*\z' -or $seen.ContainsKey($id)) {
                throw "ID no válido o repetido en $field."
            }
            $seen[$id] = $true
        }
    }
    return $doc
}

function Save-STSetupPlan([string]$Path, $Data) {
    $target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $temp = Join-Path ([IO.Path]::GetDirectoryName($target)) ('.sparktune-plan-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $Data -Depth 4), [Text.UTF8Encoding]::new($false))
        # File.Move fails if the destination already exists, even on PowerShell 5.1.
        [IO.File]::Move($temp, $target)
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}

function Invoke-STSetup {
    param([string]$Perfil, [string]$Plan, [string]$Goal, [switch]$SkipApps, [switch]$SkipTweaks, [switch]$Interactive, [switch]$Yes, [string]$SavePath, [string]$LoadPath, [switch]$ValidateOnly)

    $en = $Global:STLang -eq 'en'
    $file = Join-Path $Global:STData 'setup-profiles.json'
    $profiles = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    $keys = @($profiles.PSObject.Properties.Name)
    $saved = $null
    if ($LoadPath) {
        try { $saved = Read-STSetupPlan $LoadPath }
        catch { Write-STErr $_.Exception.Message; return 3 }
        $Perfil = $saved.perfil
        $Plan = $saved.energia
    }
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
    try {
        if ($Perfil -notin $keys) {
            Write-STErr "Perfil de setup desconocido: $Perfil. Disponibles: $($keys -join ', ')."
            return $(if ($saved) { 3 } else { 2 })
        }
        $profile = $profiles.$Perfil
        $appIds = if ($saved) { $saved.apps } else { $profile.apps }
        $tweakIds = if ($saved) { $saved.ajustes } else { $profile.ajustes }
        $showManual = -not $SkipApps -and $profile.manual -and (-not $saved -or $saved.manual)

        $apps = @()
        if (-not $SkipApps) {
            $catalog = Get-STAppsCatalog
            if (-not $catalog) { throw 'No se pudo cargar el catálogo de aplicaciones.' }
            $apps = @(
                foreach ($id in ($appIds | Select-Object -Unique)) {
                    $app = $catalog.apps | Where-Object { $_.id -eq $id } | Select-Object -First 1
                    if (-not $app) { throw "Aplicación desconocida en ${Perfil}: $id" }
                    $app
                }
            )
        }

        $tweaks = @()
        if (-not $SkipTweaks) {
            $tweaks = @(
                foreach ($id in ($tweakIds | Select-Object -Unique)) {
                    $action = $actions[$id]
                    if (-not $action -or -not $action.setupSafe) { throw "Ajuste de setup desconocido en ${Perfil}: $id" }
                    if (Test-STApplies $action $hw) { $action }
                    elseif ($saved) { throw "El ajuste $id del plan no es compatible con este equipo." }
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
                return $(if ($saved) { 3 } else { 2 })
            }
        }

    } catch {
        if (-not $saved) { throw }
        Write-STErr $_.Exception.Message
        return 3
    }
    if ($ValidateOnly) {
        Write-STOk $(if ($en) {
            "Valid plan: $($apps.Count) app(s), $($tweaks.Count) setting(s), power plan $Plan."
        } else {
            "Plan válido: $($apps.Count) apps, $($tweaks.Count) ajustes. Energía: $Plan."
        })
        return 0
    }

    if ($SavePath) {
        $data = [ordered]@{
            version = 1
            perfil = $Perfil.ToLowerInvariant()
            apps = @($apps | ForEach-Object { $_.id })
            ajustes = @($tweaks | ForEach-Object { $_.id })
            energia = $Plan
            manual = [bool]$showManual
        }
        Save-STSetupPlan -Path $SavePath -Data $data
        Write-STOk $(if ($en) { "Plan saved: $SavePath" } else { "Plan guardado: $SavePath" })
        return 0
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
    if ($showManual) {
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

# Comandos de catálogo. Solo exponen las acciones declarativas de setup.
function Invoke-STActionCatalog {
    param([switch]$ValidateOnly, [switch]$Json, [string]$Id, [switch]$Yes)
    try { $actions = @(Get-SetupCatalogActions) }
    catch { Write-STErr $_.Exception.Message; return 3 }

    if ($ValidateOnly) {
        Write-STOk (TF 'catalog.valid' @($actions.Count))
        return 0
    }
    if ($Id) {
        $action = $actions | Where-Object id -eq $Id | Select-Object -First 1
        if (-not $action) { Write-STErr (TF 'catalog.unknown' @($Id)); return 2 }
        if (-not (Test-STApplies $action (Get-STHardware))) {
            Write-STErr (TF 'catalog.incompatible' @($Id))
            return 1
        }
        if ($Global:STDryRun) {
            Show-STCard $action
            Write-STInfo (T 'dryrun')
            return 0
        }
        $status = Invoke-STApply -Action $action -Yes $Yes.IsPresent
        if ($status -ne 'ok') { return 1 }
        return 0
    }

    if ($Json) {
        $rows = @(
            foreach ($action in $actions) {
                [ordered]@{
                    id = $action.id
                    titulo = STField $action 'titulo'
                    descripcion = STField $action 'descripcion'
                    build_minima = $action.minBuild
                    reversible = $action.reversible
                }
            }
        )
        ConvertTo-Json -InputObject $rows -Depth 3
    } else {
        foreach ($action in $actions) { Write-STInfo "$($action.id) · $(STField $action 'titulo')" }
        return 0
    }
}
