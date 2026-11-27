<#
.SYNOPSIS
  Instala SparkTune en %LOCALAPPDATA%\SparkTune y lo añade al PATH de usuario.
.DESCRIPTION
  Desde el ZIP o el repositorio, instala la copia local. Si ejecutas solo
  install.ps1, descarga e instala el ZIP de la última versión 1.x publicada.
  Consulta el README para el comando de instalación rápida.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (-not $PSScriptRoot) {
    throw 'Guarda install.ps1 como archivo y ejecútalo con powershell.exe -File.'
}

function Test-InstallFiles([string]$Directory) {
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Directory $file) -PathType Leaf)) { return $false }
    }
    return (Test-Path -LiteralPath (Join-Path $Directory 'src\catalog') -PathType Container)
}

function Select-STRelease($Releases) {
    # Este instalador es de la edición 1.x. Desde la 2.0.0 (Python), la última release
    # de GitHub no incluye el ZIP de PowerShell, así que se elige la 1.x publicada más reciente.
    $Releases | Where-Object { -not $_.draft -and -not $_.prerelease -and $_.tag_name -match '^v1\.\d+\.\d+$' } |
        Sort-Object { [version]$_.tag_name.Substring(1) } -Descending | Select-Object -First 1
}

function Add-InstallPath {
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $userPath = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if (($userPath -split ';') -contains $dst) { return }
        $newPath = if ($userPath) { "$dst;$userPath" } else { $dst }
        # Conserva el tipo del valor existente, incluido REG_EXPAND_SZ.
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($key.GetValueNames() -contains 'Path') { $kind = $key.GetValueKind('Path') }
        $key.SetValue('Path', $newPath, $kind)
    } finally { $key.Dispose() }

    # notificar a las ventanas abiertas
    try {
        $sig = '[System.Runtime.InteropServices.DllImport("user32.dll",SetLastError=true,CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
        if (-not ('ST.Win32' -as [type])) { Add-Type -MemberDefinition $sig -Name Win32 -Namespace ST }
        $r = [UIntPtr]::Zero
        # HWND_BROADCAST=0xFFFF, WM_SETTINGCHANGE=0x1A, lParam="Environment"
        [ST.Win32]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r) | Out-Null
    } catch { }
    Write-Host "Añadido al PATH de usuario: $dst" -ForegroundColor Green
}

