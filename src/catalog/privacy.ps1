# SparkTune privacy.ps1 — categoria F: privacidad y telemetria.
# Nunca toca Defender, UAC, Windows Update de seguridad ni AppLocker.

function Get-PrivacyCatalogActions {
    $A = @()

    $A += @{
        id='priv.teletrack'
        titulo='Telemetria nivel basico (AllowTelemetry=1)'
        titulo_en='Telemetry to basic level (AllowTelemetry=1)'
        descripcion='Desactiva telemetria completa (envio de datos de uso/diagnostico extendido). Nivel Organizational no se toca.'
        descripcion_en='Disables full telemetry (extended usage/diagnostic data). Organizational untouched.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('ofimatica','gaming','bajos-recursos','portatil-ahorro','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={
            $cur = Get-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' $null
            $curTxt = if ($null -eq $cur) { '(sin policy, por defecto segun edicion)' } else { "$cur" }
            "$curTxt  ->  1 (basico)"
        }
        apply={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
            $cur = Get-STRegValue $g 'AllowTelemetry' 0
            Set-STRegValue $g '__ST_prev_AllowTelemetry' ([int]$cur)
            Set-STRegValue $g 'AllowTelemetry' 1
        }
        undo={
            $g='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
            $prev = Get-STRegValue $g '__ST_prev_AllowTelemetry' 0
            if ($null -eq $prev) { Remove-ItemProperty $g 'AllowTelemetry' -ErrorAction SilentlyContinue }
            else { Set-STRegValue $g 'AllowTelemetry' ([int]$prev) }
            Remove-ItemProperty $g '__ST_prev_AllowTelemetry' -ErrorAction SilentlyContinue
        }
        undoCmd='borra AllowTelemetry'
    }
    $A += @{
        id='priv.diagsvc-off'
        titulo='⚠ Desactivar servicio de telemetria (DiagTrack)'
        titulo_en='⚠ Disable telemetry service (DiagTrack)'
        descripcion='Detiene y deshabilita Connected User Experiences. En agresivo: tambien dmwappushservice.'
        descripcion_en='Stops and disables Connected User Experiences. On aggressive: also dmwappushservice.'
        aviso='Puede romperse la sincronizacion de relojes/Timeline y algunos diagnosticos corporativos.'
        aviso_en='May break clock sync/Timeline and corporate diagnostics.'
        categoria='privacy'; riesgo='medio'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','ofimatica','bajos-recursos','portatil-ahorro','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ "$(Get-STServiceStart 'DiagTrack')  ->  Disabled" }
        apply={
            Set-STServiceStart 'DiagTrack' 'Disabled'; Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
            Set-STServiceStart 'dmwappushservice' 'Disabled'; Stop-Service dmwappushservice -Force -ErrorAction SilentlyContinue
        }
        undo={
            Set-STServiceStart 'DiagTrack' 'Auto'; Start-Service DiagTrack -ErrorAction SilentlyContinue
            Set-STServiceStart 'dmwappushservice' 'Manual'; Start-Service dmwappushservice -ErrorAction SilentlyContinue
        }
        undoCmd='sc.exe config DiagTrack start=auto; dmwappushservice start=demand'
    }
    $A += @{
        id='priv.tips'
        titulo='Off: sugerencias, tips y anuncios en inicio/menu'
        titulo_en='Off: tips, suggestions and start-menu ads'
        descripcion='Quita sugerencias de Windows, content del launcher y recomendaciones de la config.'
        descripcion_en='Removes Windows tips, launcher content and settings recommendations.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('gaming','ofimatica','bajos-recursos','portatil-ahorro','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'sugerencias ON -> OFF' }
        apply={
            Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
            Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 0
            Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 0
            Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications' 'GetTips' 0
        }
        undo={
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications' 'GetTips' -ErrorAction SilentlyContinue
        }
        undoCmd='borra claves de ContentDeliveryManager'
    }
    $A += @{
        id='priv.activity'
        titulo='Off: historial de actividad y envio a Microsoft'
        titulo_en='Off: activity history and send to Microsoft'
        descripcion='Deja de subir tu actividad (apps, archivos) a la cuenta MS. TimeLine local seguira parcial.'
        descripcion_en='Stops uploading activity (apps, files) to MS account. Local Timeline partially remains.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','ofimatica','portatil-ahorro','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'UploadSettings -> 0 (off)' }
        apply={ Set-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadSettings' 0 }
        undo={ Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadSettings' -ErrorAction SilentlyContinue }
        undoCmd='borra UploadSettings'
    }
    $A += @{
        id='priv.cortana'
        titulo='Off: Cortana y resultados Bing en Busqueda'
        titulo_en='Off: Cortana and Bing results in Search'
        descripcion='Busqueda local pura; sin web/Bing en el menu inicio.'
        descripcion_en='Pure local search; no web/Bing in start menu.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('ofimatica','gaming','bajos-recursos','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'Bing/Cortana ON -> OFF' }
        apply={
            Set-STRegValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
            Set-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
            Set-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
        }
        undo={
            Remove-ItemProperty 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' -ErrorAction SilentlyContinue
        }
        undoCmd='borra politicas de busqueda'
    }
    $A += @{
        id='priv.deep-telemetry'
        titulo='⚠⚠ Telemetria profunda: bloquear tareas y servicios (agresivo)'
        titulo_en='⚠⚠ Deep telemetry: block tasks and services (aggressive)'
        descripcion='Deshabilita Scheduled tasks de Application Telemetry/Compatibility Assistant y desactiva UnifiedTelemetry en tareas.'
        descripcion_en='Disables Application Telemetry/Compatibility Assistant scheduled tasks.'
        aviso='En entornos corporativos/MDM puede generar avisos de cumplimiento. Usuario particular: OK.'
        aviso_en='In corporate/MDM may trigger compliance warnings. Home users: OK.'
        categoria='privacy'; riesgo='alto'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('gaming','bajos-recursos','personalizado')
        niveles=@{ agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'tareas ApplicationTelemetry -> deshabilitadas' }
        apply={
            $names = @(
                '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
                '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
                '\Microsoft\Windows\Application Experience\StartupAppTask',
                '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
                '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
                '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
            )
            foreach ($n in $names) { Disable-ScheduledTask -TaskPath (Split-Path $n -Parent) -TaskName (Split-Path $n -Leaf) -ErrorAction SilentlyContinue | Out-Null }
        }
        undo={
            $names = @(
                '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
                '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
                '\Microsoft\Windows\Application Experience\StartupAppTask',
                '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
                '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
                '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
            )
            foreach ($n in $names) { Enable-ScheduledTask -TaskPath (Split-Path $n -Parent) -TaskName (Split-Path $n -Leaf) -ErrorAction SilentlyContinue | Out-Null }
        }
        undoCmd='Enable-ScheduledTask de las mismas rutas'
    }
    $A += @{
        id='priv.ads'
        titulo='Off: anuncios y contenido patrocinado en el menú Inicio'
        titulo_en='Off: sponsored ads and app suggestions in Start'
        descripcion='Desactiva el contenido patrocinado (apps "sugeridas" con publicidad) en el menu Inicio.'
        descripcion_en='Disables sponsored content (ad-driven "suggested" apps) in the Start menu.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','ofimatica','gaming','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'anuncios inicio ON -> OFF' }
        apply={ Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'AppSuggestionsEnabled' 0 }
        undo={ Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'AppSuggestionsEnabled' -ErrorAction SilentlyContinue }
        undoCmd='borra AppSuggestionsEnabled'
    }
    $A += @{
        id='priv.input-personalization'
        titulo='Off: personalizacion de entrada y datos de escritura a mano'
        titulo_en='Off: input personalization and inking data upload'
        descripcion='Evita que Windows suba datos de tecleo/manuscrito para "mejorar" reconocimiento. El diccionario local sigue funcionando.'
        descripcion_en='Stops uploading typing/handwriting data for recognition "improvements". Local dictionary keeps working.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','ofimatica','personalizado')
        niveles=@{ suave=1; medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'InputPersonalization ON -> OFF (HKCU)' }
        apply={ Set-STRegValue 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1; Set-STRegValue 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1; Set-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\InputPersonalization' 'RestrictImplicitTextCollection' 1; Set-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\InputPersonalization' 'RestrictImplicitInkCollection' 1 }
        undo={
            Remove-ItemProperty 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\InputPersonalization' 'RestrictImplicitTextCollection' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\InputPersonalization' 'RestrictImplicitInkCollection' -ErrorAction SilentlyContinue
        }
        undoCmd='borra claves RestrictImplicit*'
    }
    $A += @{
        id='priv.preapps'
        titulo='Off: instalacion automatica de "app recommended" (ContentDelivery)'
        titulo_en='Off: auto-install of recommended apps (ContentDelivery)'
        descripcion='Bloquea que Windows instale silenciosamente apps "recomendadas" (juegos, trialware) tras reinstalar o en cuentas nuevas.'
        descripcion_en='Blocks silent installs of "recommended" apps (games, trialware) after reinstall or on new accounts.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('red-privacidad','ofimatica','bajos-recursos','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'AutoInstallContent ON -> OFF' }
        apply={
            $g='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            Set-STRegValue $g 'SilentInstalledAppsEnabled' 0
            Set-STRegValue $g 'OemPreInstalledAppsEnabled' 0
            Set-STRegValue $g 'PreInstalledAppsEnabled' 0
            Set-STRegValue $g 'PreInstalledAppsEverEnabled' 0
        }
        undo={
            $g='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            foreach ($n in @('SilentInstalledAppsEnabled','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','PreInstalledAppsEverEnabled')) {
                Remove-ItemProperty $g $n -ErrorAction SilentlyContinue
            }
        }
        undoCmd='borra claves PreInstalled/SilentInstalled'
    }
    $A += @{
        id='priv.cloud-content'
        titulo='Off: sugerencias de contenido en Explorer (OneDrive/Store en Mis Documentos)'
        titulo_en='Off: Explorer content suggestions (OneDrive/Store in My Documents)'
        descripcion='Quita los popups de Explorer que sugieren subir carpetas a OneDrive o comprar plantillas de Office.'
        descripcion_en='Removes Explorer popups suggesting OneDrive folder upload or buying Office templates.'
        categoria='privacy'; riesgo='bajo'; reversible=$true; admin=$false; reinicio=$false; needsRP=$false
        perfiles=@('creativo','desarrollo','red-privacidad','ofimatica','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'sugerencias contenido explorer ON -> OFF' }
        apply={
            Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
            Set-STRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-314544Enabled' 0
        }
        undo={
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-314544Enabled' -ErrorAction SilentlyContinue
        }
        undoCmd='borra ShowSyncProviderNotifications + SubscribedContent-314544Enabled'
    }
    $A += @{
        id='priv.feedback-all-off'
        titulo='Off: peticiones de feedback (mostradores de valoracion)'
        titulo_en='Off: feedback prompts (rating popups)'
        descripcion='Desactiva los "How likely are you to recommend...?" dentro de apps/Windows.'
        descripcion_en='Disables "How likely are you to recommend...?" popups inside apps/Windows.'
        categoria='privacy'; riesgo='sin'; reversible=$true; admin=$true; reinicio=$false; needsRP=$false
        perfiles=@('creativo','desarrollo','red-privacidad','ofimatica','gaming','personalizado')
        niveles=@{ medio=1; agresivo=1 }
        detect={ param($hw) $true }
        preview={ 'AllowFeedbackHub: ? -> OFF (politica + HKLM)' }
        apply={
            Set-STRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowFeedbackHub' 0
            Set-STRegValue 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
        }
        undo={
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowFeedbackHub' -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' -ErrorAction SilentlyContinue
        }
        undoCmd='borra AllowFeedbackHub + NumberOfSIUFInPeriod'
    }
    return $A
}
