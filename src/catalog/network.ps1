# SparkTune network.ps1 — categoria E: red.

function Get-NetworkCatalogActions {
    $A = @()

    $A += @{
        id='net.nla'
        titulo='Desactivar Network Location Awareness (reconocimiento de red)'
        titulo_en='Disable Network Location Awareness'
        descripcion='Evita que Windows reclasifique redes y dispare perfiles publicos/firewall. En casa fija: OK.'
        descripcion_en='Stops Windows reclassifying networks and triggering public/firewall profiles. Fine on fixed home.'
        categoria='network'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','bajos-recursos','portatil-ahorro','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ "$(Get-STServiceStart 'NlaSvc')  ->  Manual" }
        apply={ Set-STServiceStart 'NlaSvc' 'Manual' }
        undo={ Set-STServiceStart 'NlaSvc' 'Auto'; Start-Service NlaSvc -ErrorAction SilentlyContinue }
        undoCmd='sc.exe config NlaSvc start=auto'
    }
    $A += @{
        id='net.doh'
        titulo='DNS over HTTPS (propuesta de proveedor)'
        titulo_en='DNS over HTTPS (provider proposal)'
        descripcion='DNS cifrado con el proveedor que elijas. Privacidad+ y evita DNS hijacking de ISP.'
        descripcion_en='Encrypted DNS with the provider you choose. Privacy + and avoids ISP DNS hijacking.'
        categoria='network'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('ofimatica','gaming','portatil-ahorro','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $hw.Build -ge 19628 }
        preview={ 'DNS: sistema -> DoH (Cloudflare/Google/Quad9), indexades per adaptador' }
        apply={
            Write-STInfo 'Proveedores: 1=Cloudflare 2=Google 3=Quad9'
            $pick = Read-Host '  elige'
            switch ($pick) {
                '2' { $p = 'dns.google'; $ip = '8.8.8.8' }
                '3' { $p = 'dns.quad9.net'; $ip = '9.9.9.9' }
                default { $p = 'cloudflare-dns.com'; $ip = '1.1.1.1' }
            }
            $ifaces = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty IfIndex)
            if (-not $ifaces) { $ifaces = @(Get-NetAdapter | Select-Object -First 1 -ExpandProperty IfIndex) }
            $prev = @()
            foreach ($i in $ifaces) {
                try {
                    $cur = @(Get-DnsClientServerAddress -InterfaceIndex $i -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
                    $prev += @{ iface = $i; dns = @($cur) }
                } catch { }
                Add-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate "https://$p/dns-query" -AllowFallbackToUdpTCP $true -DohSelection PreferDoh -ErrorAction Stop
                Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses ($ip) -ErrorAction SilentlyContinue
            }
            Set-STStateFile 'net.doh' @{ prev = $prev }
        }
        undo={
            $st = Get-STStateFile 'net.doh'
            if ($st -and $st.prev) {
                foreach ($e in $st.prev) {
                    try {
                        if (@($e.dns).Count -gt 0) { Set-DnsClientServerAddress -InterfaceIndex ([int]$e.iface) -ServerAddresses @($e.dns) -ErrorAction SilentlyContinue }
                        else { Set-DnsClientServerAddress -InterfaceIndex ([int]$e.iface) -ResetServerAddresses -ErrorAction SilentlyContinue }
                    } catch { }
                }
                Remove-STStateFile 'net.doh'
            }
            foreach ($ip in @('1.1.1.1','8.8.8.8','9.9.9.9')) {
                try { Remove-DnsClientDohServerAddress -ServerAddress $ip -Force -ErrorAction SilentlyContinue } catch { }
            }
        }
        undoCmd='restaura DNS por adaptador desde ~/.sparktune/state-net.doh.json'
    }
    $A += @{
        id='net.tcp-autotune'
        titulo='⚠ TCP autotuning nivel experimental'
        titulo_en='⚠ TCP autotuning to experimental'
        descripcion='Ventana TCP mas agresiva. Gana en conexiones de alta latencia (juegos overseas, VPN).'
        descripcion_en='More aggressive TCP window. Wins on high-latency links (overseas gaming, VPN).'
        aviso='En redes inestables puede causar cuelgues de descarga. Undo trivial.'
        aviso_en='On unstable networks downloads may stall. Trivial undo.'
        categoria='network'; riesgo='alto'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={
            $cur = (netsh.exe interface tcp show global 2>$null) -join "`n"
            $m = 'desconocido'
            if ($cur -match '(?i)autotun\S*\s*[:=]\s*(\w+)') { $m = $matches[1] }
            "$m -> experimental"
        }
        apply={ netsh.exe interface tcp set global autotuninglevel=experimental | Out-Null }
        undo={ netsh.exe interface tcp set global autotuninglevel=normal | Out-Null }
        undoCmd='netsh interface tcp set global autotuninglevel=normal'
    }
    $A += @{
        id='net.winsock-reset'
        titulo='⚠ Reset de Winsock + stack TCP/IP'
        titulo_en='⚠ Winsock + TCP/IP stack reset'
        descripcion='Repara catalogos de red corruptos. REINICIA y puede borrar VPNs/proxies configurados.'
        descripcion_en='Repairs corrupt network catalogs. Requires reboot; may wipe VPN/proxy configs.'
        aviso='Ultimo recurso si tienes red rota. Apuntate tus VPNs antes.'
        aviso_en='Last resort when networking is broken. Note your VPN configs first.'
        categoria='network'; riesgo='alto'; reversible=$false; admin=$true; reinicio=$true; needsRP=$false
        perfiles=@('personalizado','limpieza')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'winsock/TCP-IP -> reset' }
        apply={
            netsh.exe winsock reset | Out-Null
            netsh.exe int ip reset | Out-Null
        }
        undo={ Write-STWarn 'Winsock no tiene undo automatico; se dejo copia del registro en ~/.sparktune si hubo backup.' }
        undoCmd='n/a'
    }
    $A += @{
        id='net.latin'
        titulo='Desactivar limitacion de ancho de banda reservada (QoS)'
        titulo_en='Disable reserved bandwidth (QoS limiter)'
        descripcion='Quita el 20% reservado para tareas multimedia programadas (reservable, no reservada realmente).'
        descripcion_en='Removes the 20% reserved for scheduled multimedia (reservable, not actually held).'
        categoria='network'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','ofimatica','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'QoS reservable por defecto -> NetworkThrottlingIndex=0xFFFFFFFF' }
        apply={
            $g='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
            $cur = Get-STRegValue $g 'NetworkThrottlingIndex' 10
            Set-STRegValue $g '__ST_prev_NetworkThrottlingIndex' ([int]$cur)
            Set-STRegValue $g 'NetworkThrottlingIndex' -1
        }
        undo={
            $g='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
            $prev = Get-STRegValue $g '__ST_prev_NetworkThrottlingIndex' 10
            Set-STRegValue $g 'NetworkThrottlingIndex' ([int]$prev)
            Remove-ItemProperty $g '__ST_prev_NetworkThrottlingIndex' -ErrorAction SilentlyContinue
        }
        undoCmd='NetworkThrottlingIndex=10'
    }
    $A += @{
        id='net.wol-off'
        titulo='Wake-on-LAN desactivado en adaptadores de red'
        titulo_en='Disable Wake-on-LAN on network adapters'
        descripcion='Evita que la red despierte el PC desde suspension/apagado (gana bateria en portatil y evita encendidos fantasma).'
        descripcion_en='Prevents the NIC from waking the PC from sleep/off (saves laptop battery, avoids phantom power-ons).'
        categoria='network'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('portatil-ahorro','red-privacidad','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'WoL habilitado en adap. magic packet -> deshabilitado' }
        apply={
            $acs = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)
            foreach ($ad in $acs) {
                try { Disable-NetAdapterPowerManagement -Name $ad.Name -WakeOnMagicPacket -WakeOnPattern -ErrorAction SilentlyContinue } catch { }
            }
        }
        undo={
            $acs = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)
            foreach ($ad in $acs) {
                try { Enable-NetAdapterPowerManagement -Name $ad.Name -WakeOnMagicPacket -WakeOnPattern -ErrorAction SilentlyContinue } catch { }
            }
        }
        undoCmd='Enable-NetAdapterPowerManagement -WakeOnMagicPacket -WakeOnPattern'
    }
    $A += @{
        id='net.netbios-off'
        titulo='NetBIOS over TCP/IP deshabilitado'
        titulo_en='Disable NetBIOS over TCP/IP'
        descripcion='Cierra el puerto 137-139 de descubrimiento de red legado. En redes domesticas sin SMB antiguo: sin efecto visible.'
        descripcion_en='Closes legacy ports 137-139. On home networks without old SMB: no visible effect.'
        categoria='network'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'NetBIOS: por defecto -> deshabilitado (TcpipParameters)' }
        apply={
            foreach ($iid in (Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue)) {
                Set-STRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\$($iid.PSChildName)" 'NetbiosOptions' 2
            }
        }
        undo={
            foreach ($iid in (Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue)) {
                Set-STRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\$($iid.PSChildName)" 'NetbiosOptions' 0
            }
        }
        undoCmd='NetbiosOptions=0 en NetBT\Parameters\Interfaces'
    }
    $A += @{
        id='net.llmnr-off'
        titulo='Desactivar LLMNR y mDNS (resolucion local)'
        titulo_en='Disable LLMNR and mDNS (local resolution)'
        descripcion='Evita envenenamiento de cache LLMNR (ataques de vecinos en la LAN) y trafico mDNS extra. La resolución DNS normal sigue igual.'
        descripcion_en='Prevents LLMNR cache poisoning (LAN neighbor attacks) and extra mDNS traffic. Normal DNS keeps working.'
        categoria='network'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','ofimatica','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'EnableMulticast(LLMNR)/EnableMDNS ON -> OFF (politica de maquina)' }
        apply={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
            $prevA = Get-STRegValue $g 'EnableMulticast' $null
            $prevB = Get-STRegValue $g 'EnableMDNS' $null
            Set-STRegValue $g '__ST_prev_EnableMulticast' ([int]$(if ($null -eq $prevA) { 1 } else { [int]$prevA }))
            Set-STRegValue $g '__ST_prev_EnableMDNS' ([int]$(if ($null -eq $prevB) { 1 } else { [int]$prevB }))
            Set-STRegValue $g 'EnableMulticast' 0
            Set-STRegValue $g 'EnableMDNS' 0
        }
        undo={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
            $pa = Get-STRegValue $g '__ST_prev_EnableMulticast' 1
            $pb = Get-STRegValue $g '__ST_prev_EnableMDNS' 1
            Set-STRegValue $g 'EnableMulticast' ([int]$pa)
            Set-STRegValue $g 'EnableMDNS' ([int]$pb)
            Remove-ItemProperty $g '__ST_prev_EnableMulticast' -ErrorAction SilentlyContinue
            Remove-ItemProperty $g '__ST_prev_EnableMDNS' -ErrorAction SilentlyContinue
        }
        undoCmd='EnableMulticast=1; EnableMDNS=1 (o borrar politicas)'
    }
    $A += @{
        id='net.wsl-nat'
        titulo='WSL2 en modo NAT (evita exponer servicios WSL a la LAN)'
        titulo_en='WSL2 in NAT mode (avoid exposing WSL services to the LAN)'
        descripcion='Cambia WSL2 a networkingMode=NAT para que los puertos que abras en WSL (dev servers, bases de datos) no queden accesibles desde toda la red local.'
        descripcion_en='Switches WSL2 to networkingMode=NAT so ports you open in WSL (dev servers, DBs) are not reachable from the whole LAN.'
        aviso='Requiere WSL2 (no WSL1). Si usas mirrored (acceso directo desde LAN a proposito), NO lo cambies.'
        aviso_en='Requires WSL2 (not WSL1). If you deliberately use mirrored (intentional LAN access), do NOT change it.'
        categoria='network'; riesgo='medio'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('desarrollo','red-privacidad','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $c = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE '.wslconfig' } else { '' }; $w = if ($env:WINDIR) { Join-Path $env:WINDIR 'System32\wsl.exe' } else { '' }; [bool](($c -and (Test-Path $c)) -or ($w -and (Test-Path $w))) }
        preview={ '.wslconfig: networkingMode -> NAT' }
        apply={
            $f = Join-Path $env:USERPROFILE '.wslconfig'
            $prev = if (Test-Path $f) { Get-Content $f -Raw } else { '' }
            Set-STStateFile 'net.wsl-nat' @{ prev = $prev }
            $body = "[wsl2]`nnetworkingMode=NAT`n"
            if ($prev -and $prev -notmatch '(?i)\[wsl2\]') { $body = $prev.TrimEnd() + "`n`n" + $body }
            [System.IO.File]::WriteAllText($f, $body, (New-Object System.Text.UTF8Encoding($false)))
        }
        undo={
            $st = Get-STStateFile 'net.wsl-nat'
            $f = Join-Path $env:USERPROFILE '.wslconfig'
            if ($st -and $st.prev) { [System.IO.File]::WriteAllText($f, $st.prev, (New-Object System.Text.UTF8Encoding($false))) }
            elseif (Test-Path $f) { Remove-Item $f -Force }
            Remove-STStateFile 'net.wsl-nat'
        }
        undoCmd='restaura ~/.wslconfig desde state-net.wsl-nat.json'
    }
    $A += @{
        id='net.smb-hardening'
        titulo='Endurecer SMB: desactivar guest (insecure guest logons)'
        titulo_en='Harden SMB: disable insecure guest logons'
        descripcion='Bloquea conexiones SMB "guest" sin credenciales (NAS mal configurados, ataques de LAN). SMB normal con usuario/clave funciona igual.'
        descripcion_en='Blocks credential-less SMB guest connections (misconfigured NAS, LAN attacks). Normal SMB with user/password still works.'
        categoria='network'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','desarrollo','ofimatica','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'AllowInsecureGuestAuth: ? -> 0' }
        apply={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation'
            $cur = Get-STRegValue $g 'AllowInsecureGuestAuth' $null
            Set-STRegValue $g '__ST_prev_AllowInsecureGuestAuth' ([int]$(if ($null -eq $cur) { 1 } else { [int]$cur }))
            Set-STRegValue $g 'AllowInsecureGuestAuth' 0
        }
        undo={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation'
            $prev = Get-STRegValue $g '__ST_prev_AllowInsecureGuestAuth' 1
            Set-STRegValue $g 'AllowInsecureGuestAuth' ([int]$prev)
            Remove-ItemProperty $g '__ST_prev_AllowInsecureGuestAuth' -ErrorAction SilentlyContinue
        }
        undoCmd='AllowInsecureGuestAuth=<prev>'
    }
    return $A
}
