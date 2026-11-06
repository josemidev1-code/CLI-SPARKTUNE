# SparkTune detect.ps1 — deteccion de hardware (CIM/WMI, PS 5.1).
# Devuelve hashtable: Cpu, CpuCores, CpuThreads, RamGB, HasSSD, HasHDD, Disks[], Gpu[],
# GpuVendor, HasNvidia, HasAmd, HasIntelGpu, HasDgpu, IsLaptop, Battery, BatteryPct, Plugged,
# Build, IsWin11, OsName, PowerPlan, SpaceFreeGB, SpaceTotalGB, Admin

function Get-STHardware {
    $hw = @{}
    $hw.Cpu = '?'; $hw.CpuCores = 0; $hw.CpuThreads = 0
    $hw.RamGB = 0; $hw.HasSSD = $false; $hw.HasHDD = $false
    $hw.Disks = @(); $hw.Gpu = @(); $hw.GpuVendor = 'desconocida'
    $hw.HasNvidia = $false; $hw.HasAmd = $false; $hw.HasIntelGpu = $false; $hw.HasDgpu = $false
    $hw.IsLaptop = $false; $hw.Battery = $false; $hw.BatteryPct = -1; $hw.Plugged = $true
    $hw.Build = 0; $hw.IsWin11 = $false; $hw.OsName = 'Windows'
    $hw.PowerPlan = '?'; $hw.SpaceFreeGB = 0; $hw.SpaceTotalGB = 0
    try { $hw.Admin = Is-STAdmin } catch { $hw.Admin = $false }

    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs) {
            $hw.IsLaptop = ($cs.PCSystemType -ge 2)
            $hw.Manufacturer = "$($cs.Manufacturer)"
            $hw.Model = "$($cs.Model)"
        }
    } catch { }

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cpu) {
            $hw.Cpu = ("$($cpu.Name)").Trim()
            $hw.CpuCores = [int]$cpu.NumberOfCores
            $hw.CpuThreads = [int]$cpu.NumberOfLogicalProcessors
        }
    } catch { }

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $hw.RamGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $hw.Build = [int]$os.BuildNumber
            $hw.OsName = "$($os.Caption)".Trim()
            $hw.IsWin11 = ($hw.Build -ge 22000)
        }
    } catch { }

    # discos fisicos: MediaType 4=SSD, 3=HDD (SMR 5) — fallback por taille/particiones
    try {
        $pd = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue
        foreach ($d in $pd) {
            $gb = [Math]::Round(($d.Size / 1GB), 0)
            $hw.Disks += [pscustomobject]@{ Number = $d.Index; SizeGB = $gb; Model = "$($d.Model)".Trim(); Type = 'porDetectar' }
        }
        $phys = Get-PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($p in $phys) {
            $t = "$($p.MediaType)"
            $gb = [Math]::Round($p.Size / 1GB, 0)
            $found = $false
            for ($i = 0; $i -lt $hw.Disks.Count; $i++) {
                if ($hw.Disks[$i].SizeGB -eq $gb -or $hw.Disks[$i].Model -eq "$($p.FriendlyName)".Trim()) {
                    $hw.Disks[$i].Type = $t; $found = $true; break
                }
            }
            if (-not $found) { $hw.Disks += [pscustomobject]@{ Number = -1; SizeGB = $gb; Model = "$($p.FriendlyName)".Trim(); Type = $t } }
            if ($t -match 'SSD') { $hw.HasSSD = $true }
            if ($t -match 'HDD') { $hw.HasHDD = $true }
        }
        if (-not $hw.HasSSD -and -not $hw.HasHDD) {
            foreach ($d in $hw.Disks) {
                if ($d.Type -match 'SSD') { $hw.HasSSD = $true }
                if ($d.Type -match 'HDD') { $hw.HasHDD = $true }
            }
        }
    } catch { }

    # espacio en C:
    try {
        $c = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        if ($c) {
            $hw.SpaceTotalGB = [Math]::Round($c.Size / 1GB, 1)
            $hw.SpaceFreeGB  = [Math]::Round($c.FreeSpace / 1GB, 1)
        }
    } catch { }

    # GPUs
    try {
        $vc = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($g in $vc) {
            $name = "$($g.Name)".Trim()
            if (-not $name) { continue }
            $hw.Gpu += [pscustomobject]@{
                Name = $name
                Driver = "$($g.DriverVersion)".Trim()
                VramMB = [int]($g.AdapterRAM / 1MB)
            }
            if ($name -match 'NVIDIA|GeForce|RTX|GTX') { $hw.HasNvidia = $true }
            if ($name -match 'AMD|Radeon')             { $hw.HasAmd = $true }
            if ($name -match 'Intel.*(HD|UHD|Iris|Arc)') { $hw.HasIntelGpu = $true }
        }
        if ($hw.HasNvidia) { $hw.GpuVendor = 'NVIDIA' }
        elseif ($hw.HasAmd) { $hw.GpuVendor = 'AMD' }
        elseif ($hw.HasIntelGpu) { $hw.GpuVendor = 'Intel' }
        $dgpuCount = 0
        if ($hw.HasNvidia) { $dgpuCount++ }
        if ($hw.HasAmd -and $hw.HasIntelGpu) { $dgpuCount++ }
        $hw.HasDgpu = ($dgpuCount -ge 1) -and ($hw.Gpu.Count -ge 1)
    } catch { }

    # bateria: Win32_Battery
    try {
        $bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bat) {
            $hw.Battery = $true
            $hw.BatteryPct = [int]$bat.EstimatedChargeRemaining
            # BatteryStatus: 1=desconectado(no bateria),2=cargando,3=enchufado y cargado,...
            $st = [int]$bat.BatteryStatus
            $hw.Plugged = ($st -in @(2,3,5,6,9))
            if (-not $hw.IsLaptop) { $hw.IsLaptop = $true }
        }
    } catch { }

    # plan de energia activo
    try {
        $act = (powercfg.exe /getactivescheme 2>$null) -join "`n"
        $hw.PowerPlan = ''
        $hw.PowerPlanGuid = ''
        if ($act -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
            $hw.PowerPlanGuid = $matches[1]
        }
        if ($hw.PowerPlanGuid) {
            $guidEsc = [regex]::Escape($hw.PowerPlanGuid)
            foreach ($pl in @(powercfg.exe /list 2>$null)) {
                if ("$pl" -match $guidEsc) {
                    if ("$pl" -match '\(([^)]+)\)\s*$') { $hw.PowerPlan = $matches[1] }
                    elseif ("$pl" -match ':\s*(.+?)\s*\(') { $hw.PowerPlan = $matches[1] }
                    break
                }
            }
        }
        if (-not $hw.PowerPlan -and $hw.PowerPlanGuid) { $hw.PowerPlan = $hw.PowerPlanGuid }
    } catch { }

    return $hw
}

