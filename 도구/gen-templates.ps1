param([string]$SiteDir)
# index.html의 ALBUMS 목록을 보고, 아직 없는 가사 파일만 빈 틀로 만든다 (이미 있는 파일은 건드리지 않음)
$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding $false
$dir = Join-Path $SiteDir '가사'
$src = [IO.File]::ReadAllText((Join-Path $SiteDir 'index.html'), $enc)
$json = [regex]::Match($src, '/\*ALBUMS\*/([\s\S]*?)/\*END\*/').Groups[1].Value
$albums = @(($json | ConvertFrom-Json) | ForEach-Object { $_ })

# 머리말은 EP.js의 것을 가져와 앨범 이름만 바꾼다
$ep = [IO.File]::ReadAllText((Join-Path $dir 'EP.js'), $enc) -split "`r?`n"
$cut = [array]::FindIndex([string[]]$ep, [Predicate[string]]{ param($x) $x.StartsWith('가사("EP"') })
$header = @($ep[1..($cut - 1)])

function Norm([string]$s) { ($s.Normalize([Text.NormalizationForm]::FormKC).ToLowerInvariant()) -replace '\s+', '' }
$all = foreach ($al in $albums) {
  $i = 0
  foreach ($tr in $al.tracks) { $i++; $t = @($tr); [pscustomobject]@{ album = $al; no = $i; jp = $t[0]; ko = $(if ($t.Count -gt 1) { $t[1] } else { '' }); read = $(if ($t.Count -gt 2) { $t[2] } else { '' }); key = (Norm $t[0]) } }
}

foreach ($al in $albums) {
  $path = Join-Path $dir "$($al.file).js"
  if (Test-Path -LiteralPath $path) { continue }
  $out = New-Object System.Collections.Generic.List[string]
  $first = "// 녹황색사회 가사 노트 · $($al.label) 『$($al.title)』"
  if ($al.ko) { $first += " $($al.ko)" }
  $out.Add("$first ($($al.date))")
  foreach ($h in $header) { $out.Add($h.Replace('가사("EP"', "가사(`"$($al.file)`"")) }
  $out.Add("가사(`"$($al.file)`", ``"); $out.Add('')
  foreach ($t in ($all | Where-Object { $_.album -eq $al })) {
    $head = '### {0:D2} {1}' -f $t.no, $t.jp
    if ($t.read) { $head += "($($t.read))" }
    if ($t.ko) { $head += " · $($t.ko)" }
    $out.Add($head)
    $inst = if ($al.inst) { $al.inst."$($t.no)" } else { $null }
    if ($inst) { $out.Add("// 가사가 없는 $inst 곡입니다. 칸은 비워 두면 됩니다.") }
    else {
      $tw = @($all | Where-Object { $_ -ne $t -and $_.key -eq $t.key })
      if ($tw.Count) { $out.Add('// ' + (($tw | ForEach-Object { "$($_.album.label) 『$($_.album.title)』 $($_.no)번" }) -join ', ') + '과 같은 곡입니다. 한쪽에만 넣어도 양쪽에서 보입니다.') }
    }
    $out.Add('')
    foreach ($sec in '원문', '발음', '한글발음', '해석', '공부', '메모') { $out.Add("[$sec]"); $out.Add('') }
    $out.Add('')
  }
  $out.Add('`);')
  [IO.File]::WriteAllText($path, ($out -join "`r`n"), $enc)
  "만듦: $($al.file).js ($(@($al.tracks).Count)곡)"
}
