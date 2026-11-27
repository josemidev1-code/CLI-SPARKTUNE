# SparkTune ui.ps1 — colores ANSI, diccionario ES/EN, menus, fichas, confirmaciones.
# Cargado por sparktune.ps1. Solo cmdlets PS 5.1 + ReadKey + VT.

# ---------- consola / ANSI ----------
$script:STAnsi = $true
function Test-STConsoleUsable {
    # [Console] es un type; solo es util si hay consola real interactiva
    try {
        if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $false }
        $null = [Console]::WindowWidth
        return $true
    } catch { return $false }
}
$script:STConsole = Test-STConsoleUsable

function Test-STAnsi {
    if ($env:WT_SESSION) { return $true }
    if ($env:TERM_PROGRAM) { return $true }
    if ($env:ConEmuANSI) { return $true }
    if ($Host.Name -match 'PowerShell ISE') { return $false }
    # conhost de Win10 1607+ soporta VT; en Win7 no
    try {
        $bld = [Environment]::OSVersion.Version.Build
        if ($bld -ge 10240) { return $true }
    } catch { }
    return $false
}

function Enable-STVirtualTerminal {
    $script:STVtEnabled = $false
    $script:STAnsi = Test-STAnsi
    if (-not $script:STAnsi -and -not $script:STConsole) { return }
    try {
        if (-not ('STNat.Win32C' -as [type])) {
            $sig = @'
[DllImport("kernel32.dll",SetLastError=true)] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll",SetLastError=true)] public static extern bool GetConsoleMode(IntPtr h,out uint m);
[DllImport("kernel32.dll",SetLastError=true)] public static extern bool SetConsoleMode(IntPtr h,uint m);
'@
            Add-Type -MemberDefinition $sig -Name Win32C -Namespace STNat
        }
        $h = [STNat.Win32C]::GetStdHandle(-11)
        $m = [uint32]0
        if ([STNat.Win32C]::GetConsoleMode($h, [ref]$m)) {
            # ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
            $script:STVtEnabled = [STNat.Win32C]::SetConsoleMode($h, ($m -bor 4))
            if ($script:STVtEnabled) { $script:STAnsi = $true }
        }
    } catch { $script:STAnsi = $false }
}

function STC([string]$code) {
    if (-not $script:STAnsi -or $env:NO_COLOR) { return '' }
    return "$([char]27)[${code}m"
}

$script:STColorMap = @{
    reset='0'; bold='1'; dim='2'; italic='3'
    gray='90'; red='91'; green='92'; yellow='93'; blue='94'; magenta='95'; accent='38;2;195;180;245'; white='97'
    bg_red='41'; bg_green='42'; bg_yellow='43'; bg_blue='44'; bg_magenta='45'; bg_cyan='46'; bg_gray='100'
}

function Write-STLine {
    param([string]$Text = '', [string]$Color = '', [string]$Extra = '')
    $pre = ''; $suf = ''
    if ($script:STAnsi) {
        if ($Color -and $script:STColorMap.ContainsKey($Color)) { $pre += STC $script:STColorMap[$Color] }
        if ($Extra  -and $script:STColorMap.ContainsKey($Extra))  { $pre += STC $script:STColorMap[$Extra] }
        if ($pre) { $suf = STC '0' }
    }
    if ($script:STConsole) { [Console]::Write("$pre$Text$suf`n") } else { Write-Host "$pre$Text$suf" }
}
function Write-STPlain([string]$Text) {
    if ($script:STConsole) { [Console]::Write($Text) } else { Write-Host -NoNewline $Text }
}
function Write-STInfo([string]$T)  { Write-STLine "  $T" }
function Write-STOk([string]$T)    { Write-STLine "  $T" }
function Write-STWarn([string]$T)  { Write-STLine "  [!] $T" 'yellow' }
function Write-STErr([string]$T)   { Write-STLine "  [x] $T" 'red' }

function Clear-STScreen {
    if ($script:STConsole) { [Console]::Clear() } else { Clear-Host }
}

