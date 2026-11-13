<#
.SYNOPSIS
  Instala SparkTune en %LOCALAPPDATA%\SparkTune y lo añade al PATH de usuario.
  No requiere admin.
.DESCRIPTION
  Instalar desde GitHub (recomendado, sin admin):

    powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/josemidev1-code/CLI-SPARKTUNE/main/install.ps1 -o $env:TEMP\sparktune-install.ps1; & $env:TEMP\sparktune-install.ps1; rm $env:TEMP\sparktune-install.ps1"

  Tambien vale "iwr ... | iex", pero si algun dia el script se ejecuta dentro de una
  sesion restringida (AMSI/EDR), la variante -o & ejecutar es mas fiable.
  Modo offline: ejecuta install.ps1 desde la carpeta del zip de la release.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) {
    Write-Error "SparkTune install: descarga primero el zip de la release. Una linea (PowerShell):"
    Write-Host '  powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/josemidev1-code/CLI-SPARKTUNE/main/install.ps1 -o $env:TEMP\sparktune-install.ps1; & $env:TEMP\sparktune-install.ps1; rm $env:TEMP\sparktune-install.ps1"' -ForegroundColor Cyan
    exit 1
}
$src = $PSScriptRoot
$dst = Join-Path $env:LOCALAPPDATA 'SparkTune'

Write-Host "SparkTune install" -ForegroundColor Cyan
# version actual para deteccion de update
$newVer = try { (Select-String -Path (Join-Path $src 'src\core\globals.ps1') -Pattern "STVersion = '([\d.]+)'").Matches[0].Groups[1].Value } catch { '' }
if ((Test-Path $dst) -and (-not $Force)) {
    $verFile = Join-Path $dst 'VERSION.txt'
    $oldVer = if (Test-Path $verFile) { (Get-Content $verFile -First 1).Trim() } else { '' }
    if ($oldVer -and $oldVer -eq $newVer) {
        Write-Host "Ya instalado v$oldVer en $dst (usa -Force para reinstalar)" -ForegroundColor Yellow
        exit 0
    }
    if ($oldVer) { Write-Host "Actualizando v$oldVer -> v$newVer" -ForegroundColor Cyan }
}
if (Test-Path $dst) {
    try { Remove-Item $dst -Recurse -Force } catch {
        Write-Host "No se pudo borrar la instalacion previa (archivos abiertos?). Cierra SparkTune y reintenta." -ForegroundColor Red
        exit 1
    }
}
New-Item -ItemType Directory -Path $dst -Force | Out-Null
foreach ($item in @('src', 'sparktune.ps1', 'sparktune.cmd', 'uninstall.ps1', 'LICENSE', 'README.md')) {
    $p = Join-Path $src $item
    if (Test-Path $p) {
        if ($item -eq 'src') {
            Copy-Item $p -Destination $dst -Recurse -Force
            $testsDst = Join-Path $dst 'tests'
            if (Test-Path $testsDst) { Remove-Item $testsDst -Recurse -Force }
        } else {
            Copy-Item $p -Destination $dst -Force
        }
    }
}

# journal portable: ~/.sparktune/journal.json (los undoCmd usan rutas %USERPROFILE% y son portables)
if ($newVer) { [System.IO.File]::WriteAllText((Join-Path $dst 'VERSION.txt'), $newVer, (New-Object System.Text.UTF8Encoding($false))) }
$jh = Join-Path $(if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }) '.sparktune'
if (-not (Test-Path $jh)) { New-Item -ItemType Directory -Path $jh -Force | Out-Null }
if (-not (Test-Path (Join-Path $jh 'journal.json'))) {
    [System.IO.File]::WriteAllText((Join-Path $jh 'journal.json'), '{"version":1,"entries":[]}', (New-Object System.Text.UTF8Encoding($false)))
}

# PATH de usuario via registro (sin admin)
$userPath = (Get-ItemProperty -Path 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue).Path
if ($null -eq $userPath) { $userPath = '' }
if (($userPath -split ';') -notcontains $dst) {
    $newPath = if ($userPath) { "$dst;$userPath" } else { $dst }
    Set-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value $newPath
    # notificar a las ventanas abiertas
    try {
        $sig = '[System.Runtime.InteropServices.DllImport("user32.dll",SetLastError=true,CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
        if (-not ('ST.Win32' -as [type])) { Add-Type -MemberDefinition $sig -Name Win32 -Namespace ST }
        $r = [UIntPtr]::Zero
        # HWND_BROADCAST=0xFFFF, WM_SETTINGCHANGE=0x1A, lParam="Environment"
        [ST.Win32]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r) | Out-Null
    } catch { }
    Write-Host "Anadido al PATH de usuario: $dst" -ForegroundColor Green
} else {
    Write-Host "Ya estaba en el PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "Instalado en: $dst" -ForegroundColor Green
Write-Host "Abre una NUEVA ventana de CMD o PowerShell y escribe: sparktune" -ForegroundColor Cyan
Write-Host "Sin cerrar/reabrir tambien vale:  & '$dst\sparktune.ps1'" -ForegroundColor DarkGray
Write-Host "Desinstalar:  powershell -File '$dst\uninstall.ps1'" -ForegroundColor DarkGray
