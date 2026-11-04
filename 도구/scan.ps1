param([string]$Dir)
$enc = New-Object System.Text.UTF8Encoding $false
foreach ($f in Get-ChildItem -LiteralPath $Dir -Filter *.js) {
    $song = $null; $sec = $null; $counts = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines($f.FullName, $enc)) {
        if ($line -match '^\s*###\s*(\d+)') { $song = $Matches[1]; $counts[$song] = @{}; $sec = $null; continue }
        if (-not $song -or $line -match '^\s*//') { continue }
        if ($line -match '^\s*\[([^\]]+)\]\s*$') { $sec = $Matches[1]; continue }
        if ($sec -and $line.Trim()) {
            $c = $counts[$song]
            $c[$sec] = 1 + [int]$c[$sec]
            if ($sec -eq '원문' -and $line -match '\{') { $c['후리가나줄'] = 1 + [int]$c['후리가나줄'] }
        }
    }
    foreach ($k in $counts.Keys) {
        $c = $counts[$k]
        if ($c['원문'] -or $c['발음'] -or $c['해석']) {
            "$($f.Name) #$k : " + (($c.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', ')
        }
    }
}