function Write-STHeader {
    param([string]$Title, [string]$Detail = '')
    Write-STLine ''
    Write-STLine "  SparkTune  /  $Title" 'accent' 'bold'
    if ($Detail) { Write-STLine "  $Detail" 'gray' }
    Write-STLine "  $('─' * 44)" 'gray'
}

function Write-STSection([string]$Title) {
    Write-STLine ''
    Write-STLine "  $Title" '' 'bold'
}

# ---------- idioma ----------
$script:ST = @{}
$script:ST_ES = @{
    'catalog.valid' = 'Catálogo válido: {0} acciones.'
    'catalog.unknown' = 'Acción desconocida: {0}. Consulta sparktune acciones.'
    'catalog.incompatible' = 'Acción incompatible con este equipo: {0}.'
    'app.tagline'    = 'Optimizacion de Windows'
    'app.by'         = 'por @josemidev1'
    'menu.title'     = 'Que quieres optimizar?'
    'menu.level'     = 'Que nivel?'
    'lvl.suave'      = 'Suave      (solo cambios seguros y conservadores)'
    'lvl.medio'      = 'Medio      (equilibrio rendimiento/estabilidad)'
    'lvl.agresivo'   = 'Agresivo   (maxima ganancia, lee cada ficha)'
    'prof.gaming'    = 'Gaming'
    'prof.ofimatica' = 'Ofimatica / Productividad'
    'prof.portatil-ahorro' = 'Portatil - Ahorro de bateria'
    'prof.portatil-rendimiento' = 'Portatil - Rendimiento (enchufado)'
    'prof.limpieza'  = 'Limpieza de disco'
    'prof.bajos-recursos' = 'Bajos recursos (PC antiguo)'
    'prof.red-privacidad' = 'Red y privacidad'
    'prof.creativo' = 'Creativo / Edicion (foto, video, 3D)'
    'prof.desarrollo' = 'Desarrollo (IDEs, WSL, compiles)'
    'prof.personalizado' = 'Personalizado (elige tu mismo)'
    'prof.custom'    = 'Personalizado'
    'list.title'     = 'Acciones disponibles (filtra hardware/perfil). Espacio=seleccionar  Enter=continuar  F=ficha  Esc=volver'
    'list.empty'     = 'Ninguna accion aplica a este hardware/perfil.'
    'card.title'     = 'Ficha'
    'card.desc'      = 'Que hace'
    'card.why'       = 'Por que / aviso'
    'card.cur'       = 'Actual -> Propuesto'
    'card.risk'      = 'Riesgo'
    'ai.goalLength'  = 'El objetivo debe tener 500 caracteres o menos.'
    'ai.invalidLevel'= 'Usa --nivel=suave|medio|agresivo junto a un perfil concreto.'
    'ai.missingKey'  = 'Configura GROQ_API_KEY u OPENAI_API_KEY en esta terminal o usa sparktune ai --dry-run para ver el contexto.'
    'ai.noCandidates'= 'No hay ajustes reversibles compatibles. Revisa el perfil o vuelve a probar sin ese filtro.'
    'ai.httpError'   = 'El proveedor de IA devolvió HTTP {0}. Comprueba la clave, el acceso al modelo y la cuota de la API.'
    'ai.networkError'= 'No se pudo conectar al proveedor de IA. Comprueba la conexión y vuelve a intentarlo.'
    'ai.noResponse'  = 'El modelo no devolvió recomendaciones en el formato esperado.'
    'ai.restart'     = 'Requiere reinicio.'
    'ai.noRecommendations' = 'El modelo no encontró recomendaciones para este objetivo.'
    'card.rev'       = 'Reversible'
    'card.reboot'    = 'Requiere reinicio'
    'card.admin'     = 'Requiere admin'
    'card.executed'  = 'EJECUTADA'
    'yes'='si'; 'no'='no'
    'risk.sin'='ninguno'; 'risk.bajo'='bajo'; 'risk.medio'='MEDIO'; 'risk.alto'='ALTO'
    'confirm.all'    = 'Aplicar las {0} acciones seleccionadas? (s/n)'
    'confirm.one'    = 'Aplicar esta accion? (s/n/e=editar ficha)'
    'confirm.type'   = 'ACCION DE RIESGO ALTO. Escribe SI (mayusculas) para confirmar, o ENTER para cancelar:'
    'confirm.typery' = 'Escribe DESACER para deshacer todos los cambios:'
    'run.title'      = 'Ejecutando'
    'run.done'       = 'Completado'
    'run.undo'       = 'Para deshacer todo:  sparktune undo'
    'dryrun'         = 'MODO SIMULACION (--dry-run): no se aplica nada.'
    'status.title'   = 'Estado del sistema'
    'status.cpu'     = 'CPU'
    'status.ram'     = 'RAM'
    'status.disk'    = 'Discos'
    'status.gpu'     = 'GPU'
    'status.batt'    = 'Bateria'
    'status.plan'    = 'Plan de energia'
    'status.heavy'   = 'Servicios/procesos que consumen recursos'
    'undo.title'     = 'Deshacer cambios'
    'undo.none'      = 'No hay cambios registrados.'
    'undo.list'      = 'Cambios en el journal (arriba = mas antiguo):'
    'analyze.title'  = 'Analisis de espacio (informativo, no borra nada)'
    'history.title'  = 'Historial de cambios (journal)'
    'history.none'   = 'No hay cambios registrados.'
    'history.line'   = 'Journal'
    'doctor.title'   = 'Doctor: comprobaciones de salud y consistencia'
    'doctor.clean'   = 'Todo en orden. Sin avisos.'
    'doctor.issues'  = 'Avisos encontrados:'
    'power.title'    = 'Planes de energia SparkTune'
    'battery.title'  = 'Informe de bateria'
    'hw.detect'      = 'Detectando hardware'
    'hw.ram'         = 'RAM'
    'hw.disk'        = 'Disco'
    'hw.gpu'         = 'GPU'
    'hw.batt'        = 'Bateria'
    'hw.os'          = 'Sistema'
    'hw.noapply'     = 'no aplica'
    'card.na'        = 'no disponible en simulacion'
    'apply.ok'       = 'OK'
    'apply.fail'     = 'ERROR'
    'apply.skip'     = 'omitido'
    'admin.need'     = 'Esta accion requiere administradora. Ejecuta la terminal como admin o omite la accion.'
    'rp.title'       = 'Punto de restauracion'
    'rp.create'      = 'Crear punto de restauracion antes de aplicar? (s/n)'
    'rp.done'        = 'Punto de restauracion creado.'
    'rp.fail'        = 'No se pudo crear el punto de restauracion.'
    'rp.nofeature'   = 'La restauracion de sistema esta deshabilitada. Recomendado habilitarla para cambios de registro.'
    'nav.updown'     = 'Sube/Baja'
    'nav.space'      = 'Seleccionar'
    'nav.enter'      = 'Aceptar'
    'nav.esc'        = 'Volver'
    'nav.f'          = 'Ficha'
    'nav.a'          = 'Marcar/desmarcar TODO (A o E)'
    'nav.quit'       = 'Salir'
}
$script:ST_EN = @{
    'catalog.valid' = 'Valid catalog: {0} actions.'
    'catalog.unknown' = 'Unknown action: {0}. See sparktune acciones.'
    'catalog.incompatible' = 'Action incompatible with this PC: {0}.'
    'app.tagline'    = 'Windows optimization'
    'app.by'         = 'by @josemidev1'
    'menu.title'     = 'What do you want to optimize?'
    'menu.level'     = 'What level?'
    'lvl.suave'      = 'Gentle    (safe, conservative changes only)'
    'lvl.medio'      = 'Medium    (perf/stability balance)'
    'lvl.agresivo'   = 'Aggressive(max gains, read every card)'
    'prof.gaming'    = 'Gaming'
    'prof.ofimatica' = 'Office / Productivity'
    'prof.portatil-ahorro' = 'Laptop - Battery saver'
    'prof.portatil-rendimiento' = 'Laptop - Performance (plugged in)'
    'prof.limpieza'  = 'Disk cleanup'
    'prof.bajos-recursos' = 'Low resources (old PC)'
    'prof.red-privacidad' = 'Network & privacy'
    'prof.creativo' = 'Creative / Editing (photo, video, 3D)'
    'prof.desarrollo' = 'Development (IDEs, WSL, builds)'
    'prof.personalizado' = 'Custom (pick yourself)'
    'prof.custom'    = 'Custom'
    'list.title'     = 'Available actions (filtered by HW/profile). Space=toggle Enter=continue F=card Esc=back'
    'list.empty'     = 'No actions apply to this hardware/profile.'
    'card.title'     = 'Card'
    'card.desc'      = 'What it does'
    'card.why'       = 'Why / warning'
    'card.cur'       = 'Current -> Proposed'
    'card.risk'      = 'Risk'
    'ai.goalLength'  = 'The objective must be 500 characters or fewer.'
    'ai.invalidLevel'= 'Use --nivel=suave|medio|agresivo with a specific profile.'
    'ai.missingKey'  = 'Set GROQ_API_KEY or OPENAI_API_KEY in this terminal or run sparktune ai --dry-run to preview the context.'
    'ai.noCandidates'= 'No compatible reversible actions. Check the profile or try again without that filter.'
    'ai.httpError'   = 'The AI provider returned HTTP {0}. Check your key, model access and API quota.'
    'ai.networkError'= 'Could not connect to the AI provider. Check your connection and try again.'
    'ai.noResponse'  = 'The model did not return recommendations in the expected format.'
    'ai.restart'     = 'Requires a restart.'
    'ai.noRecommendations' = 'The model found no recommendations for this objective.'
    'card.rev'       = 'Reversible'
    'card.reboot'    = 'Needs reboot'
    'card.admin'     = 'Needs admin'
    'card.executed'  = 'EXECUTED'
    'yes'='yes'; 'no'='no'
    'risk.sin'='none'; 'risk.bajo'='low'; 'risk.medio'='MEDIUM'; 'risk.alto'='HIGH'
    'confirm.all'    = 'Apply the {0} selected actions? (y/n)'
    'confirm.one'    = 'Apply this action? (y/n/e=edit card)'
    'confirm.type'   = 'HIGH RISK ACTION. Type YES (uppercase) to confirm, ENTER to cancel:'
    'confirm.typery' = 'Type UNDO to revert all changes:'
    'run.title'      = 'Running'
    'run.done'       = 'Done'
    'run.undo'       = 'To revert everything:  sparktune undo'
    'dryrun'         = 'DRY-RUN mode (--dry-run): nothing is applied.'
    'status.title'   = 'System status'
    'status.cpu'     = 'CPU'
    'status.ram'     = 'RAM'
    'status.disk'    = 'Disks'
    'status.gpu'     = 'GPU'
    'status.batt'    = 'Battery'
    'status.plan'    = 'Power plan'
    'status.heavy'   = 'Heavy services/processes'
    'undo.title'     = 'Undo changes'
    'undo.none'      = 'No recorded changes.'
    'undo.list'      = 'Journal entries (top = oldest):'
    'analyze.title'  = 'Space analysis (read-only, deletes nothing)'
    'history.title'  = 'Change history (journal)'
    'history.none'   = 'No recorded changes.'
    'history.line'   = 'Journal'
    'doctor.title'   = 'Doctor: health and consistency checks'
    'doctor.clean'   = 'All good. No warnings.'
    'doctor.issues'  = 'Warnings found:'
    'power.title'    = 'SparkTune power plans'
    'battery.title'  = 'Battery report'
    'hw.detect'      = 'Detecting hardware'
    'hw.ram'         = 'RAM'
    'hw.disk'        = 'Disk'
    'hw.gpu'         = 'GPU'
    'hw.batt'        = 'Battery'
    'hw.os'          = 'OS'
    'hw.noapply'     = 'not applicable'
    'card.na'        = 'not available in simulation'
    'apply.ok'       = 'OK'
    'apply.fail'     = 'ERROR'
    'apply.skip'     = 'skipped'
    'admin.need'     = 'This action needs administrator rights. Run the terminal as admin or skip it.'
    'rp.title'       = 'Restore point'
    'rp.create'      = 'Create a restore point before applying? (y/n)'
    'rp.done'        = 'Restore point created.'
    'rp.fail'        = 'Could not create restore point.'
    'rp.nofeature'   = 'System Restore is disabled. Recommended to enable it for registry changes.'
    'nav.updown'     = 'Up/Down'
    'nav.space'      = 'Toggle'
    'nav.enter'      = 'Accept'
    'nav.esc'        = 'Back'
    'nav.f'          = 'Card'
    'nav.a'          = 'Toggle ALL (A or E)'
    'nav.quit'       = 'Quit'
}
function Set-STLang([string]$Lang) {
    $Global:STLang = $Lang
    if ($Lang -eq 'en') { $script:ST = $script:ST_EN } else { $script:ST = $script:ST_ES }
}
function T([string]$Key) {
    if ($script:ST.ContainsKey($Key)) { return $script:ST[$Key] }
    if ($script:ST_ES.ContainsKey($Key)) { return $script:ST_ES[$Key] }
    return $Key
}
function TF([string]$Key, [array]$Args2) {
    $s = T $Key
    try { return [string]::Format($s, $Args2) } catch { return $s }
}
# campo bilingue del catalogo: titulo/titulo_en segun idioma
function STField($Action, [string]$Name) {
    if ($Global:STLang -eq 'en') {
        $alt = "$($Name)_en"
        if ($Action.ContainsKey($alt) -and $Action[$alt]) { return $Action[$alt] }
    }
    return $Action[$Name]
}

