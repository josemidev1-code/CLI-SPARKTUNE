# Pruebas del comando ai mediante la CLI, con la API simulada.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$entry = Join-Path $root 'sparktune.ps1'
$testHome = Join-Path ([IO.Path]::GetTempPath()) ('sparktune-ai-' + [guid]::NewGuid().ToString('N'))
$oldProfile = $env:USERPROFILE
$oldKey = $env:OPENAI_API_KEY
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
    $mock.Chosen = @($mock.LastRequest.text.format.schema.properties.recommendations.items.properties.id.enum)[0]
    if ($mock.Reply -eq 'http-error') { throw 'PRIVATE-API-DETAIL' }
    $advice = @{
        recommendations = @(
            @{ id = 'unknown.fake'; reason = 'INVALID ADVICE' }
            @{ id = $mock.Chosen; reason = "Mejora sugerida. $([char]27)CONTROL" }
            @{ id = $mock.Chosen; reason = 'DUPLICATE ADVICE' }
        )
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
    $env:SPARKTUNE_AI_MODEL = 'mock-model'

    $goal = 'Batería = más duración'
    $preview = & $entry ai "--objetivo=$goal" --dry-run
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
    Assert-AI ($null -ne $mock.LastRequest) "La solicitud simulada no se registró. Salida: $answer"
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

    Write-Host 'AI advisor tests OK'
} finally {
    $env:USERPROFILE = $oldProfile
    $env:OPENAI_API_KEY = $oldKey
    $env:SPARKTUNE_AI_MODEL = $oldModel
    if (Test-Path -LiteralPath $testHome) { Remove-Item -LiteralPath $testHome -Recurse -Force }
}
