param([string]$File, [string]$Backup)
# 후리가나 읽기와 로마자가 같은 소리인지 줄마다 대조하고, 칸별 줄 수와 원문·다른 칸의 변화를 확인합니다.
$enc = New-Object Text.UTF8Encoding $false

function Parse([string]$path) {
  $songs = @{}; $song = $null; $sec = $null
  foreach ($l in ([IO.File]::ReadAllText($path, $enc) -split "`r?`n")) {
    if ($l -match '^###\s*(\d+)') { $song = [int]$Matches[1]; $songs[$song] = @{ head = $l }; $sec = $null; continue }
    if ($null -eq $song -or $l.StartsWith('`);')) { continue }
    if ($l -match '^\[(.+)\]\s*$') { $sec = $Matches[1]; $songs[$song][$sec] = New-Object System.Collections.Generic.List[string]; continue }
    if ($sec -and $l.Trim()) { $songs[$song][$sec].Add($l.Trim()) }
  }
  $songs
}

$base = @{
  'あ'='a';'い'='i';'う'='u';'え'='e';'お'='o';'か'='ka';'き'='ki';'く'='ku';'け'='ke';'こ'='ko'
  'が'='ga';'ぎ'='gi';'ぐ'='gu';'げ'='ge';'ご'='go';'さ'='sa';'し'='shi';'す'='su';'せ'='se';'そ'='so'
  'ざ'='za';'じ'='ji';'ず'='zu';'ぜ'='ze';'ぞ'='zo';'た'='ta';'ち'='chi';'つ'='tsu';'て'='te';'と'='to'
  'だ'='da';'ぢ'='ji';'づ'='zu';'で'='de';'ど'='do';'な'='na';'に'='ni';'ぬ'='nu';'ね'='ne';'の'='no'
  'は'='ha';'ひ'='hi';'ふ'='fu';'へ'='he';'ほ'='ho';'ば'='ba';'び'='bi';'ぶ'='bu';'べ'='be';'ぼ'='bo'
  'ぱ'='pa';'ぴ'='pi';'ぷ'='pu';'ぺ'='pe';'ぽ'='po';'ま'='ma';'み'='mi';'む'='mu';'め'='me';'も'='mo'
  'や'='ya';'ゆ'='yu';'よ'='yo';'ら'='ra';'り'='ri';'る'='ru';'れ'='re';'ろ'='ro';'わ'='wa';'を'='o';'ん'='n'
  'ぁ'='a';'ぃ'='i';'ぅ'='u';'ぇ'='e';'ぉ'='o'
}
$youon = @{ 'ゃ'='a';'ゅ'='u';'ょ'='o' }

function ToRoma([string]$s) {
  $s = [regex]::Replace($s, '\{[^{}|]+\|([^{}|]+)\}', '$1')
  $sb = New-Object Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    $c = [int]$ch
    if ($c -ge 0x30A1 -and $c -le 0x30F6) { [void]$sb.Append([char]($c - 0x60)) } else { [void]$sb.Append($ch) }
  }
  $s = $sb.ToString()
  $o = New-Object Text.StringBuilder; $i = 0; $dbl = $false
  while ($i -lt $s.Length) {
    $k = [string]$s[$i]
    if ($k -eq 'っ') { $dbl = $true; $i++; continue }
    if ($k -eq 'ー') { $i++; continue }
    if ($base.ContainsKey($k)) {
      $r = $base[$k]
      if ($i + 1 -lt $s.Length -and $youon.ContainsKey([string]$s[$i + 1])) {
        $v = $youon[[string]$s[$i + 1]]
        if ($r -match '^(shi|chi|ji)$') { $r = $r.Substring(0, $r.Length - 1) + $v } else { $r = $r.Substring(0, $r.Length - 1) + 'y' + $v }
        $i++
      }
      if ($dbl) { $r = $r.Substring(0, 1) + $r; $dbl = $false }
      [void]$o.Append($r)
    } else { [void]$o.Append($k); $dbl = $false }
    $i++
  }
  $o.ToString()
}

