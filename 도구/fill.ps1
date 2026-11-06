param([string]$Dir, [string]$FuriFile, [string]$FixFile, [string]$Backup, [switch]$NoHangul)
$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding $false
if ($Backup) { New-Item -ItemType Directory -Force -Path $Backup | Out-Null; Copy-Item -Path (Join-Path $Dir '*.js') -Destination $Backup }

# ---------- 로마자 → 한글 ----------
$syl = @{
  'a'='아';'i'='이';'u'='우';'e'='에';'o'='오'
  'ka'='카';'ki'='키';'ku'='쿠';'ke'='케';'ko'='코'
  'ga'='가';'gi'='기';'gu'='구';'ge'='게';'go'='고'
  'sa'='사';'si'='시';'shi'='시';'su'='스';'se'='세';'so'='소'
  'za'='자';'zi'='지';'ji'='지';'zu'='즈';'ze'='제';'zo'='조'
  'ta'='타';'ti'='티';'chi'='치';'tsu'='츠';'tu'='투';'te'='테';'to'='토'
  'da'='다';'di'='디';'du'='두';'de'='데';'do'='도';'dzu'='즈';'dji'='지'
  'na'='나';'ni'='니';'nu'='누';'ne'='네';'no'='노'
  'ha'='하';'hi'='히';'fu'='후';'hu'='후';'he'='헤';'ho'='호'
  'fa'='화';'fi'='피';'fe'='페';'fo'='포'
  'ba'='바';'bi'='비';'bu'='부';'be'='베';'bo'='보'
  'pa'='파';'pi'='피';'pu'='푸';'pe'='페';'po'='포'
  'ma'='마';'mi'='미';'mu'='무';'me'='메';'mo'='모'
  'ya'='야';'yu'='유';'ye'='예';'yo'='요'
  'ra'='라';'ri'='리';'ru'='루';'re'='레';'ro'='로'
  'wa'='와';'wi'='위';'we'='웨';'wo'='오'
  'va'='바';'vi'='비';'vu'='부';'ve'='베';'vo'='보'
  'kya'='캬';'kyu'='큐';'kyo'='쿄';'gya'='갸';'gyu'='규';'gyo'='교'
  'sha'='샤';'shu'='슈';'she'='셰';'sho'='쇼';'ja'='자';'ju'='주';'je'='제';'jo'='조'
  'cha'='차';'chu'='추';'che'='체';'cho'='초';'nya'='냐';'nyu'='뉴';'nyo'='뇨'
  'hya'='햐';'hyu'='휴';'hyo'='효';'bya'='뱌';'byu'='뷰';'byo'='뵤'
  'pya'='퍄';'pyu'='퓨';'pyo'='표';'mya'='먀';'myu'='뮤';'myo'='묘'
  'rya'='랴';'ryu'='류';'ryo'='료'
}

# 받침 붙이기. 바로 앞이 띄어쓰기면(예: koi tte, itta nda) 그 앞 글자에 붙이고 띄어쓰기를 지운다.
# 장음(-) 바로 뒤라면(sukurīn, itooshī nda) 장음을 모음 글자로 풀어 받침을 붙인다: 리- + ㄴ → 리인
function Add-Final([System.Text.StringBuilder]$sb, [int]$fin, [string]$jamo) {
  $canTake = { param($code) $code -ge 0xAC00 -and $code -le 0xD7A3 -and (($code - 0xAC00) % 28) -eq 0 }
  $end = $sb.Length
  $pos = if ($end -gt 1 -and $sb.ToString($end - 1, 1) -eq ' ') { $end - 2 } else { $end - 1 }
  if ($pos -ge 0) {
    $c = [int][char]$sb.ToString($pos, 1)
    if (& $canTake $c) { [void]$sb.Remove($pos, $end - $pos).Append([char]($c + $fin)); return }
    if ($c -eq 45 -and $pos -ge 1) {
      $prev = [int][char]$sb.ToString($pos - 1, 1)
      if ($prev -ge 0xAC00 -and $prev -le 0xD7A3) {
        $jung = [int][math]::Floor(($prev - 0xAC00) / 28) % 21
        [void]$sb.Remove($pos, $end - $pos).Append([char][int](0xAC00 + (11 * 21 + $jung) * 28 + $fin))
        return
      }
    }
  }
  if ($fin -eq 19) { return }    # 쉼표 뒤의 っ처럼 붙일 글자가 없으면 생략 (", tte" → ", 테")
  [void]$sb.Append($jamo)
}

