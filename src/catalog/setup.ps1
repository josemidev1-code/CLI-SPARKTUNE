# Ajustes de usuario para preparar un PC. Cada acción cambia un único valor.
function Get-STSetupRegistryValue([string]$Path, [string]$Name) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path)
    if (-not $key) { return $null }
    try {
        if ($key.GetValueNames() -notcontains $Name) { return $null }
        if ($key.GetValueKind($Name) -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
            throw "El valor $Name tiene un tipo inesperado."
        }
        return [int]$key.GetValue($Name)
    } finally { $key.Dispose() }
}

function Set-STSetupRegistryValue([string]$Path, [string]$Name, $Value) {
    if ($null -eq $Value) {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path, $true)
        if ($key) {
            try { $key.DeleteValue($Name, $false) } finally { $key.Dispose() }
        }
        return
    }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($Path)
    try { $key.SetValue($Name, [int]$Value, [Microsoft.Win32.RegistryValueKind]::DWord) }
    finally { $key.Dispose() }
}

function New-STSetupAction {
    param([string]$Id, [string]$Path, [string]$Name, [int]$Value,
          [string]$Title, [string]$TitleEn, [string]$Description, [string]$DescriptionEn,
          [int]$MinBuild = 10240)
    return @{
        id = $Id
        titulo = $Title
        titulo_en = $TitleEn
        descripcion = $Description
        descripcion_en = $DescriptionEn
        categoria = 'setup'
        riesgo = 'bajo'
        reversible = $true
        admin = $false
        reinicio = $false
        setupSafe = $true
        detect = { param($hw) $hw.Build -ge $MinBuild }.GetNewClosure()
        preview = {
            $old = Get-STSetupRegistryValue $Path $Name
            if ($null -eq $old) { $old = 'Windows default' }
            "$old -> $Value"
        }.GetNewClosure()
        apply = {
            $old = Get-STSetupRegistryValue $Path $Name
            Set-STStateFile $Id @{ previous = $old; value = $Value }
            Set-STSetupRegistryValue $Path $Name $Value
        }.GetNewClosure()
        undo = {
            $state = Get-STStateFile $Id
            if (-not $state -or $state.PSObject.Properties.Name -notcontains 'previous' -or $state.value -ne $Value) {
                throw "Falta el estado anterior de $Id."
            }
            $current = Get-STSetupRegistryValue $Path $Name
            if ($current -ne $Value -and $current -ne $state.previous) {
                throw "El valor de $Id ha cambiado desde la aplicación. Revisa esa opción en Configuración de Windows."
            }
            Set-STSetupRegistryValue $Path $Name $state.previous
        }.GetNewClosure()
        undoCmd = "sparktune undo --id=$Id"
    }
}

function Get-SetupCatalogActions {
    New-STSetupAction -Id 'setup.start-suggestions' `
        -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_IrisRecommendations' -Value 0 -MinBuild 22000 `
        -Title 'Ocultar sugerencias de Inicio' -TitleEn 'Hide Start recommendations' `
        -Description 'Quita las sugerencias de aplicaciones y consejos de Inicio en Windows 11. El cambio puede requerir cerrar sesión.' `
        -DescriptionEn 'Turns off app and tip suggestions in Windows 11 Start. Signing out may be required.'
    New-STSetupAction -Id 'setup.background-capture' `
        -Path 'System\GameConfigStore' -Name 'HistoricalCaptureEnabled' -Value 0 `
        -Title 'Desactivar la grabación en segundo plano' -TitleEn 'Turn off background recording' `
        -Description 'Desactiva Grabar lo que ocurrió en Capturas de Windows. Si usas las repeticiones automáticas, conserva esta opción.' `
        -DescriptionEn 'Turns off Record what happened in Windows Captures. Keep it enabled if you use instant replays.'
    New-STSetupAction -Id 'setup.game-mode' `
        -Path 'Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 `
        -Title 'Activar el Modo Juego de Windows' -TitleEn 'Enable Windows Game Mode' `
        -Description 'Activa el Modo Juego en la cuenta actual.' -DescriptionEn 'Enables Game Mode for the current user.'
}
