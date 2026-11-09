# SparkTune security.ps1 — categoria G: seguridad del sistema.
# Principio: SparkTune NUNCA desactiva Defender, firewall, UAC ni actualizaciones
# de seguridad. Solo informa, endurece (reversible) y restaura opciones ocultas.

function Get-SecurityCatalogActions {
    $A = @()

    $A += @{
        id='sec.defender-report'
        titulo='Informe de estado de Microsoft Defender'
        titulo_en='Microsoft Defender status report'
        descripcion='Muestra estado de antivirus, firewall y ultimas actualizaciones. No modifica nada.'
        descripcion_en='Shows antivirus, firewall and last update status. Changes nothing.'
        categoria='security'; riesgo='sin'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','ofimatica','gaming','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={
            $r = @()
            try {
                $av = Get-MpComputerStatus -ErrorAction Stop
                $r += "AV: $($av.AntivirusEnabled)  AS: $($av.AntispywareEnabled)  RTam: $($av.RealTimeProtectionEnabled)"
                $r += "ult. act. firmas: $($av.AntivirusSignatureLastUpdated)"
            } catch { $r += 'Defender no accesible (¿otro AV o sin permisos?)' }
            ($r -join '  |  ')
        }
        apply={ Write-STInfo 'sin acciones: solo lectura' }
        undo={ }
        undoCmd='n/a (informativo)'
    }
    $A += @{
        id='sec.pua-protection'
        titulo='PUA protection: bloquear apps potencialmente no deseadas'
        titulo_en='PUA protection: block potentially unwanted apps'
        descripcion='Activa el bloqueo de PUA/crimeware en Defender y en el navegador Edge. Recomendado.'
        descripcion_en='Turns on Defender PUA/crimeware blocking and Edge smart filter. Recommended.'
        categoria='security'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','ofimatica','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'PUA: ? -> habilitado (Defender + Edge)' }
        apply={
            Set-MpPreference -PUAProtection Enable -ErrorAction SilentlyContinue
            Set-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'SmartScreenEnabled' 1
        }
        undo={
            Set-MpPreference -PUAProtection NotConfigured -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'SmartScreenEnabled' -ErrorAction SilentlyContinue
        }
        undoCmd='Set-MpPreference -PUAProtection NotConfigured + borra policy Edge'
    }
    $A += @{
        id='sec.autostart-notifs'
        titulo='Reactivar avisos de apps al inicio (ocultados por OEMs)'
        titulo_en='Re-enable startup app notifications (hidden by OEMs)'
        descripcion='Muchos portatiles vienen con las notificaciones de apps desactivadas (avisos silenciosos). Las reactiva.'
        descripcion_en='Many laptops ship with app notifications silently disabled. This re-enables them.'
        categoria='security'; riesgo='sin'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','ofimatica','gaming','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'avisos de apps: ? -> ON (por usuario y globales)' }
        apply={
            Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' 1
        }
        undo={ Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' -ErrorAction SilentlyContinue }
        undoCmd='borra NOC_GLOBAL_SETTING_TOASTS_ENABLED'
    }
    $A += @{
        id='sec.firewall-log'
        titulo='Logs del firewall de Windows activados'
        titulo_en='Enable Windows Firewall logging'
        descripcion='Activa registro de paquetes descartados (Drop) para poder diagnosticar. Escribe en %windir%\System32\LogFiles\Firewall\pfirewall.log.'
        descripcion_en='Enables dropped-packet logging for diagnostics at %windir%\System32\LogFiles\Firewall\pfirewall.log.'
        categoria='security'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'log drop: ? -> habilitado' }
        apply={ Set-NetFirewallProfile -Profile Domain,Public,Private -LogDroppedPackets Enabled -LogAllowedPackets NotConfigured }
        undo={ Set-NetFirewallProfile -Profile Domain,Public,Private -LogDroppedPackets NotConfigured }
        undoCmd='Set-NetFirewallProfile -LogDroppedPackets NotConfigured'
    }
    $A += @{
        id='sec.smb1-off'
        titulo='⚠ Desactivar SMBv1 (protocolo legado tipo WannaCry)'
        titulo_en='⚠ Disable SMBv1 (legacy WannaCry-class protocol)'
        descripcion='SMBv1 es inseguro y solo lo usan NAS/SMB muy antiguos. Si tienes un NAS viejo o Windows XP en casa, revisa antes.'
        descripcion_en='SMBv1 is insecure; only very old NAS/XP use it. Check before disabling if you have old NAS/XP at home.'
        aviso='Si usas NAS antiguos o equipos legacy, prueba que sigan funcionando tras aplicar. Undo inmediato.'
        aviso_en='If you use old NAS/legacy gear, verify they still work after applying. Trivial undo.'
        categoria='security'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$true; needsRP=$false
        perfiles=@('red-privacidad','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'SMB1: ? -> deshabilitado' }
        apply={ Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop }
        undo={ Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop }
        undoCmd='Enable-WindowsOptionalFeature SMB1Protocol'
    }
    $A += @{
        id='sec.hidden-restore'
        titulo='Restaurar opciones ocultas por politicas (menu clasico, energia, rendimiento)'
        titulo_en='Restore options hidden by policies (classic menus, power, performance)'
        descripcion='Quita politicas que ocultan opciones normales de Windows: plan de energia avanzado, pestañas del Administrador de tareas, "Ejecutar" del menu inicio.'
        descripcion_en='Removes policies hiding normal Windows options: advanced power plan, Task Manager tabs, Run dialog.'
        categoria='security'; riesgo='sin'; reversible=$false; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('personalizado','ofimatica')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'politicas de ocultacion -> borradas si existen' }
        apply={
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoRun' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System' 'DisableTaskMgr' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings' 'SetPowerSaveConfigEnabled' -ErrorAction SilentlyContinue
        }
        undo={ Write-STWarn 'informativo: restaura opciones, no crea politicas nuevas (no hay estado previo que guardar)' }
        undoCmd='n/a'
    }
    return $A
}