# ---------- help ----------
function Show-STIntroduction {
    $en = $Global:STLang -eq 'en'
    if ($en) {
        Write-STLine '  SparkTune sets up and tunes your Windows PC from the terminal.'
        Write-STLine '  Choose apps, Windows settings and power plans before applying changes.'
        Write-STLine '  To get AI advice, open sparktune setup and describe your situation.'
        Write-STLine '  For settings that need it, the wizard offers a Windows restore point'
        Write-STLine '  when System Protection is available. Creating one requires admin rights.'
    } else {
        Write-STLine '  SparkTune prepara y optimiza tu PC con Windows desde la terminal.'
        Write-STLine '  Elige las aplicaciones, los ajustes y el plan de energía antes de aplicar.'
        Write-STLine '  Para empezar con IA, abre sparktune preparar y cuéntale tu situación.'
        Write-STLine '  Si un ajuste lo requiere, el asistente ofrece crear un punto de restauración'
        Write-STLine '  cuando Windows lo permite. Crearlo requiere permisos de administrador.'
    }
}

function Show-STHelp([string]$Topic, [switch]$SkipIntroduction) {
    $en = $Global:STLang -eq 'en'
    $title = if ($en) { 'Quick help' } else { 'Ayuda rápida' }
    $rows = @(
        @{ id='setup';    es='preparar';   en='setup';    desc='Prepara un PC por perfil';           descEn='Set up a PC by profile' }
        @{ id='wizard';   es='optimizar';  en='wizard';   desc='Elige qué ajustes de Windows aplicar'; descEn='Choose which Windows settings to apply' }
        @{ id='apps';     es='apps';       en='apps';     desc='Instala o actualiza aplicaciones';   descEn='Install or update apps' }
        @{ id='power';    es='energia';    en='power';    desc='Elige un plan de energía';           descEn='Choose a power plan' }
        @{ id='ai';       es='ia';         en='ai';       desc='Pide recomendaciones a la IA';      descEn='Ask AI for recommendations' }
        @{ id='status';   es='estado';     en='status';   desc='Consulta CPU, RAM, discos y GPU';    descEn='Check CPU, RAM, drives and GPU' }
        @{ id='battery';  es='bateria';    en='battery';  desc='Consulta el estado de la batería';   descEn='Check battery health' }
        @{ id='analyze';  es='espacio';    en='analyze';  desc='Mira qué ocupa espacio';             descEn='See what takes up disk space' }
        @{ id='history';  es='historial';  en='history';  desc='Consulta los cambios aplicados';     descEn='See applied changes' }
        @{ id='undo';     es='deshacer';   en='undo';     desc='Restaura cambios reversibles';       descEn='Revert supported changes' }
        @{ id='acciones'; es='acciones';  en='acciones'; desc='Lista los ajustes del catálogo';     descEn='List catalog settings' }
        @{ id='ejecutar'; es='ejecutar';  en='ejecutar'; desc='Aplica un ajuste por su ID';         descEn='Apply a setting by ID' }
        @{ id='validar';  es='validar';   en='validar';  desc='Comprueba el catálogo o un plan';    descEn='Validate a catalog or plan' }
        @{ id='doctor';   es='doctor';    en='doctor';   desc='Comprueba el sistema y el historial'; descEn='Check the system and history' }
        @{ id='report';   es='informe';   en='report';   desc='Exporta un informe HTML';            descEn='Export an HTML report' }
        @{ id='banner';   es='banner';    en='banner';   desc='Reproduce la intro';                descEn='Play the intro' }
        @{ id='version';  es='version';   en='version';  desc='Muestra la versión instalada';      descEn='Show the installed version' }
    )
    $lang = if ($en) { 'en' } else { 'es' }
    $description = if ($en) { 'descEn' } else { 'desc' }
    $help = if ($en) { 'help' } else { 'ayuda' }
    $prepare = if ($en) { 'setup' } else { 'preparar' }
    $simulate = if ($en) { '--dry-run' } else { '--simular' }
    if (-not $Topic -or $Topic -eq 'help') {
        Write-STHeader -Title $title -Detail "v$Global:STVersion"
        if (-not $SkipIntroduction) { Show-STIntroduction }
        for ($i = 0; $i -lt $rows.Count; $i++) {
            switch ($i) {
                0  { Write-STSection $(if ($en) { 'Set up and tune' } else { 'Preparar y optimizar' }) }
                5  { Write-STSection $(if ($en) { 'Check and revert' } else { 'Consultar y deshacer' }) }
                10 { Write-STSection $(if ($en) { 'More commands' } else { 'Más comandos' }) }
            }
            $row = $rows[$i]
            Write-STLine ('  {0,-22} {1}' -f "sparktune $($row[$lang])", $row[$description])
        }
        Write-STLine ''
        Write-STInfo "sparktune $prepare desarrollo $simulate"
        if ($en) {
            Write-STLine '  See examples for a command with sparktune help setup.'
            Write-STLine '  Español   sparktune ayuda --lang=es   |   sparktune --set-lang=es'
        } else {
            Write-STLine '  Más ejemplos con sparktune ayuda preparar.'
            Write-STLine '  English   sparktune help --lang=en    |   sparktune --set-lang=en'
        }
        return
    }

    $row = $rows | Where-Object { $_.id -eq $Topic }
    $command = "sparktune $($row[$lang])"
    Write-STHeader -Title $command -Detail $row[$description]
    $examples = switch ($Topic) {
        'setup' {
            "$command desarrollo $simulate"
            "$command gaming"
            if ($en) {
                "$command --goal=`"Save battery`""
                "$command desarrollo --save-plan=plan.json"
                "$command --load-plan=plan.json $simulate"
            } else {
                "$command --objetivo=`"Ahorrar batería`""
                "$command desarrollo --guardar-plan=plan.json"
                "$command --cargar-plan=plan.json $simulate"
                'Perfiles disponibles  desarrollo, gaming, ofimatica, video-adobe y video-libre'
            }
        }
        'wizard' {
            "$command --perfil=gaming --nivel=medio $simulate"
            if ($en) { 'The wizard offers a restore point before settings that need it.' }
            else { 'El asistente ofrece crear un punto de restauración si algún ajuste lo requiere.' }
        }
        'apps' {
            "$command --install=vlc $simulate"
            "$command --install=vlc"
            "$command --update=vlc"
        }
        'ai' {
            $goal = if ($en) { 'Save battery' } else { 'Ahorrar batería' }
            "$command `"$goal`" $simulate"
            "$command `"$goal`""
        }
        'undo' { "$command $simulate"; "$command --id=setup.file-extensions" }
        'report' { "$command --out=informe.html" }
        'validar' { "$command --cargar-plan=plan.json" }
        'acciones' { "$command --json" }
        'ejecutar' { "$command --id=setup.file-extensions $simulate" }
    }
    Write-STLine "  $command"
    foreach ($example in $examples) { Write-STLine "  $example" }
    Write-STLine ''
    Write-STInfo "sparktune $help"
}