# 한글 발음에서는 조사·끝맺음을 앞 단어에 붙여 쓴다 (한국어 띄어쓰기처럼: 아나타 와 → 아나타와). 사용자 요청 2026-11-03
$particleSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in ('와 가 오 니 노 데 토 에 모 카 야 요 네 나 사 조 제 카라 마데 요리 다케 데모 나라 시카 코소 사에 바카리 나도 토카 난테 난카 쿠라이 호도 노니 케도 카모 다 데스 데쇼 다로 다요 토모 카나 요네 니와 니모 데와 토와 노와 데스요 다케도 다케데 마데모 데시타 닷타 노데 노요 노네 카네 와요 와네' -split ' ')) { [void]$particleSet.Add($p) }
function Join-Particles([string]$line) {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($tok in ($line -split ' ')) {
    $core = $tok -replace '[,.!?、。…~)"」』]+$', ''
    if ($tok -and $out.Count -gt 0 -and $particleSet.Contains($core) -and $out[$out.Count - 1] -match '[가-힣A-Za-z\-]$') {
      $out[$out.Count - 1] = $out[$out.Count - 1] + $tok
    } else { $out.Add($tok) }
  }
  $out -join ' '
}

# $jp: 같은 줄의 원문. 원문에 영어로 적힌 단어(need you, S.T.U.D 등)는 한글로 바꾸지 않고 그대로 둔다.
function ConvertTo-Hangul([string]$line, [string]$jp = '') {
  $tokens = New-Object System.Collections.Generic.List[string]
  if ($jp) {
    # 중복 제거를 먼저 하고 긴 단어부터 (Sort-Object -Unique는 길이가 같은 다른 단어까지 지워 버린다)
    $keep = @([regex]::Matches($jp, "[A-Za-z][A-Za-z'.\-]*[A-Za-z]|[A-Za-z]") | ForEach-Object { $_.Value } | Select-Object -Unique | Sort-Object Length -Descending)
    # 대소문자까지 같은 것 먼저 (Na na처럼 둘 다 있으면 원문 그대로 남게), 그다음 대소문자만 다른 것.
    # 이미 찾은 단어는 두 번째에 건너뛴다 (YESかNOの의 조사 no가 영어 NO로 바뀌지 않게)
    $hit = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($opt in '', '(?i)') {
      foreach ($w in $keep) {
        if ($opt -and $hit.Contains($w)) { continue }
        $rx = [regex]($opt + '(?<![A-Za-z])' + [regex]::Escape($w) + '(?![A-Za-z])')
        while (($m = $rx.Match($line)).Success) {
          $line = $line.Substring(0, $m.Index) + [string][char](0xE000 + $tokens.Count) + $line.Substring($m.Index + $m.Length)
          $tokens.Add($w)
          [void]$hit.Add($w)
        }
      }
    }
  }
  $out = Convert-Core $line
  for ($t = 0; $t -lt $tokens.Count; $t++) { $out = $out.Replace([string][char](0xE000 + $t), $tokens[$t]) }
  $out
}

function Convert-Core([string]$line) {
  $s = $line.Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
  $s = [regex]::Replace($s, '(?<=\p{L})-(?=\p{L})', '')      # yume-tachi, hōkō-sei → 붙여 씀 (장음 처리보다 먼저)
  $s = [regex]::Replace($s, '\s*̄', '-')
  foreach ($p in @(@('ā','a-'),@('ī','i-'),@('ū','u-'),@('ē','e-'),@('ō','o-'),@('â','a-'),@('î','i-'),@('û','u-'),@('ê','e-'),@('ô','o-'))) { $s = $s.Replace($p[0], $p[1]) }
  $sb = New-Object System.Text.StringBuilder
  $i = 0
  while ($i -lt $s.Length) {
    $c = $s[$i]
    if ($c -notmatch '[a-z]') { if ($c -ne "'") { [void]$sb.Append($c) }; $i++; continue }
    $next = if ($i + 1 -lt $s.Length) { $s[$i + 1] } else { '' }
    if ("$c" -match '[bcdfghjkprstvwz]' -and ($next -eq $c -or ($c -eq 't' -and $next -eq 'c'))) { Add-Final $sb 19 'ㅅ'; $i++; continue }
    if (($c -eq 'n' -and "$next" -notmatch '^[aiueoy]$') -or ($c -eq 'm' -and "$next" -match '^[bpm]$')) { Add-Final $sb 4 'ㄴ'; $i++; continue }
    $done = $false
    foreach ($len in 3, 2, 1) {
      if ($i + $len -le $s.Length) {
        $k = $s.Substring($i, $len)
        if ($syl.ContainsKey($k)) { [void]$sb.Append($syl[$k]); $i += $len; $done = $true; break }
      }
    }
    if (-not $done) { [void]$sb.Append($c); $i++ }
  }
  $sb.ToString()
}

