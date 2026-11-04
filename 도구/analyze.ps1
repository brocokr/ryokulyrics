param([string]$Dir)
$enc = New-Object System.Text.UTF8Encoding $false
$plain = { param($s) [regex]::Replace($s, '\{([^{}|]+)\|[^{}|]+\}', '$1').Trim() }
$first = @{}       # 줄 내용 → 처음 나온 위치
$order = 'EP.js','미니1집.js','미니2집.js','미니3집.js','정규1집.js','정규2집.js','정규3집.js','정규4집.js','정규5집.js','정규6집.js'
foreach ($name in $order) {
  $lines = [IO.File]::ReadAllLines((Join-Path $Dir $name), $enc)
  $song = 0; $sec = $null; $nb = 0; $rows = @(); $pron = @()
  $flush = {
    if ($rows.Count) {
      $needs = @($rows | Where-Object { $_.kanji -and -not $_.ruby -and -not $_.dup })
      $dups = @($rows | Where-Object { $_.dup })
      $romaji = @($pron | Where-Object { $_ -match '^[\x00-\x7FĀ-ſ̀-ͯ’‘ ]+$' }).Count
      "{0} #{1:D2}: 줄={2} 후리가나필요(고유)={3} 이미있음={4} 한자없음={5} 중복={6} | 발음줄={7} 로마자줄={8}" -f $name, $song, $rows.Count, $needs.Count, @($rows | Where-Object { $_.ruby }).Count, @($rows | Where-Object { -not $_.kanji }).Count, $dups.Count, $pron.Count, $romaji
      foreach ($d in $dups) { "    {0} = {1}" -f $d.n, $d.dup }
    }
  }
  foreach ($l in $lines) {
    if ($l -match '^\s*###\s*(\d+)') { $next = [int]$Matches[1]; . $flush; $song = $next; $sec = $null; $nb = 0; $rows = @(); $pron = @(); continue }
    if (-not $song -or $l -match '^\s*//') { continue }
    if ($l -match '^\s*\[([^\]]+)\]\s*$') { $sec = $Matches[1]; continue }
    if ($l.StartsWith('`);')) { continue }
    if ($sec -eq '원문' -and $l.Trim()) {
      $nb++
      $p = & $plain $l
      $key = "$name|$song|$nb"
      $dup = $null
      if ($first.ContainsKey($p)) { $dup = $first[$p] } else { $first[$p] = $key }
      $rows += [pscustomobject]@{ n = $nb; kanji = ($p -match '[一-鿿々]'); ruby = ($l -match '\{[^{}|]+\|[^{}|]+\}'); dup = $dup }
    }
    if ($sec -eq '발음' -and $l.Trim()) { $pron += $l.Trim() }
  }
  . $flush
}
