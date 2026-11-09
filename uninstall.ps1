<#
.SYNOPSIS
  Desinstala SparkTune: quita del PATH de usuario y borra %LOCALAPPDATA%\SparkTune.
  Opcional: -Journal borra tambien el registro de cambios (~\.sparktune).
#>
[CmdletBinding()]
param([switch]$Journal)

$ErrorActionPreference = 'Stop'
$dst = Join-Path $env:LOCALAPPDATA 'SparkTune'

Write-Host "SparkTune uninstall" -ForegroundColor Cyan

$userPath = (Get-ItemProperty -Path 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue).Path
if ($userPath) {
    $parts = @($userPath -split ';' | Where-Object { $_ -and ($_ -ne $dst) })
    $new = $parts -join ';'
    if ($new) { Set-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value $new }
    else { Remove-ItemProperty -Path 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue }
    Write-Host "Quitado del PATH de usuario." -ForegroundColor Green
}

if (Test-Path $dst) {
    try { Remove-Item $dst -Recurse -Force } catch {
        Write-Host "No se pudo borrar $dst (archivos abiertos). Cierra la terminal que lo use y reintenta." -ForegroundColor Red
        exit 1
    }
}
Write-Host "Carpeta eliminada: $dst" -ForegroundColor Green

if ($Journal) {
    $home2 = Join-Path $env:USERPROFILE '.sparktune'
    if (Test-Path $home2) { Remove-Item $home2 -Recurse -Force }
    Write-Host "Journal eliminado: $home2" -ForegroundColor Green
} else {
    Write-Host "Se conserva ~/.sparktune (journal + undo). Usa -Journal para borrarlo." -ForegroundColor DarkGray
}
Write-Host "Desinstalado. Reinicia la terminal para refrescar el PATH." -ForegroundColor Cyan