# ---------- 입력 목록 ----------
$furi = @{}; $cur = $null; $furiTotal = 0
foreach ($row in [IO.File]::ReadAllLines($FuriFile, $enc)) {
  $r = $row.Trim()
  if (-not $r -or $r.StartsWith('#')) { continue }
  if ($r.StartsWith('@')) { $p = $r.Substring(1) -split '\s+'; $cur = "$($p[0])|$([int]$p[1])"; continue }
  $tok = $r -split '\s+'
  $list = New-Object System.Collections.ArrayList
  foreach ($t in $tok[1..($tok.Count - 1)]) { $a, $b = $t -split '=', 2; [void]$list.Add(@($a, $b)); $furiTotal++ }
  $furi["$cur|$([int]$tok[0])"] = $list
}
$fixes = @{}
foreach ($row in [IO.File]::ReadAllLines($FixFile, $enc)) {
  if (-not $row.Trim()) { continue }
  $f, $song, $old, $new, $fsec = $row -split "`t"
  $k = "$f|$([int]$song)"
  if (-not $fixes.ContainsKey($k)) { $fixes[$k] = New-Object System.Collections.ArrayList }
  [void]$fixes[$k].Add([pscustomobject]@{ Old = $old; New = $new; Sec = $(if ($fsec) { $fsec.Trim() } else { '발음' }); Hits = 0 })
}

# 수정 목록 적용. "re:"로 시작하면 정규식. 칸(원문/발음)별로 따로 부른다.
function Apply-Fixes([string]$secName) {
  foreach ($n in $order) {
    $lines = $files[$n]
    foreach ($r in (Get-Rows $lines | Where-Object { $_.sec -eq $secName -and -not $_.head -and $_.n })) {
      $k = "$n|$($r.song)"
      if (-not $fixes.ContainsKey($k)) { continue }
      foreach ($fx in $fixes[$k]) {
        if ($fx.Sec -ne $secName) { continue }
        $l = $lines[$r.i]
        if ($fx.Old.StartsWith('re:')) {
          $rx = $fx.Old.Substring(3)
          if ([regex]::IsMatch($l, $rx)) { $lines[$r.i] = [regex]::Replace($l, $rx, $fx.New); $fx.Hits++ }
        } elseif ($l.Contains($fx.Old)) { $lines[$r.i] = $l.Replace($fx.Old, $fx.New); $fx.Hits++ }
      }
    }
  }
}

$plainOf = { param($s) [regex]::Replace($s, '\{([^{}|]+)\|[^{}|]+\}', '$1').Trim() }
$order = @('EP.js','미니1집.js','미니2집.js','미니3집.js','정규1집.js','정규2집.js','정규3집.js','정규4집.js','정규5집.js','정규6집.js') +
  @(Get-ChildItem -Path $Dir -Filter '싱글*집.js' | Sort-Object { [int]($_.Name -replace '\D', '') } | ForEach-Object { $_.Name })
$order += @(Get-ChildItem -Path $Dir -Filter '*.js' | Where-Object { $order -notcontains $_.Name } | Sort-Object Name | ForEach-Object { $_.Name })    # 그 외의 곡처럼 곡 이름으로 된 파일
$order = @($order | Where-Object { Test-Path -LiteralPath (Join-Path $Dir $_) })    # 복사본 폴더에 일부 파일만 있어도 돌아가게
$files = [ordered]@{}
foreach ($n in $order) { $files[$n] = New-Object System.Collections.Generic.List[string]; $files[$n].AddRange([string[]]([IO.File]::ReadAllText((Join-Path $Dir $n), $enc) -split "`r?`n")) }

# 줄마다 (곡, 칸, 칸 안 순번) 표시
function Get-Rows($lines) {
  $rows = @(); $song = 0; $sec = $null; $nb = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match '^\s*###\s*(\d+)') { $song = [int]$Matches[1]; $sec = $null; continue }
    if (-not $song -or $l -match '^\s*//' -or $l.StartsWith('`);')) { continue }
    if ($l -match '^\s*\[([^\]]+)\]\s*$') { $sec = $Matches[1]; $nb = 0; $rows += [pscustomobject]@{ i = $i; song = $song; sec = $sec; head = $true; n = 0 }; continue }
    if ($l.Trim()) { $nb++ }
    $rows += [pscustomobject]@{ i = $i; song = $song; sec = $sec; head = $false; n = $(if ($l.Trim()) { $nb } else { 0 }) }
  }
  $rows
}

