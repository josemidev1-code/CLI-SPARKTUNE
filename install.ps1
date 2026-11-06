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
    Remove-Item $dst -Recurse -Force
}
Copy-Item $src $dst -Recurse -Force

# PATH de usuario via registro (sin admin)
$userPath = (Get-ItemProperty -Path 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue).Path
if ($null -eq $userPath) { $userPath = '' }
if (($userPath -split ';') -notcontains $dst) {
    $newPath = if ($userPath) { "$dst;$userPath" } else { $dst }
    Set-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value $newPath
    # notificar a las ventanas abiertas
    try {
        $sig = '[System.Runtime.InteropServices.DllImport("user32.dll",SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd,uint Msg,UIntPtr wParam,string lParam,uint fuFlags,uint uTimeout,out UIntPtr lpdwResult);'
        if (-not ('ST.Win32' -as [type])) { Add-Type -MemberDefinition $sig -Name Win32 -Namespace ST }
        $r = [UIntPtr]::Zero
        [ST.Win32]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'WM_SETTINGCHANGE', 2, 5000, [ref]$r) | Out-Null
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
