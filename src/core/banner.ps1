# Intro ASCII. Cada cuadro reemplaza el anterior en el mismo bloque de consola.
function Show-STBanner {
    param([switch]$NoBanner)
    if ($NoBanner) { return }

    $credit = '  made by josemidev1'
    $logoFile = Join-Path $Global:STData 'figlet.txt'
    $logo = @(Get-Content -LiteralPath $logoFile -ErrorAction SilentlyContinue)
    $width = 80
    if ($script:STConsole) { try { $width = $script:STConsole.WindowWidth } catch { } }
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
    $dim = STC '90'
    $gold = STC '93'
    $reset = STC '0'
    $first = $true

    try {
        Write-STPlain "$esc[?25l"
        for ($frame = 0; $frame -le 24; $frame++) {
            $edge = [int][Math]::Floor($logoWidth * [Math]::Min($frame, 16) / 16)
            $rows = @(
                foreach ($line in $logo) {
                    $end = [Math]::Min($edge, $line.Length)
                    $start = [Math]::Max(0, $end - 3)
                    if ($frame -lt 16) {
                        $line.Substring(0, $start).Insert(0, $cyan) +
                            $spark + $line.Substring($start, $end - $start) + $dim +
                            ($line.Substring($end) -replace '[#]', '.')
                    } else { $cyan + $line }
                }
                ''
                $gold + $credit.Substring(0, [int][Math]::Floor($credit.Length * [Math]::Max(0, $frame - 16) / 8))
            )
            $position = if ($first) { '' } else { $up }
            $buffer = ($rows | ForEach-Object { "`r$clear$_$reset" }) -join "`r`n"
            Write-STPlain ($position + $buffer)
            $first = $false
            if ($frame -lt 24) { Start-Sleep -Milliseconds 44 }
        }
        Start-Sleep -Milliseconds 430
    } finally {
        Write-STPlain "$reset$esc[?25h`r`n`r`n"
    }
}