# 0) 원문 오타 수정
Apply-Fixes '원문'

# 1) 후리가나 적용
$furiUsed = 0; $annotated = @{}
foreach ($n in $order) {
  $lines = $files[$n]
  foreach ($r in (Get-Rows $lines | Where-Object { $_.sec -eq '원문' -and -not $_.head -and $_.n })) {
    $key = "$n|$($r.song)|$($r.n)"
    $l = $lines[$r.i]
    if ($furi.ContainsKey($key) -and $l -notmatch '\{[^{}|]+\|') {
      $cursor = 0
      foreach ($e in $furi[$key]) {
        $idx = $l.IndexOf($e[0], $cursor)
        if ($idx -lt 0) { throw "후리가나 위치를 못 찾음: $key '$($e[0])'" }
        $mk = '{' + $e[0] + '|' + $e[1] + '}'
        $l = $l.Substring(0, $idx) + $mk + $l.Substring($idx + $e[0].Length)
        $cursor = $idx + $mk.Length
        $furiUsed++
      }
      $lines[$r.i] = $l
    }
    if ($lines[$r.i] -match '\{[^{}|]+\|') { $p = & $plainOf $lines[$r.i]; if (-not $annotated.ContainsKey($p)) { $annotated[$p] = $lines[$r.i].Trim() } }
  }
}
# 2) 같은 줄에 복사
$copied = 0
foreach ($n in $order) {
  $lines = $files[$n]
  foreach ($r in (Get-Rows $lines | Where-Object { $_.sec -eq '원문' -and -not $_.head -and $_.n })) {
    $l = $lines[$r.i]
    if ($l -match '\{[^{}|]+\|') { continue }
    $p = & $plainOf $l
    if ($annotated.ContainsKey($p)) { $lines[$r.i] = $annotated[$p]; $copied++ }
  }
}
# 3) 로마자 수정
Apply-Fixes '발음'
# 4) 비어 있는 [한글발음] 채우기 (뒤에서부터 바꿔 줄 번호가 밀리지 않게)
$filled = @()
foreach ($n in $(if ($NoHangul) { @() } else { $order })) {
  $lines = $files[$n]
  $rows = Get-Rows $lines
  $songs = $rows | Select-Object -ExpandProperty song -Unique | Sort-Object -Descending
  foreach ($song in $songs) {
    $sr = @($rows | Where-Object { $_.song -eq $song })
    $hgHead = $sr | Where-Object { $_.head -and $_.sec -eq '한글발음' } | Select-Object -First 1
    if (-not $hgHead) { continue }
    $hgBody = @($sr | Where-Object { -not $_.head -and $_.sec -eq '한글발음' })
    if (@($hgBody | Where-Object { $_.n }).Count) { continue }        # 이미 채워져 있으면 그대로
    $pr = @($sr | Where-Object { -not $_.head -and $_.sec -eq '발음' } | ForEach-Object { $lines[$_.i] })
    while ($pr.Count -and -not $pr[0].Trim()) { $pr = @($pr | Select-Object -Skip 1) }
    while ($pr.Count -and -not $pr[$pr.Count - 1].Trim()) { $pr = @($pr | Select-Object -First ($pr.Count - 1)) }
    if (-not $pr.Count) { continue }
    $jpRows = @($sr | Where-Object { -not $_.head -and $_.sec -eq '원문' -and $_.n } | ForEach-Object { & $plainOf $lines[$_.i] })
    $k = 0
    $new = @(foreach ($p in $pr) {
      if ($p.Trim()) { $j = if ($k -lt $jpRows.Count) { $jpRows[$k] } else { '' }; $k++; Join-Particles (ConvertTo-Hangul $p.Trim() $j) } else { '' }
    }) + ''
    $start = $hgHead.i + 1
    $count = $hgBody.Count
    $lines.RemoveRange($start, $count)
    $lines.InsertRange($start, [string[]]$new)
    $filled += "$n #$song ($(@($pr | Where-Object { $_.Trim() }).Count)줄)"
  }
}

foreach ($n in $order) { [IO.File]::WriteAllText((Join-Path $Dir $n), ($files[$n] -join "`r`n"), $enc) }
"후리가나: 목록 $furiUsed / $furiTotal 적용, 같은 줄 복사 $copied"
"수정 목록:"; foreach ($k in $fixes.Keys) { foreach ($fx in $fixes[$k]) { "  $k [$($fx.Sec)] '$($fx.Old)' → $($fx.Hits)곳" } }
"한글발음 채움: $($filled -join ', ')"