# ---------- input teclado ----------
function Read-STKey {
    param([switch]$Block)
    # devuelve objeto con Character/Key; ESC lo detecta por tiempo
    if (-not $script:STConsole) {
        $k = Read-Host
        return [pscustomobject]@{ Ch = $(if ($k) { $k[0] } else { [char]13 }); Key = 'Enter' }
    }
    $ki = [Console]::ReadKey($true)
    $c = $ki.KeyChar
    $ck = "$($ki.Key)"
    switch ($ck) {
        'UpArrow'    { return [pscustomobject]@{ Ch = [char]0; Key = 'Up' } }
        'DownArrow'  { return [pscustomobject]@{ Ch = [char]0; Key = 'Down' } }
        'LeftArrow'  { return [pscustomobject]@{ Ch = [char]0; Key = 'Left' } }
        'RightArrow' { return [pscustomobject]@{ Ch = [char]0; Key = 'Right' } }
        'Enter'      { return [pscustomobject]@{ Ch = [char]13; Key = 'Enter' } }
        'Escape'     { return [pscustomobject]@{ Ch = [char]27; Key = 'Esc' } }
        'Spacebar'   { return [pscustomobject]@{ Ch = ' '; Key = 'Space' } }
        default {
            if ($c -eq [char]27) { return [pscustomobject]@{ Ch = [char]27; Key = 'Esc' } }
            return [pscustomobject]@{ Ch = $c; Key = $ck }
        }
    }
}

