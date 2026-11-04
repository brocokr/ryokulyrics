param([string]$Dir, [string]$Backup, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding $false

# 한글 발음에서 앞 단어에 붙여 쓰는 조사·끝맺음 (한국어 띄어쓰기처럼: 아나타 와 → 아나타와)
$list = '와 가 오 니 노 데 토 에 모 카 야 요 네 나 사 조 제 카라 마데 요리 다케 데모 나라 시카 코소 사에 바카리 나도 토카 난테 난카 쿠라이 호도 노니 케도 카모 다 데스 데쇼 다로 다요 토모 카나 요네 니와 니모 데와 토와 노와 데스요 다케도 다케데 마데모 데시타 닷타 노데 노요 노네 카네 와요 와네' -split ' '
$set = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in $list) { [void]$set.Add($p) }

function Join-Particles([string]$line) {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($tok in ($line -split ' ')) {
    $core = $tok -replace '[,.!?、。…~)"」』]+$', ''
    if ($tok -and $out.Count -gt 0 -and $set.Contains($core) -and $out[$out.Count - 1] -match '[가-힣A-Za-z\-]$') {
      $out[$out.Count - 1] = $out[$out.Count - 1] + $tok
    } else { $out.Add($tok) }
  }
  $out -join ' '
}

if ($Backup) { New-Item -ItemType Directory -Force -Path $Backup | Out-Null; Copy-Item -Path (Join-Path $Dir '*.js') -Destination $Backup }
$total = 0
foreach ($f in Get-ChildItem -LiteralPath $Dir -Filter *.js) {
  $lines = [IO.File]::ReadAllText($f.FullName, $enc) -split "`r?`n"
  $sec = $null; $changed = 0; $joins = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match '^\s*###') { $sec = $null; continue }
    if ($l -match '^\s*\[([^\]]+)\]\s*$') { $sec = $Matches[1]; continue }
    if ($sec -ne '한글발음' -or -not $l.Trim() -or $l -match '^\s*//') { continue }
    $new = Join-Particles $l
    if ($new -ne $l) { $joins += ($l.Split(' ').Count - $new.Split(' ').Count); $lines[$i] = $new; $changed++ }
  }
  if ($changed) {
    if (-not $DryRun) { [IO.File]::WriteAllText($f.FullName, ($lines -join "`r`n"), $enc) }
    "$($f.Name): $($changed)줄, 붙인 곳 $($joins)"
    $total += $joins
  }
}
"합계 붙인 곳: $total" + $(if ($DryRun) { ' (시험 실행, 파일은 그대로)' } else { '' })
