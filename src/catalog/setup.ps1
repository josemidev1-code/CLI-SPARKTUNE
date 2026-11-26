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
        registryPath = $Path
        registryName = $Name
        registryValue = $Value
        minBuild = $MinBuild
        detect = { param($hw, $action) $hw.Build -ge $action.minBuild }
        preview = {
            param($action)
            $old = Get-STSetupRegistryValue $action.registryPath $action.registryName
            if ($null -eq $old) { $old = 'Windows default' }
            "$old -> $($action.registryValue)"
        }
        apply = {
            param($action)
            $old = Get-STSetupRegistryValue $action.registryPath $action.registryName
            Set-STStateFile $action.id @{ previous = $old; value = $action.registryValue }
            Set-STSetupRegistryValue $action.registryPath $action.registryName $action.registryValue
        }
        undo = {
            param($action)
            $state = Get-STStateFile $action.id
            if (-not $state -or $state.PSObject.Properties.Name -notcontains 'previous' -or $state.value -ne $action.registryValue) {
                throw "Falta el estado anterior de $($action.id)."
            }
            $current = Get-STSetupRegistryValue $action.registryPath $action.registryName
            if ($current -ne $action.registryValue -and $current -ne $state.previous) {
                throw "El valor de $($action.id) ha cambiado desde la aplicación. Revisa esa opción en Configuración de Windows."
            }
            Set-STSetupRegistryValue $action.registryPath $action.registryName $state.previous
        }
        undoCmd = "sparktune undo --id=$Id"
    }
}

function Get-SetupCatalogActions {
    $file = Join-Path $Global:STData 'acciones.json'
    $doc = Get-Content -LiteralPath $file -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($doc.version -ne 1 -or $doc.acciones -isnot [array]) {
        throw 'acciones.json requiere version 1 y una lista acciones.'
    }
    $ids = @{}
    $targets = @{}
    $definitions = @(
        for ($index = 0; $index -lt $doc.acciones.Count; $index++) {
            $action = $doc.acciones[$index]
            $prefix = "acciones.json acciones[$index]"
            foreach ($field in @('id','titulo','titulo_en','descripcion','descripcion_en','ruta','nombre')) {
                if ($action.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($action.$field) -or
                    $action.$field -match '[\p{Cc}\p{Cf}]') {
                    throw "$prefix.$field debe ser texto sin caracteres de control."
                }
            }
            if ($action.id -cnotmatch '^setup\.[a-z0-9]+(?:-[a-z0-9]+)*$' -or $ids.ContainsKey($action.id)) {
                throw "$prefix.id tiene un formato inválido o está repetido."
            }
            if ($action.ruta -notmatch '^(?:Software\\Microsoft\\(?:[a-z0-9]+\\)*[a-z0-9]+|System\\GameConfigStore)$') {
                throw "$prefix.ruta debe estar dentro de Software\Microsoft o ser System\GameConfigStore de HKCU."
            }
            if ($action.nombre -notmatch '^[a-z0-9_-]+$') { throw "$prefix.nombre no es un nombre de registro válido." }
            $target = "$($action.ruta):$($action.nombre)"
            if ($targets.ContainsKey($target)) { throw "$prefix apunta al mismo valor que otra acción." }
            if (($action.valor -isnot [int] -and $action.valor -isnot [long]) -or $action.valor -notin @(0,1)) {
                throw "$prefix.valor debe ser el entero 0 o 1."
            }
            if (($action.build_minima -isnot [int] -and $action.build_minima -isnot [long]) -or
                $action.build_minima -lt 10240 -or $action.build_minima -gt [int]::MaxValue) {
                throw "$prefix.build_minima debe ser un entero a partir de 10240."
            }
            $ids[$action.id] = $true
            $targets[$target] = $true
            $action
        }
    )
    foreach ($action in $definitions) {
        New-STSetupAction -Id $action.id -Path $action.ruta -Name $action.nombre -Value $action.valor `
            -MinBuild $action.build_minima -Title $action.titulo -TitleEn $action.titulo_en `
            -Description $action.descripcion -DescriptionEn $action.descripcion_en
    }
}
