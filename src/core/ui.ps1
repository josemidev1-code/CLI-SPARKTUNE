# SparkTune ui.ps1 — colores ANSI, diccionario ES/EN, menus, fichas, confirmaciones.
# Cargado por sparktune.ps1. Solo cmdlets PS 5.1 + ReadKey + VT.

# ---------- consola / ANSI ----------
$script:STAnsi = $true
function Test-STConsoleUsable {
    # [Console] es un type; solo es util si hay consola real interactiva
    try {
        if (-not [Environment]::UserInteractive) { return $false }
        if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $false }
        $null = [Console]::WindowWidth
        return $true
    } catch { return $false }
}
$script:STConsole = $null
if (Test-STConsoleUsable) { try { $script:STConsole = [Console] } catch { $script:STConsole = $null } }

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
    $script:STAnsi = Test-STAnsi
    if (-not $script:STAnsi) { return }
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
            [STNat.Win32C]::SetConsoleMode($h, ($m -bor 4)) | Out-Null
        }
    } catch { $script:STAnsi = $false }
}

function STC([string]$code) {
    if (-not $script:STAnsi) { return '' }
    return "$([char]27)[${code}m"
}

$script:STColorMap = @{
    reset='0'; bold='1'; dim='2'; italic='3'
    gray='90'; red='91'; green='92'; yellow='93'; blue='94'; magenta='95'; cyan='96'; white='97'
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
    if ($script:STConsole) { $script:STConsole.Write("$pre$Text$suf`n") } else { Write-Host "$pre$Text$suf" }
}
function Write-STPlain([string]$Text) {
    if ($script:STConsole) { $script:STConsole.Write($Text) } else { Write-Host -NoNewline $Text }
}
function Write-STInfo([string]$T)  { Write-STLine "  $T" 'cyan' }
function Write-STOk([string]$T)    { Write-STLine "  $T" 'green' }
function Write-STWarn([string]$T)  { Write-STLine "  [!] $T" 'yellow' }
function Write-STErr([string]$T)   { Write-STLine "  [x] $T" 'red' }

function Clear-STScreen {
    if ($script:STConsole) { $script:STConsole.Clear() } else { Clear-Host }
}

# ---------- idioma ----------
$script:ST = @{}
$script:ST_ES = @{
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
function Show-STHelp {
    $L = $Global:STLang
    Write-STLine "SparkTune v$Global:STVersion - $(T 'app.tagline') - $(T 'app.by')" 'cyan' 'bold'
    $lines = @(
        'Uso:  sparktune [comando] [opciones]',
        '',
        '  (sin comando)          Asistente interactivo',
        '  status                 Panel: CPU, RAM, disco, GPU, bateria, plan, servicios',
        '  battery                Informe de bateria + planes recomendados',
        '  power                  Listar/crear/aplicar planes SparkTune',
        '  undo                   Deshacer cambios (--id=xxx para uno concreto)',
        '  analyze                Que ocupa espacio (no borra nada)',
        '  history                Historial de cambios del journal',
        '  apps                   Instalar apps populares via winget (menu interactivo)',
        '  apps --install=a,b     Instalar sin interactuar (ids o nombres, comma separados)',
        '  apps --update=a,b      Actualizar solo las apps indicadas',
        '',
        '  --perfil=gaming        gaming|ofimatica|limpieza|bajos-recursos|',
        '                         portatil-ahorro|portatil-rendimiento|',
        '                         red-privacidad|creativo|desarrollo|',
        '                         personalizado',
        '  --nivel=suave          suave|medio|agresivo',
        '  --yes                  Sin confirmaciones (cuidado)',
        '  --dry-run              Simulacion: muestra, no ejecuta',
        '  --lang=es|en           Idioma de esta ejecucion',
        '  --set-lang=es|en       Guarda idioma por defecto (persistente)',
        '  --set-banner=on|off    Banner de arranque por defecto',
        '  --set-nivel=medio      Nivel por defecto en el wizard (suave|medio|agresivo)',
        '  --no-banner            Sin animacion de arranque',
        '  --id=xxx               (undo) solo el cambio con ese id',
        '  --scope=user           (apps) pedir winget --scope=user',
        '  --interactive          (apps) mostrar UI de winget en vez de silencioso',
        '  (apps)                 paquetes "(p)" = winget Portable (sin instalador)',
        '',
        'Ejemplos:',
        '  sparktune',
        '  sparktune --perfil=gaming --nivel=medio --dry-run',
        '  sparktune undo',
        '  sparktune apps --install=chrome,vlc',
        '  sparktune power'
    )
    if ($L -eq 'en') {
        $lines = @(
            'Usage: sparktune [command] [options]',
            '',
            '  (no command)           Interactive wizard',
            '  status                 Dashboard: CPU, RAM, disk, GPU, battery, plan, services',
            '  battery                Battery report + recommended plans',
            '  power                  List/create/apply SparkTune power plans',
            '  undo                   Revert changes (--id=xxx for a single one)',
            '  analyze                What takes space (deletes nothing)',
            '  history                Change history from the journal',
            '  apps                   Install popular apps via winget (interactive menu)',
            '  apps --install=a,b     Non-interactive install (ids or names, comma separated)',
            '  apps --update=a,b      Update only the listed apps',
            '',
            '  --perfil=gaming        gaming|ofimatica|limpieza|bajos-recursos|',
            '                         portatil-ahorro|portatil-rendimiento|',
            '                         red-privacidad|creativo|desarrollo|',
            '                         personalizado',
            '  --nivel=suave          suave|medio|agresivo',
            '  --yes                  Skip confirmations (careful)',
            '  --dry-run              Simulation: show, do not execute',
            '  --lang=es|en           Language for this run',
            '  --set-lang=es|en       Save default language (persistent)',
            '  --set-banner=on|off    Default boot banner',
            '  --set-nivel=medio      Default wizard level (suave|medio|agresivo)',
            '  --no-banner            Skip boot animation',
            '  --id=xxx               (undo) only the change with that id',
            '  --scope=user           (apps) request winget --scope=user',
            '  --interactive          (apps) show winget UI instead of silent',
            '  (apps)                 "(p)" packages = winget Portable (no installer)',
            '',
            'Examples:',
            '  sparktune',
            '  sparktune --perfil=gaming --nivel=medio --dry-run',
            '  sparktune undo',
            '  sparktune apps --install=chrome,vlc',
            '  sparktune power'
        )
    }
    foreach ($l in $lines) { Write-STLine "  $l" }
}

# ---------- input teclado ----------
function Read-STKey {
    param([switch]$Block)
    # devuelve objeto con Character/Key; ESC lo detecta por tiempo
    if (-not $script:STConsole) {
        $k = Read-Host
        return [pscustomobject]@{ Ch = $(if ($k) { $k[0] } else { [char]13 }); Key = 'Enter' }
    }
    $ki = $script:STConsole.ReadKey($true)
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
        try { $w = $script:STConsole.WindowWidth } catch { }
        if ($w -lt 40) { $w = 40 }
        $inner = $w - 12
        if ($inner -lt 10) { $inner = 10 }
        $done = [int](($Pct / 100.0) * $inner); if ($done -gt $inner) { $done = $inner }
        $bar = ('#' * $done).PadRight($inner, '-')
        $txt = "  [$bar] $($Pct.ToString().PadLeft(3))% $Label"
        $txt = $txt.Substring(0, [Math]::Min($txt.Length, $w - 1))
        $script:STConsole.Write("`r$txt")
        if ($Pct -ge 100) { $script:STConsole.Write("`n") }
    } else {
        Write-Host "`r  [$Pct%] $Label" -NoNewline
    }
}
