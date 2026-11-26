# Startup animation drawn in place in a single console region.
function Show-STBanner {
    param([switch]$NoBanner)
    if ($NoBanner) { return }

    $credit = '  made by josemidev1'
    $logoFile = Join-Path $Global:STData 'figlet.txt'
    $logo = @(Get-Content -LiteralPath $logoFile -ErrorAction SilentlyContinue | ForEach-Object { $_.Replace('#','█') })
    $width = 80
    if ($script:STConsole) { try { $width = [Console]::WindowWidth } catch { } }
    $logoWidth = ($logo | Measure-Object -Property Length -Maximum).Maximum
    if (-not $logo.Count -or $width -le $logoWidth) {
        $logo = @('  SparkTune')
        $logoWidth = $logo[0].Length
    }

    if ($script:STConsole) { Enable-STVirtualTerminal }
    if (-not $script:STConsole -or -not $script:STVtEnabled -or $width -le $credit.Length -or $env:TERM -eq 'dumb') {
        foreach ($line in $logo) { Write-Host $line }
        Write-Host $credit
        return
    }

    $columns = [Math]::Min($width - 1, [Math]::Max($credit.Length, $logoWidth + 7))
    $logoTop = 3
    $rows = $logoTop + $logo.Count + 3
    $sparkX = [int][Math]::Floor($logoWidth * 0.42)
    $ignition = 20
    $lastFrame = 35
    $cyan = STC '96'
    $mint = STC '92'
    $gold = STC '93'
    $muted = STC '90'
    $bold = STC '1'
    $white = STC '97'
    $reset = STC '0'
    $palette = @(
        STC '38;2;255;79;121'
        STC '38;2;255;123;80'
        STC '38;2;253;180;77'
        STC '38;2;221;231;88'
        STC '38;2;131;235;119'
        STC '38;2;73;228;174'
        STC '38;2;69;215;235'
        STC '38;2;90;162;255'
        STC '38;2;135;121;255'
        STC '38;2;194;104;250'
        STC '38;2;240;100;210'
    )

    $signature = '-=[ made by josemidev1 ]=-'
    $decorated = $logo.Count -gt 1 -and $columns -ge $signature.Length
    $indent = ' ' * [Math]::Max(0, [int][Math]::Floor(($logoWidth - $signature.Length) / 2))
    $author = 'josemidev1'

    # Stable paths keep the binary assembly identical at each startup.
    $random = [Random]::new(14)
    $particles = @(
        for ($y = 0; $y -lt $logo.Count; $y++) {
            for ($x = 0; $x -lt $logo[$y].Length; $x++) {
                $char = $logo[$y][$x]
                if ($char -eq ' ') { continue }
                $originX = @(0, ($columns - 1), $x)
                $originY = @(0, 1, ($rows - 2), ($rows - 1))
                @{
                    X = $x; Y = $logoTop + $y; Char = [string]$char
                    FromX = $originX[$random.Next($originX.Count)]
                    FromY = $originY[$random.Next($originY.Count)]
                    Delay = $random.Next(5); Bit = $random.Next(2)
                }
            }
        }
    )

    $esc = [char]27
    $clear = "$esc[2K"
    $up = "$esc[$($rows - 1)A"
    $position = ''
    try {
        Write-STPlain "$esc[?25l"
        for ($frame = 0; $frame -le $lastFrame; $frame++) {
            $cells = @{}
            $wave = ($frame - $ignition) * 3
            foreach ($particle in $particles) {
                $step = ($frame - $particle.Delay) / 15.0
                if ($step -le 0 -or $step -ge 1) { continue }
                $x = [int]($particle.FromX + ($particle.X - $particle.FromX) * [Math]::Min($step / 0.68, 1))
                $y = [int]($particle.FromY + ($particle.Y - $particle.FromY) * [Math]::Max(($step - 0.68) / 0.32, 0))
                $bit = [string](($particle.Bit + [Math]::Floor($frame / 2)) % 2)
                $cells[$y * $columns + $x] = @($bit, $mint)
            }
            foreach ($particle in $particles) {
                if ($frame -lt $particle.Delay + 15) { continue }
                $distance = [Math]::Abs($particle.X - $sparkX) + ($particle.Y - $logoTop)
                $color = $cyan
                if ($wave -ge $distance) {
                    $shift = if ($frame -eq $lastFrame) { 0 } else { $frame - $ignition }
                    $hue = ([int][Math]::Floor($particle.X / 3.0) + $shift) % $palette.Count
                    $color = $palette[$hue]
                }
                $cells[$particle.Y * $columns + $particle.X] = @($particle.Char, $color)
            }
            if ($frame -ge $ignition -and $frame -le ($ignition + 5)) {
                $spread = 1 + [int][Math]::Floor(($frame - $ignition) / 2)
                $cells[(2 * $columns) + $sparkX] = @('*', $white)
                $cells[$sparkX] = @('|', $gold)
                $cells[$columns + $sparkX - $spread] = @('\', $gold)
                $cells[$columns + $sparkX + $spread] = @('/', $gold)
                $cells[2 * $columns + $sparkX - $spread - 1] = @('+', $gold)
                $cells[2 * $columns + $sparkX + $spread + 1] = @('+', $gold)
            }

            $buffer = [Text.StringBuilder]::new($position)
            for ($y = 0; $y -lt $rows; $y++) {
                if ($y) { [void]$buffer.Append("`r`n") }
                [void]$buffer.Append("`r$clear")
                if ($y -eq $rows - 1 -and $frame -ge $ignition + 5) {
                    if ($decorated) {
                        $shine = $frame - $ignition - 5
                        $authorLine = [Text.StringBuilder]::new()
                        for ($i = 0; $i -lt $author.Length; $i++) {
                            $tint = if ($i -eq $shine) { $white } else { $palette[($i + 5) % $palette.Count] }
                            [void]$authorLine.Append("$tint$($author[$i])")
                        }
                        [void]$buffer.Append("$indent$cyan-=[ $muted" + "made by $bold$authorLine$reset$cyan ]=-$reset")
                    } else {
                        [void]$buffer.Append("$gold$credit$reset")
                    }
                    continue
                }
                $activeColor = ''
                for ($x = 0; $x -lt $columns; $x++) {
                    $cell = $cells[$y * $columns + $x]
                    if (-not $cell) { [void]$buffer.Append(' '); continue }
                    if ($cell[1] -cne $activeColor) {
                        $activeColor = $cell[1]
                        [void]$buffer.Append($activeColor)
                    }
                    [void]$buffer.Append($cell[0])
                }
                [void]$buffer.Append($reset)
            }
            Write-STPlain $buffer.ToString()
            $position = $up
            if ($frame -lt $lastFrame) { Start-Sleep -Milliseconds 39 }
        }
        Start-Sleep -Milliseconds 420
    } finally {
        Write-STPlain "$reset$esc[?25h`r`n`r`n"
    }
}
