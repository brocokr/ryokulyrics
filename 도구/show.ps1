param([string]$Dir, [string]$Name, [int[]]$Songs)
$enc = New-Object System.Text.UTF8Encoding $false
$plain = { param($s) [regex]::Replace($s, '\{([^{}|]+)\|[^{}|]+\}', '$1').Trim() }
# 앞선 파일들까지 포함해 처음 나온 줄만 보여 준다(중복 줄은 자동 복사 대상)
$seen = @{}
$order = 'EP.js','미니1집.js','미니2집.js','미니3집.js','정규1집.js','정규2집.js','정규3집.js','정규4집.js','정규5집.js','정규6집.js'
foreach ($fn in $order) {
  $lines = [IO.File]::ReadAllLines((Join-Path $Dir $fn), $enc)
  $song = 0; $sec = $null; $jp = @(); $pr = @()
  $emit = {
    if ($fn -eq $Name -and $Songs -contains $song -and $jp.Count) {
      "@$fn $song"
      for ($i = 0; $i -lt $jp.Count; $i++) {
        if ($jp[$i].show) { "{0}`t{1}`t{2}" -f ($i + 1), $jp[$i].text, $pr[$i] }
      }
    }
  }
  foreach ($l in $lines) {
    if ($l -match '^\s*###\s*(\d+)') { $next = [int]$Matches[1]; . $emit; $song = $next; $sec = $null; $jp = @(); $pr = @(); continue }
    if (-not $song -or $l -match '^\s*//' -or $l.StartsWith('`);')) { continue }
    if ($l -match '^\s*\[([^\]]+)\]\s*$') { $sec = $Matches[1]; continue }
    if (-not $l.Trim()) { continue }
    if ($sec -eq '원문') {
      $p = & $plain $l
      $show = ($p -match '[一-鿿々]') -and -not ($l -match '\{') -and -not $seen.ContainsKey($p)
      $seen[$p] = 1
      $jp += [pscustomobject]@{ text = $p; show = $show }
    }
    if ($sec -eq '발음') { $pr += $l.Trim() }
  }
  . $emit
}
