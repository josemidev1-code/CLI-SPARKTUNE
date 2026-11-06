# SparkTune banner.ps1 — animacion de arranque: scramble-decode + spark cian + fade del tagline.
# Depende de ui.ps1 (Write-STPlain, STC, $script:STAnsi, $script:STConsole).

$script:STLogoLines = @(
'███████╗ █████╗ ██████╗ ██████╗  █████╗ ████████╗████████╗██╗   ██╗███╗   ██╗███╗   ██╗███████╗',
'██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝╚██╗ ██╔╝████╗ ████║████╗ ████║██╔══██╗██╔════╝',
'███████╗███████║██████╔╝██████╔╝███████║   ██║    ╚████╔╝ ██╔████╔██║██╔████╔██║███████║███████╗',
'╚════██║██╔══██║██╔═══╝ ██╔══██╗██╔══██║   ██║     ╚██╔╝  ██║╚██╔╝██║██║╚██╔╝██║██╔══██║╚════██║',
'███████║██║  ██║██║     ██║  ██║██║  ██║   ██║      ██║   ██║ ╚═╝ ██║██║ ╚═╝ ██║██║  ██║███████║',
'╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝     ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝'
)

$script:STScrambleChars = '▒▓░█▚▞╳╱╲#%@$&*+=?/\<>'

function STSleepMs([int]$Ms) { Start-Sleep -Milliseconds $Ms }

function Show-STBanner {
    param([switch]$NoBanner)
    if ($NoBanner) { return }
    Enable-STVirtualTerminal

    $lines = $script:STLogoLines
    $n = $lines.Count
    $maxLen = 0
    foreach ($l in $lines) { if ($l.Length -gt $maxLen) { $maxLen = $l.Length } }

    if ($script:STConsole) { try { $script:STConsole.CursorVisible = $false } catch { } }

    $cyan = STC '96'; $bold = STC '1'; $dim = STC '2'; $white = STC '97'; $rst = STC '0'

    if ($script:STAnsi -and $script:STConsole) {
        # ---- fase 1: scramble-decode ----
        $rnd = Get-Random
        $state = New-Object 'object[]' $n
        for ($i = 0; $i -lt $n; $i++) { $state[$i] = $lines[$i].ToCharArray() }
        $locked = New-Object 'int[]' $n
        for ($frame = 0; $frame -lt 14; $frame++) {
            $prog = ($frame / 13.0) * $maxLen
            for ($row = 0; $row -lt $n; $row++) {
                $src = $lines[$row]
                $border = [Math]::Min($maxLen, $src.Length + 8)
                $sb = New-Object System.Text.StringBuilder
                for ($col = 0; $col -lt $border; $col++) {
                    $ch = ' '
                    if ($col -lt $src.Length) { $ch = $src[$col] }
                    if ($col -lt $prog) {
                        [void]$sb.Append($ch)
                    } elseif ($ch -eq ' ') {
                        [void]$sb.Append(' ')
                    } else {
                        [void]$sb.Append($script:STScrambleChars[(Get-Random -Maximum $script:STScrambleChars.Length)])
                    }
                }
                if ($row -eq 0) { Write-STPlain "`r" } else { Write-STPlain "`r`n" }
                Write-STPlain ($dim + $sb.ToString() + $rst)
            }
            STSleepMs 28
        }
        # fijar logo limpio
        for ($row = 0; $row -lt $n; $row++) {
            Write-STPlain "`r"
            if ($row -lt $n - 1) { Write-STPlain "`n" }
            Write-STPlain ($bold + $cyan + $lines[$row] + $rst)
        }
        # ---- fase 2: spark cian->blanco de izquierda a derecha ----
        for ($pos = 0; $pos -le $maxLen + 6; $pos += 2) {
            for ($row = 0; $row -lt $n; $row++) {
                $src = $lines[$row]
                $border = [Math]::Min($maxLen, $src.Length + 8)
                $sb = New-Object System.Text.StringBuilder
                for ($col = 0; $col -lt $border; $col++) {
                    $ch = ' '
                    if ($col -lt $src.Length) { $ch = $src[$col] }
                    $d = [Math]::Abs($col - $pos)
                    if ($d -le 1) { [void]$sb.Append($bold + $white + $ch + $rst) }
                    elseif ($d -le 4) { [void]$sb.Append($bold + $cyan + $ch + $rst) }
                    else { [void]$sb.Append($bold + $cyan + $ch + $rst) }
                }
                Write-STPlain "`r"
                if ($row -lt $n - 1) { Write-STPlain "`n" }
                Write-STPlain $sb.ToString()
            }
            STSleepMs 16
        }
        # logo final fijo
        for ($row = 0; $row -lt $n; $row++) {
            Write-STPlain "`r"
            if ($row -lt $n - 1) { Write-STPlain "`n" }
            Write-STPlain ($bold + $cyan + $lines[$row] + $rst)
        }
        Write-STPlain "`n"
    } else {
        # fallback sin ANSI: logo estatico plano
        foreach ($l in $lines) { Write-STLine $l }
    }

    # ---- fase 3: tagline con fade ----
    $tag = "  ⚡ $(T 'app.tagline') · v$Global:STVersion · $(T 'app.by') ⚡"
    if ($script:STAnsi -and $script:STConsole) {
        $fadeSteps = 5
        $chars = $tag.ToCharArray()
        for ($s = 1; $s -le $fadeSteps; $s++) {
            $sb = New-Object System.Text.StringBuilder
            $lit = [int](($s / [double]$fadeSteps) * $chars.Length)
            for ($i = 0; $i -lt $chars.Length; $i++) {
                $c = [string]$chars[$i]
                if ($i -lt $lit) { [void]$sb.Append($bold + $c) }
                elseif ($i -lt $lit + 6) { [void]$sb.Append($dim + $c) }
                else { [void]$sb.Append(' ') }
            }
            Write-STPlain "`r"
            Write-STPlain ($bold + $sb.ToString() + $rst)
            STSleepMs 40
        }
        Write-STPlain "`r"
        Write-STPlain ($bold + (STC '93') + $tag + $rst + "`n")
    } else {
        Write-STLine $tag 'yellow' 'bold'
    }
    Write-STLine ''
    if ($script:STConsole) { try { $script:STConsole.CursorVisible = $true } catch { } }
}
