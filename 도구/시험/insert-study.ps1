param([string]$Work, [string]$File, [string]$No, [string]$StudyFile, [string]$Route, [string]$Out)
# Inserts (or replaces) the study section of block "### $No" in site16 copy of $File, then renders $Route.
$ErrorActionPreference = 'Stop'
$f = Join-Path "$Work\site16" $File
$gb = [string][char]0xACF5 + [char]0xBD80   # study section name
$mm = [string][char]0xBA54 + [char]0xBAA8   # memo section name
$study = [IO.File]::ReadAllText($StudyFile, [Text.Encoding]::UTF8)
$study = ($study -replace "`r`n", "`n").Trim("`n").TrimStart([char]0xFEFF) -replace "`n", "`r`n"
$t = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($f))
$blk = [regex]::Match($t, "(?ms)^### $No .*?(?=^### |\z)")
if (-not $blk.Success) { throw "block $No not found" }
$m = [regex]::Match($blk.Value, "(?s)\[$gb\]\r\n(.*?)\r\n\[$mm\]")
if (-not $m.Success) { throw 'study/memo sections not found' }
$b = $blk.Value.Substring(0, $m.Groups[1].Index) + $study + "`r`n" + $blk.Value.Substring($m.Groups[1].Index + $m.Groups[1].Length)
$t = $t.Substring(0, $blk.Index) + $b + $t.Substring($blk.Index + $blk.Length)
[IO.File]::WriteAllBytes($f, (New-Object Text.UTF8Encoding($false)).GetBytes($t))
'LF-only=' + ([regex]::Matches($t, "(?<!`r)`n")).Count + ' backtick=' + ([regex]::Matches($study, '`')).Count
& "$Work\test-seishun.ps1" -Work $Work -Route $Route -Out $Out