function Norm([string]$s) {
  $s = $s.Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
  foreach ($p in @(@('ā','a'),@('ī','i'),@('ū','u'),@('ē','e'),@('ō','o'))) { $s = $s.Replace($p[0], $p[1]) }
  $s = [regex]::Replace($s, '[^a-z]', '')
  $s = $s.Replace('dzu','zu').Replace('cch','tch')
  # 조사 は·へ·を와 긴 소리 차이는 같은 소리로 친다
  $s = $s.Replace('ha','wa').Replace('he','e').Replace('wo','o')
  $s = $s.Replace('ou','o').Replace('ei','e')
  $s = [regex]::Replace($s, '([aiueo])\1+', '$1')
  $s
}

$now = Parse $File; $old = Parse $Backup
$mis = 0; $total = 0
"[줄 수]"
foreach ($k in ($now.Keys | Sort-Object)) {
  $a = $now[$k]['원문'].Count; $b = $now[$k]['발음'].Count; $c = $now[$k]['한글발음'].Count
  $flag = if ($a -eq $b -and $b -eq $c) { '' } else { '  <-- 다름' }
  "{0:00}: 원문 {1} / 발음 {2} / 한글 {3}{4}" -f $k, $a, $b, $c, $flag
}
"[후리가나와 로마자가 다른 줄]"
foreach ($k in ($now.Keys | Sort-Object)) {
  $jp = $now[$k]['원문']; $pr = $now[$k]['발음']
  for ($i = 0; $i -lt [Math]::Min($jp.Count, $pr.Count); $i++) {
    $total++
    $x = Norm (ToRoma $jp[$i]); $y = Norm $pr[$i]
    if ($x -ne $y) { $mis++; "{0:00}-{1}: {2}`n     로마자 {3}" -f $k, ($i + 1), $x, $y }
  }
}
"대조 $total 줄, 다른 줄 $mis"
"[한자에 읽기가 없는 줄]"
$noFuri = 0
foreach ($k in ($now.Keys | Sort-Object)) {
  $jp = $now[$k]['원문']
  for ($i = 0; $i -lt $jp.Count; $i++) {
    $rest = [regex]::Replace($jp[$i], '\{[^{}|]+\|[^{}|]+\}', '')
    if ($rest -match '[一-鿿々]') { $noFuri++; "{0:00}-{1}: {2}" -f $k, ($i + 1), $rest }
  }
}
"없는 줄 $noFuri"
"[한글발음에 남은 로마자 중 원문에 없는 것]"
$left = 0
foreach ($k in ($now.Keys | Sort-Object)) {
  $jp = $now[$k]['원문']; $hg = $now[$k]['한글발음']
  for ($i = 0; $i -lt [Math]::Min($jp.Count, $hg.Count); $i++) {
    foreach ($m in [regex]::Matches($hg[$i], "[A-Za-z][A-Za-z'.\-]*")) {
      if ($jp[$i] -notmatch [regex]::Escape($m.Value)) { $left++; "{0:00}-{1}: {2}" -f $k, ($i + 1), $m.Value }
    }
  }
}
"남은 것 $left"
"[병음·물결표·백틱]"
$raw = [IO.File]::ReadAllText($File, $enc)
$body = $raw.Substring($raw.IndexOf('가사("'))
"병음 글자: " + [regex]::Matches($body, '[ǎǐǒǔèéìíòóùúàáǚǜ]').Count + ", ~: " + [regex]::Matches($body, '~').Count + ", 백틱: " + ([regex]::Matches($body, '`').Count)
"[원문: 후리가나를 뺀 뒤 바뀐 줄]"
$cnt = 0
foreach ($k in ($now.Keys | Sort-Object)) {
  $a = $now[$k]['원문']; $b = $old[$k]['원문']
  for ($i = 0; $i -lt [Math]::Min($a.Count, $b.Count); $i++) {
    $x = [regex]::Replace($a[$i], '\{([^{}|]+)\|[^{}|]+\}', '$1')
    if ($x -cne $b[$i]) { $cnt++; "{0:00}-{1}: {2} -> {3}" -f $k, ($i + 1), $b[$i], $x }
  }
}
"바뀐 줄 $cnt"
"[해석·공부·메모·제목 줄 변화]"
$chg = 0
foreach ($k in ($now.Keys | Sort-Object)) {
  if ($now[$k].head -cne $old[$k].head) { $chg++; "{0:00} 제목 줄" -f $k }
  foreach ($s in '해석','공부','메모') {
    if (($now[$k][$s] -join "`n") -cne ($old[$k][$s] -join "`n")) { $chg++; "{0:00} {1}" -f $k, $s }
  }
}
"변화 $chg"