function Is-STAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal $id
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Show-STDetectSummary($hw) {
    Write-STInfo "$(T 'hw.os'):   $($hw.OsName) (build $($hw.Build))"
    Write-STInfo "$('CPU'.PadRight(9)) $($hw.Cpu)  [$($hw.CpuCores)C/$($hw.CpuThreads)T]"
    Write-STInfo "$(T 'hw.ram'):  $($hw.RamGB) GB"
    $dts = ($hw.Disks | ForEach-Object { "$($_.SizeGB)GB $($_.Type)" }) -join ' + '
    if (-not $dts) { $dts = '—' }
    Write-STInfo "$(T 'hw.disk'): $dts   (SSD: $($hw.HasSSD) / HDD: $($hw.HasHDD))"
    $gp = ''
    foreach ($x in $hw.Gpu) { $gp += $x.Name + ' + ' }
    if ($gp.Length -gt 3) { $gp = $gp.Substring(0, $gp.Length - 3) }
    $g = $gp
    if (-not $g) { $g = '—' }
    Write-STInfo "$(T 'hw.gpu'):  $g"
    if ($hw.Battery) {
        $pct = if ($hw.BatteryPct -ge 0) { " $($hw.BatteryPct)%$(if ($hw.Plugged) { ' ⌁' } else { ' 🔋' })" } else { '' }
        Write-STInfo "$(T 'hw.batt'):$pct"
    } else {
        Write-STInfo "$(T 'hw.batt'): sobremesa"
    }
}
