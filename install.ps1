<#
.SYNOPSIS
  Instala SparkTune en %LOCALAPPDATA%\SparkTune y lo añade al PATH de usuario.
  No requiere admin.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$dst = Join-Path $env:LOCALAPPDATA 'SparkTune'

Write-Host "SparkTune install" -ForegroundColor Cyan
if (Test-Path $dst) {
    if (-not $Force) {
        Write-Host "Ya instalado en $dst" -ForegroundColor Yellow
        Write-Host "Reejecuta con -Force para sobrescribir." -ForegroundColor Yellow
        exit 0
    }
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
$jh = Join-Path $env:USERPROFILE '.sparktune'
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
