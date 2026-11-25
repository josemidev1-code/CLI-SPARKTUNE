# SparkTune journal.ps1 — ~/.sparktune/journal.json : registro de cambios con undo y estado previo.
# Escritura atomica: .tmp + Move-Item -Force.

function Read-STJournal {
    if (-not (Test-Path $Global:STJournalPath)) { return @() }
    try {
        $txt = Get-Content -LiteralPath $Global:STJournalPath -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($txt)) { throw 'archivo vacio' }
        $obj = $txt | ConvertFrom-Json -ErrorAction Stop
        if ($obj -is [array]) { return @($obj) }
        if ($null -ne $obj -and ($obj.PSObject.Properties.Name -contains 'entries') -and $obj.entries -is [array]) { return @($obj.entries) }
        throw 'formato de entradas invalido'
    } catch {
        throw "No se puede leer el historial $($Global:STJournalPath): $($_.Exception.Message). No se modificara; restaura una copia antes de continuar."
    }
}

function Write-STJournal([array]$Entries) {
    $tmp = "$Global:STJournalPath.tmp"
    $doc = [pscustomobject]@{
        version   = 1
        updatedAt = (Get-Date).ToString('o')
        entries   = @($Entries)
    }
    $json = ConvertTo-Json $doc -Depth 10
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -Path $tmp -Destination $Global:STJournalPath -Force
}

function Add-STJournalEntry {
    param($Action, [string]$Status, [string]$Detail = '', [string]$PrevState = '')
    $entries = @(Read-STJournal)
    $e = [ordered]@{
        seq       = [guid]::NewGuid().ToString('N')
        id        = $Action.id
        titulo    = (STField $Action 'titulo')
        categoria = $Action.categoria
        status    = $Status          # applied | undo | failed | dryrun
        prevState = $PrevState
        detail    = $Detail
        reversible= [bool]$Action.reversible
        undoCmd   = $(try { [string]$Action.undoCmd } catch { '' })
    }
    $entries += [pscustomobject]$e
    Write-STJournal $entries
}

function Get-STJournalPending {
    # entradas aplicadas y no deshechas, en orden de aplicacion
    $entries = @(Read-STJournal)
    $undoneKeys = @{}
    foreach ($e in $entries) {
        if ($e.status -eq 'undo' -and $e.refSeq) { $undoneKeys["$($e.refSeq)"] = $true }
    }
    $out = @()
    foreach ($e in $entries) {
        if ($e.status -eq 'applied' -and -not $undoneKeys["$($e.seq)"]) { $out += $e }
    }
    return $out
}

function Mark-STJournalUndone([string]$Seq) {
    $entries = @(Read-STJournal)
    $entries += [pscustomobject]@{
        seq    = [guid]::NewGuid().ToString('N')
        refSeq = $Seq
        id     = ''
        status = 'undo'
        detail = ''
    }
    Write-STJournal $entries
}

function Clear-STJournal {
    if (Test-Path $Global:STJournalPath) { Remove-Item $Global:STJournalPath -Force }
}
