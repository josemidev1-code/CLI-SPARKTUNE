# Intro ASCII. Cada cuadro reemplaza el anterior en el mismo bloque de consola.
function Show-STBanner {
    param([switch]$NoBanner)
    if ($NoBanner) { return }

    $credit = '  made by josemidev1'
    $logoFile = Join-Path $Global:STData 'figlet.txt'
    $logo = @(Get-Content -LiteralPath $logoFile -ErrorAction SilentlyContinue)
    $width = 80
    if ($script:STConsole) { try { $width = [Console]::WindowWidth } catch { } }
    $logoWidth = ($logo | Measure-Object -Property Length -Maximum).Maximum
    if (-not $logo.Count -or $width -le $logoWidth) {
        $logo = @('  * SparkTune')
        $logoWidth = $logo[0].Length
    }

    if ($script:STConsole) { Enable-STVirtualTerminal }
    if (-not $script:STConsole -or -not $script:STVtEnabled -or $width -le $credit.Length -or $env:TERM -eq 'dumb') {
        foreach ($line in $logo) { Write-Host $line }
        Write-Host $credit
        return
    }

    $esc = [char]27
    $clear = "$esc[2K"
    $up = "$esc[$($logo.Count + 1)A"
    $cyan = STC '96'
    $spark = STC '97'
    $blue = STC '94'
    $dim = STC '90'
    $gold = STC '93'
    $reset = STC '0'
    $lastFrame = 30
    $revealFrames = 18
    $first = $true

    try {
        Write-STPlain "$esc[?25l"
        for ($frame = 0; $frame -le $lastFrame; $frame++) {
            $rows = @(
                for ($row = 0; $row -lt $logo.Count; $row++) {
                    $line = $logo[$row]
                    # Offset each row so the advancing edge crosses the logo diagonally.
                    if ($frame -lt $revealFrames) {
                        $edge = [int][Math]::Floor(($logoWidth + 2 * ($logo.Count - 1)) * $frame / $revealFrames) - 2 * $row
                        $end = [Math]::Min([Math]::Max(0, $edge), $line.Length)
                        $start = [Math]::Max(0, $end - 3)
                        ($cyan + $line.Substring(0, $start) +
                            $spark + $line.Substring($start, $end - $start) + $dim +
                            ($line.Substring($end) -replace '[^ ]', '.'))
                    } elseif ($frame -lt $lastFrame) {
                        $edge = [int][Math]::Floor(($logoWidth + 10) * ($frame - $revealFrames) / ($lastFrame - $revealFrames)) - 5 + $row
                        $start = [Math]::Min([Math]::Max(0, $edge - 2), $line.Length)
                        $end = [Math]::Min([Math]::Max(0, $edge + 2), $line.Length)
                        ($cyan + $line.Substring(0, $start) + $spark + $line.Substring($start, $end - $start) +
                            $blue + $line.Substring($end))
                    } else { $cyan + $line }
                }
                ''
                $count = [int][Math]::Floor($credit.Length * [Math]::Max(0, $frame - $revealFrames) / ($lastFrame - $revealFrames))
                $caret = if ($frame -ge $revealFrames -and $frame -lt $lastFrame) { '_' } else { '' }
                $gold + $credit.Substring(0, $count) + $caret
            )
            $position = if ($first) { '' } else { $up }
            $buffer = ($rows | ForEach-Object { "`r$clear$_$reset" }) -join "`r`n"
            Write-STPlain ($position + $buffer)
            $first = $false
            if ($frame -lt $lastFrame) { Start-Sleep -Milliseconds 42 }
        }
        Start-Sleep -Milliseconds 400
    } finally {
        Write-STPlain "$reset$esc[?25h`r`n`r`n"
    }
}
