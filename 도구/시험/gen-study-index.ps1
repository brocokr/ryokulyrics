param([string]$Dir, [string]$Out)
# Builds a plain-text index of every [공부] item in the lyric files: "=== 곡|줄|항목 (파일)" + item line + detail lines.
$ErrorActionPreference = 'Stop'
$u = New-Object Text.UTF8Encoding($false)
$gb = '[' + [string][char]0xACF5 + [char]0xBD80 + ']'
$sb = New-Object Text.StringBuilder
$count = 0
foreach ($f in Get-ChildItem $Dir -Filter *.js) {
  $lines = [IO.File]::ReadAllLines($f.FullName, $u)
  $title = ''; $inStudy = $false; $lineNo = ''
  foreach ($l in $lines) {
    if ($l -match '^### \d+ (.+)$') { $title = ($Matches[1] -split ' · ')[0].Trim(); $inStudy = $false; continue }
    if ($l -match '^\[[^\]]+\]\s*$') { $inStudy = ($l.Trim() -eq $gb); continue }
    if (-not $inStudy) { continue }
    if ($l -match '^\d+$') { $lineNo = $l; continue }
    if ($l -match '^\S' -and $l -match ' - ') {
      $term = [regex]::Replace(($l -split ' - ')[0], '\{([^{}|]+)\|[^{}]+\}', '$1').Trim()
      [void]$sb.Append("=== $title|$lineNo|$term ($($f.BaseName))`n$l`n"); $count++
      continue
    }
    if ($l -match '^  ') { [void]$sb.Append("$l`n") }
  }
}
[IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))
"items: $count"