$requiredFiles = @(
    'sparktune.cmd', 'sparktune.ps1', 'uninstall.ps1',
    'src\core\globals.ps1', 'src\core\ui.ps1', 'src\core\banner.ps1',
    'src\core\detect.ps1', 'src\core\journal.ps1', 'src\core\engine.ps1',
    'src\core\catalog.ps1', 'src\data\profiles.json', 'src\data\apps.json'
)
$dst = Join-Path $env:LOCALAPPDATA 'SparkTune'
$work = Join-Path $env:LOCALAPPDATA ('SparkTune-install-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $work 'previous'
$versionFile = 'src\core\globals.ps1'
$src = $PSScriptRoot
$releaseVersion = $null
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$lock = [System.Threading.Mutex]::new($false, "Global\SparkTuneInstall-$sid")
$locked = $false
$keepBackup = $false

try {
    try { $locked = $lock.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Ya hay otra instalación de SparkTune en curso.' }

    if (-not ((Test-Path -LiteralPath (Join-Path $src 'src')) -or
              (Test-Path -LiteralPath (Join-Path $src 'sparktune.ps1')) -or
              (Test-Path -LiteralPath (Join-Path $src 'sparktune.cmd')))) {
        New-Item -ItemType Directory -Path $work | Out-Null
        $archive = Join-Path $work 'release.zip'
        $extract = Join-Path $work 'release'
        $repo = 'josemidev1-code/CLI-SPARKTUNE'
        $tls = [Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol = $tls -bor [Net.SecurityProtocolType]::Tls12
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=100" -UseBasicParsing -TimeoutSec 60
            $release = Select-STRelease $releases
            if (-not $release) { throw 'No hay ninguna versión 1.x de SparkTune publicada.' }
            $null = $release.tag_name -match '^v(\d+\.\d+\.\d+)$'
            $releaseVersion = $Matches[1]
            $assetName = "SparkTune-$releaseVersion.zip"
            $asset = $release.assets | Where-Object { $_.name -eq $assetName }
            if (-not $asset) { throw "La versión $releaseVersion no incluye $assetName." }
            Write-Host "Descargando SparkTune v$releaseVersion..." -ForegroundColor Cyan
            $url = "https://github.com/$repo/releases/download/$($release.tag_name)/$assetName"
            Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 120 -OutFile $archive
        } finally { [Net.ServicePointManager]::SecurityProtocol = $tls }

        if ($asset.digest -match '^sha256:([a-f0-9]{64})$') {
            if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $Matches[1]) {
                throw 'La suma SHA-256 del ZIP de SparkTune no coincide con la de GitHub.'
            }
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $extract
        $src = if (Test-InstallFiles $extract) { $extract } else { Join-Path $extract "SparkTune-$releaseVersion" }
    }

    if (-not (Test-InstallFiles $src)) { throw "La copia de SparkTune está incompleta: $src" }
    $version = Select-String -LiteralPath (Join-Path $src $versionFile) -Pattern "STVersion = '(\d+\.\d+\.\d+)'"
    if (-not $version) { throw 'No se pudo identificar la versión de SparkTune.' }
    $newVer = $version.Matches[0].Groups[1].Value
    if ($releaseVersion -and $newVer -ne $releaseVersion) {
        throw "El ZIP contiene v$newVer y la versión publicada es v$releaseVersion."
    }

    $verFile = Join-Path $dst 'VERSION.txt'
    $oldVer = if (Test-Path -LiteralPath $verFile) { ([string](Get-Content -LiteralPath $verFile -First 1)).Trim() }
    if (-not $Force -and $oldVer -eq $newVer -and (Test-InstallFiles $dst)) {
        Add-InstallPath
        Write-Host "Ya instalado v$oldVer en $dst (usa -Force para reinstalar)." -ForegroundColor Yellow
        exit 0
    }

    $stage = Join-Path $work 'new'
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    foreach ($item in @('src', 'sparktune.ps1', 'sparktune.cmd', 'uninstall.ps1', 'LICENSE', 'README.md')) {
        $path = Join-Path $src $item
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $stage -Recurse }
    }
    if (-not (Test-InstallFiles $stage)) { throw 'No se copiaron todos los archivos de SparkTune.' }
    [System.IO.File]::WriteAllText((Join-Path $stage 'VERSION.txt'), $newVer)

    # Reutiliza el journal de usuario durante la instalación y las actualizaciones.
    $jh = Join-Path $env:USERPROFILE '.sparktune'
    New-Item -ItemType Directory -Path $jh -Force | Out-Null
    $journal = Join-Path $jh 'journal.json'
    if (-not (Test-Path -LiteralPath $journal)) {
        [System.IO.File]::WriteAllText($journal, '{"version":1,"entries":[]}')
    }

    if (Test-Path -LiteralPath $dst) { [System.IO.Directory]::Move($dst, $backup) }
    $installed = $false
    try {
        [System.IO.Directory]::Move($stage, $dst)
        $installed = $true
        Add-InstallPath
    } catch {
        try {
            if ($installed) { [System.IO.Directory]::Move($dst, $stage) }
            if (Test-Path -LiteralPath $backup) { [System.IO.Directory]::Move($backup, $dst) }
        } catch {
            $keepBackup = $true
            throw "No se pudo restaurar la instalación anterior. Archivos de recuperación en $work. $_"
        }
        throw
    }

    Write-Host "Instalado SparkTune v$newVer en $dst." -ForegroundColor Green
    Write-Host 'Abre una nueva ventana de CMD o PowerShell y ejecuta sparktune.' -ForegroundColor Cyan
    Write-Host "En esta ventana: & '$dst\sparktune.cmd'" -ForegroundColor DarkGray
} finally {
    try {
        if (-not $keepBackup -and (Test-Path -LiteralPath $work)) {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    } finally {
        if ($locked) { $lock.ReleaseMutex() }
        $lock.Dispose()
    }
}

exit 0