function Read-STConfirm {
    param([string]$Question, [bool]$Yes = $false)
    $Yes = [bool]$Yes
    Write-STPlain "  $Question "
    if ($Yes) { Write-STLine "(pre-confirmed --yes)"; return $true }
    try { $raw = Read-Host } catch { Write-STLine ''; return $false }
    if ($null -eq $raw) { return $false }
    $ans = $raw.Trim().ToLowerInvariant()
    return ($ans -eq 's' -or $ans -eq 'y' -or $ans -eq 'si' -or $ans -eq 'yes')
}

function Read-STTypedYes {
    # confirmacion de riesgo alto: exigir SI / YES literal
    Write-STWarn (T 'confirm.type')
    try { $ans = Read-Host } catch { return $false }
    if ($null -eq $ans) { return $false }
    return ($ans -cmatch '^(SI|YES)$')
}

# ---------- barra de progreso ligera ----------
function Write-STProgress {
    param([int]$Pct, [string]$Label = '')
    if ($script:STConsole) {
        $w = 80
        try { $w = [Console]::WindowWidth } catch { }
        if ($w -lt 40) { $w = 40 }
        $inner = $w - 12
        if ($inner -lt 10) { $inner = 10 }
        $done = [int](($Pct / 100.0) * $inner); if ($done -gt $inner) { $done = $inner }
        $bar = ('#' * $done).PadRight($inner, '-')
        $txt = "  [$bar] $($Pct.ToString().PadLeft(3))% $Label"
        $txt = $txt.Substring(0, [Math]::Min($txt.Length, $w - 1))
        [Console]::Write("`r$txt")
        if ($Pct -ge 100) { [Console]::Write("`n") }
    } else {
        Write-Host "`r  [$Pct%] $Label" -NoNewline
    }
}
