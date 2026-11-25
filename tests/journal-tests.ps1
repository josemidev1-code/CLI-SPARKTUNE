$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\core\journal.ps1')
function STField($a, $field) { return $a[$field] }
$dir = Join-Path ([IO.Path]::GetTempPath()) ('sparktune-journal-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$Global:STJournalPath = Join-Path $dir 'journal.json'
try {
    $a = @{ id='test'; titulo='Prueba'; categoria='test'; reversible=$true; undoCmd='' }
    Add-STJournalEntry -Action $a -Status applied
    Add-STJournalEntry -Action $a -Status applied
    $entries = @(Read-STJournal)
    if ($entries.Count -ne 2 -or $entries[0].seq -eq $entries[1].seq) { throw 'IDs de historial duplicados' }
    Mark-STJournalUndone $entries[0].seq
    $pending = @(Get-STJournalPending)
    if ($pending.Count -ne 1 -or $pending[0].seq -ne $entries[1].seq) { throw 'undo marco entradas incorrectas' }
    $broken = '{"entries":['
    [IO.File]::WriteAllText($Global:STJournalPath, $broken)
    $failed = $false
    try { Add-STJournalEntry -Action $a -Status applied } catch { $failed = $true }
    if (-not $failed -or [IO.File]::ReadAllText($Global:STJournalPath) -cne $broken) { throw 'historial roto fue sobrescrito' }
    Write-Host 'Historial: OK'
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force
}
