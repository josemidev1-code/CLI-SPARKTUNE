# Pruebas del comando ai mediante la CLI, con la API simulada.
param([switch]$ShowSetupExample)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$entry = Join-Path $root 'sparktune.ps1'
$testHome = Join-Path ([IO.Path]::GetTempPath()) ('sparktune-ai-' + [guid]::NewGuid().ToString('N'))
$oldProfile = $env:USERPROFILE
$oldKey = $env:OPENAI_API_KEY
$oldGroq = $env:GROQ_API_KEY
$oldModel = $env:SPARKTUNE_AI_MODEL
$mock = @{ Calls = 0; Reply = 'normal'; LastRequest = $null; LastHttp = $null; Chosen = $null }

function Assert-AI([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-RestMethod {
    param(
        [uri]$Uri, [string]$Method, [switch]$UseBasicParsing, [hashtable]$Headers,
        [string]$ContentType, [byte[]]$Body, [int]$TimeoutSec, [int]$MaximumRedirection
    )
    $mock.Calls++
    $mock.LastRequest = ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString($Body))
    $mock.LastHttp = @{ Uri = $Uri.AbsoluteUri; Method = $Method; Authorization = $Headers.Authorization }
    if ($mock.Reply -eq 'http-error') { throw 'PRIVATE-API-DETAIL' }
    $groq = $Uri.Host -eq 'api.groq.com'
    $format = if ($groq) { $mock.LastRequest.response_format.json_schema } else { $mock.LastRequest.text.format }
    if ($format.name -eq 'sparktune_setup') {
        $advice = @{
            profile = if ($mock.Reply -eq 'bad-profile') { 'inventado' } else { 'desarrollo' }
            plan = switch ($mock.Reply) {
                'bad-plan' { 'power.restore-defaults' }
                'startup'  { 'spark-ahorro' }
                default    { 'ninguno' }
            }
            apps = $true
            tweaks = $false
            reason = if ($mock.Reply -eq 'startup') {
                'Te propongo el perfil de programación y el plan Ahorro para priorizar la batería.'
            } else { "Propuesta de programación. $([char]27)CONTROL" }
        }
    } else {
        $mock.Chosen = @($format.schema.properties.recommendations.items.properties.id.enum)[0]
        $advice = @{
            recommendations = @(
                @{ id = 'unknown.fake'; reason = 'INVALID ADVICE' }
                @{ id = $mock.Chosen; reason = "Mejora sugerida. $([char]27)CONTROL" }
                @{ id = $mock.Chosen; reason = 'DUPLICATE ADVICE' }
            )
        }
    }
    if ($groq) {
        $json = ConvertTo-Json -InputObject $advice -Depth 5 -Compress
        $reason = if ($mock.Reply -eq 'refusal') { 'length' } else { 'stop' }
        return [pscustomobject]@{ choices = @([pscustomobject]@{
            finish_reason = $reason
            message = [pscustomobject]@{ content = $json }
        }) }
    }
    $content = if ($mock.Reply -eq 'refusal') {
        @{ type = 'refusal'; refusal = 'No puedo responder.' }
    } else {
        @{ type = 'output_text'; text = (ConvertTo-Json -InputObject $advice -Depth 5 -Compress) }
    }
    [pscustomobject]@{
        status = 'completed'
        output = @(
            [pscustomobject]@{ type = 'reasoning' }
            [pscustomobject]@{ type = 'message'; content = @([pscustomobject]$content) }
        )
    }
}

try {
    New-Item -ItemType Directory -Path $testHome | Out-Null
    $env:USERPROFILE = $testHome
    $env:OPENAI_API_KEY = $null
    $env:GROQ_API_KEY = $null
    $env:SPARKTUNE_AI_MODEL = 'mock-model'

    $goal = 'Batería = más duración'
    $preview = & $entry ai "--objetivo=$goal" --dry-run
    Assert-AI ($LASTEXITCODE -eq 0) 'El modo simulación retornó un código de error.'
    $context = ConvertFrom-Json -InputObject ($preview -join "`n")
    Assert-AI ($mock.Calls -eq 0) 'El modo simulación llamó a la API.'
    Assert-AI ($context.goal -ceq $goal) 'Se perdió parte del objetivo.'
    Assert-AI ($context.candidates.Count -gt 0) 'No hay candidatos en la simulación.'
    Assert-AI (@($context.candidates | Where-Object { $_.risk -eq 'alto' }).Count -eq 0) 'Se envió una acción de riesgo alto.'
    $hardwareKeys = @($context.hardware.PSObject.Properties.Name)
    Assert-AI (($hardwareKeys -join ',') -ceq 'windows_build,cpu_cores,ram_gb,has_ssd,has_hdd,system_drive_free_gb,system_drive_total_gb,has_discrete_gpu,has_battery') 'Cambió el contexto de hardware.'
    Assert-AI (-not (Test-Path -LiteralPath (Join-Path $testHome '.sparktune/journal.json'))) 'Se escribió el historial.'

    $missing = (& $entry ai --lang=es 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 1 -and $missing -match 'OPENAI_API_KEY' -and $mock.Calls -eq 0) 'La clave ausente no se manejó bien.'

    $env:OPENAI_API_KEY = 'mock-secret'
    $answer = (& $entry ai "--goal=$goal" --perfil=gaming --nivel=suave --lang=en 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 0 -and $null -ne $mock.LastRequest) "La solicitud simulada no se registró. Salida: $answer"
    $requestContext = ConvertFrom-Json -InputObject $mock.LastRequest.input
    Assert-AI ($mock.Calls -eq 1 -and $mock.LastHttp.Uri -eq 'https://api.openai.com/v1/responses' -and $mock.LastHttp.Method -eq 'Post') 'Solicitud enviada al destino incorrecto.'
    Assert-AI ($mock.LastHttp.Authorization -ceq 'Bearer mock-secret' -and $mock.LastRequest.model -eq 'mock-model') 'Clave o modelo incorrectos.'
    Assert-AI ($mock.LastRequest.store -eq $false -and $mock.LastRequest.text.format.strict) 'La solicitud cambió sus opciones.'
    Assert-AI ($mock.LastRequest.instructions -match 'English' -and $requestContext.goal -ceq $goal) 'Idioma u objetivo incorrectos.'
    Assert-AI ($requestContext.profile -ceq 'gaming' -and $requestContext.level -ceq 'suave') 'Se perdió el filtro de perfil.'
    Assert-AI ($answer.Contains("[$($mock.Chosen)]") -and $answer.Contains('Mejora sugerida.')) 'No se mostró el consejo válido.'
    Assert-AI ($answer -notmatch 'INVALID ADVICE|DUPLICATE ADVICE|mock-secret') 'Se mostró contenido descartado.'
    Assert-AI (-not $answer.Contains("$([char]27)CONTROL")) 'Se imprimió una secuencia de control de la respuesta.'

    $mock.Reply = 'refusal'
    $refused = (& $entry ai --lang=es 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 1 -and $refused -match 'formato esperado') 'No se manejó la respuesta sin recomendaciones.'

    $mock.Reply = 'http-error'
    $errorText = (& $entry ai --lang=es 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 1 -and $errorText -match 'No se pudo conectar' -and $errorText -notmatch 'PRIVATE-API-DETAIL') 'No se manejó el fallo de red.'
    Assert-AI (-not (Test-Path -LiteralPath (Join-Path $testHome '.sparktune/journal.json'))) 'El comando ai escribió el historial.'

    $calls = $mock.Calls
    $preview = & $entry setup "--objetivo=$goal" --sin-apps --dry-run
    $context = ConvertFrom-Json -InputObject ($preview -join "`n")
    Assert-AI ($LASTEXITCODE -eq 0 -and $mock.Calls -eq $calls -and $context.goal -ceq $goal) 'setup dry-run debe mostrar el contexto sin llamar a la API.'
    Assert-AI (-not $context.apps_allowed -and @($context.profiles | Where-Object { $_.apps.Count }).Count -eq 0) 'setup dry-run incluyó apps que se pidieron omitir.'

    $mock.Reply = 'normal'
    $setup = (& $entry setup "--objetivo=$goal" --sin-apps --lang=es 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 0 -and $mock.Calls -eq ($calls + 1) -and $setup -match 'Programación \[desarrollo\]') 'setup no usó el perfil elegido en la respuesta.'
    Assert-AI ($setup -notmatch 'Visual Studio Code|SparkTune Equilibrado|setup.start-suggestions|mock-secret' -and -not $setup.Contains("$([char]27)CONTROL")) 'setup mostró un cambio omitido o texto de control.'
    if ($ShowSetupExample) {
        Write-Host "> sparktune setup '--objetivo=$goal' --sin-apps"
        Write-Host $setup
    }
    $props = $mock.LastRequest.text.format.schema.properties
    Assert-AI ($props.profile.enum -ccontains 'desarrollo' -and $props.plan.enum -ccontains 'ninguno' -and $props.plan.enum -cnotcontains 'restore-defaults') 'La consulta de setup admite opciones incorrectas.'

    foreach ($mockReply in @('bad-profile','bad-plan')) {
        $mock.Reply = $mockReply
        $rejected = (& $entry setup "--objetivo=$goal" --lang=es 6>&1) -join "`n"
        Assert-AI ($LASTEXITCODE -eq 1 -and $rejected -match 'formato esperado' -and $rejected -match 'sin IA') 'setup no rechazó una opción ajena al catálogo.'
    }
    $calls = $mock.Calls
    $null = & $entry setup "--objetivo=$goal" --yes
    Assert-AI ($LASTEXITCODE -eq 2 -and $mock.Calls -eq $calls) 'setup aceptó --yes para una recomendación de IA.'
    Assert-AI (-not (Test-Path -LiteralPath (Join-Path $testHome '.sparktune/journal.json'))) 'setup con IA escribió el historial sin aplicar ajustes.'

    $env:GROQ_API_KEY = 'groq-test-secret'
    $env:OPENAI_API_KEY = $null
    $mock.Reply = 'normal'
    $proposal = (& $entry setup "--objetivo=$goal" --sin-apps --lang=es 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 0 -and $proposal -match '\[desarrollo\]' -and $proposal -notmatch 'groq-test-secret') 'La propuesta de Groq no se mostró correctamente.'
    $request = $mock.LastRequest
    $context = ConvertFrom-Json -InputObject $request.messages[1].content
    Assert-AI ($mock.LastHttp.Uri -eq 'https://api.groq.com/openai/v1/chat/completions' -and $mock.LastHttp.Authorization -ceq 'Bearer groq-test-secret') 'La solicitud Groq tiene destino o autenticación incorrectos.'
    Assert-AI ($request.model -ceq 'openai/gpt-oss-20b' -and $request.response_format.json_schema.strict -and $context.goal -ceq $goal -and -not $context.apps_allowed) 'Groq perdió el modelo, el esquema o el objetivo.'
    $mock.Reply = 'bad-plan'
    $rejected = (& $entry setup "--objetivo=$goal" --lang=es 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 1 -and $rejected -match 'formato esperado') 'SparkTune aceptó un plan inválido de Groq.'
    $mock.Reply = 'normal'
    $advice = (& $entry ai "--objetivo=$goal" --lang=es 6>&1) -join "`n"
    Assert-AI ($LASTEXITCODE -eq 0 -and $advice -match 'Mejora sugerida' -and $advice -notmatch 'INVALID ADVICE') 'El asesor de Groq no filtró las recomendaciones.'

    foreach ($module in @('globals','ui','engine','catalog','ai','setup')) {
        . (Join-Path $root "src/core/$module.ps1")
    }
    $script:STConsole = $false
    Set-STLang 'es'
    function Get-STHardware { return @{ IsLaptop=$true; Battery=$true; Plugged=$false; Build=22631 } }
    function Read-Host([string]$Prompt) {
        $mock.Prompts++
        Write-Host "$($Prompt): $($mock.Goal)"
        return $mock.Goal
    }
    function Install-STWingetApp { throw 'El inicio intentó instalar una app.' }
    function Invoke-STApply { throw 'El inicio intentó aplicar un ajuste.' }
    $mock.Prompts = 0
    $mock.Goal = ''
    $calls = $mock.Calls
    $env:GROQ_API_KEY = $null
    $noKey = (@(Invoke-STStartup -Interactive 6>&1) -join [Environment]::NewLine)
    Assert-AI ($noKey -match 'sparktune preparar' -and $mock.Prompts -eq 0 -and $mock.Calls -eq $calls) 'El inicio sin clave pidió texto o llamó a la API.'

    $env:GROQ_API_KEY = 'groq-test-secret'
    $redirected = (@(Invoke-STStartup 6>&1) -join [Environment]::NewLine)
    Assert-AI ($redirected -match 'sparktune preparar' -and $mock.Prompts -eq 0 -and $mock.Calls -eq $calls) 'El inicio redirigido intentó leer texto o llamó a la API.'
    $skipped = (@(Invoke-STStartup -Interactive 6>&1) -join [Environment]::NewLine)
    Assert-AI ($skipped -match 'Enter para saltar' -and $skipped -match 'sparktune ayuda' -and $mock.Prompts -eq 1 -and $mock.Calls -eq $calls) 'Pulsar Enter no mostró la guía sin consultar a la IA.'

    $mock.Goal = 'Programo en mi portátil y quiero que la batería dure más'
    $mock.Reply = 'startup'
    $startupResult = @(Invoke-STStartup -Interactive 6>&1)
    Assert-AI ($startupResult[-1] -eq 0) 'El inicio con IA falló.'
    $startup = ($startupResult | Select-Object -SkipLast 1) -join [Environment]::NewLine
    $context = ConvertFrom-Json -InputObject $mock.LastRequest.messages[1].content
    Assert-AI ($mock.Prompts -eq 2 -and $mock.Calls -eq ($calls + 1) -and $context.goal -ceq $mock.Goal) 'El inicio no envió la situación descrita.'
    Assert-AI ($startup -match 'se enviarán a Groq' -and $startup -match 'priorizar la batería' -and $startup -match 'Visual Studio Code' -and $startup -match 'spark-ahorro') 'El inicio no mostró el aviso o el plan esperado.'
    Assert-AI (-not (Test-Path -LiteralPath (Join-Path $testHome '.sparktune/journal.json'))) 'El inicio con IA alteró el historial.'
    if ($ShowSetupExample) {
        Write-Host 'Inicio interactivo con respuesta simulada'
        Write-Host $startup
    }

    Write-Host 'AI advisor tests OK'
} finally {
    $env:USERPROFILE = $oldProfile
    $env:OPENAI_API_KEY = $oldKey
    $env:GROQ_API_KEY = $oldGroq
    $env:SPARKTUNE_AI_MODEL = $oldModel
    if (Test-Path -LiteralPath $testHome) { Remove-Item -LiteralPath $testHome -Recurse -Force }
}
exit 0
