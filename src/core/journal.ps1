# SparkTune journal.ps1 — ~/.sparktune/journal.json : registro de cambios con undo y estado previo.
# Escritura atomica: .tmp + Move-Item -Force.

function Read-STJournal {
    if (-not (Test-Path $Global:STJournalPath)) { return @() }
    try {
        $txt = Get-Content -Path $Global:STJournalPath -Raw -Encoding UTF8
        if (-not $txt) { return @() }
        $obj = $txt | ConvertFrom-Json
        if ($obj.entries) { return @($obj.entries) }
        if ($obj -is [array]) { return @($obj) }
        return @()
    } catch {
        try {
            Copy-Item $Global:STJournalPath "$($Global:STJournalPath).bad.$(Get-Date -Format yyyyMMddHHmmss)" -Force
        } catch { }
        return @()
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
        seq       = [DateTime]::Now.ToString('yyyyMMddHHmmssfff')
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
        seq    = [DateTime]::Now.ToString('yyyyMMddHHmmssfff')
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
