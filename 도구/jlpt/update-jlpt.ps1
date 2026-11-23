param([int]$P = 8851, [int]$DebugPort = 9381, [int]$DelayMs = 350, [string]$NihongoIndex = '', [string]$Root = '', [string]$Dump = '')
# 퀴즈 단어의 JLPT 급수표(사이트 맨 위의 jlpt.js)를 다시 만듭니다. 새 해석·[공부]를 넣은 뒤에 실행합니다.
# 1) 사이트를 열어 [공부]의 단어(문법 항목 제외)를 모으고
# 2) 아직 찾아본 적 없는 단어만 네이버 일본어사전에서 찾아 naver-cache.json에 저장하고(한 번 찾은 단어는 다시 찾지 않음)
# 3) resolve.js로 단어마다 급수를 고릅니다: 네이버 → Anki 덱(anki-v.json) → 공개 JLPT 단어 목록(jlpt-list.json) → Jisho 사전(jisho-cache.json) → 손으로 분류한 표(manual.tsv)
# 4) jlpt-head.txt(맨 위 설명)와 합쳐 jlpt.js를 씁니다.
# 끝에 '아직 분류하지 않은 단어'가 나오면 manual.tsv에 한 줄씩 적고 다시 실행합니다(적는 법은 manual.tsv 맨 위).
# anki-v.json은 broco Nihongo의 Anki 단어 덱입니다. -NihongoIndex로 nihongo index.html 경로를 주면 새로 뽑습니다.
# -Root는 사이트 폴더(안 주면 이 도구가 들어 있는 사이트), -Dump는 어떤 단어가 어떻게 정해졌는지 적어 둘 파일(확인용)입니다.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = if ($Root) { $Root } else { Split-Path (Split-Path $here) }
$tools = (Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName
. "$here\cdp.ps1"
$u = New-Object Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$js.MaxJsonLength = [int]::MaxValue

if ($NihongoIndex) {
  $line = [IO.File]::ReadAllLines($NihongoIndex, $u) | Where-Object { $_.StartsWith('const ANKI_V=[') } | Select-Object -First 1
  if ($line) { [IO.File]::WriteAllText("$here\anki-v.json", $line.Substring('const ANKI_V='.Length).TrimEnd().TrimEnd(';'), $u); 'Anki 덱을 새로 뽑았어요.' }
}

function Read-Cache([string]$file) {
  $c = @{}
  if (Test-Path $file) { $o = $js.DeserializeObject([IO.File]::ReadAllText($file, $u)); foreach ($k in $o.Keys) { $c[$k] = $o[$k] } }
  return $c
}
function Get-Json([string]$url, $headers) {
  $r = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -TimeoutSec 25
  $ms = New-Object IO.MemoryStream; $r.RawContentStream.CopyTo($ms)
  return $js.DeserializeObject([Text.Encoding]::UTF8.GetString($ms.ToArray()))
}
$cacheFile = "$here\naver-cache.json"; $cache = Read-Cache $cacheFile
$jishoFile = "$here\jisho-cache.json"; $jisho = Read-Cache $jishoFile
function Find-Naver([string[]]$queries) {
  $n = 0
  foreach ($q in $queries) {
    if (-not $q -or $cache.ContainsKey($q)) { continue }
    $o = Get-Json ("https://ja.dict.naver.com/api3/jako/search?query=" + [uri]::EscapeDataString($q) + "&m=pc&range=word&page=1") @{ 'User-Agent' = 'Mozilla/5.0'; 'Referer' = 'https://ja.dict.naver.com/' }
    $items = @()
    try { $items = $o['searchResultMap']['searchResultListMap']['WORD']['items'] } catch {}
    $keep = @()
    foreach ($it in ($items | Select-Object -First 8)) {
      $keep += ,@{ m = [string]$it['matchType']; e = [string]$it['expEntry']; k = [string]$it['expKanji']; f = [string]$it['frequencyAdd']; d = [string]$it['sourceDictnameKO'] }
    }
    $script:cache[$q] = $keep
    $n++
    if ($n % 50 -eq 0) { [IO.File]::WriteAllText($cacheFile, $js.Serialize($script:cache), $u); Write-Host "  네이버 검색 $($n)개…" }
    Start-Sleep -Milliseconds $DelayMs
  }
  if ($n) { [IO.File]::WriteAllText($cacheFile, $js.Serialize($script:cache), $u) }
  return $n
}
function Find-Jisho([string[]]$queries) {
  $n = 0
  foreach ($q in $queries) {
    if (-not $q -or $jisho.ContainsKey($q)) { continue }
    $o = Get-Json ("https://jisho.org/api/v1/search/words?keyword=" + [uri]::EscapeDataString($q)) @{ 'User-Agent' = 'Mozilla/5.0' }
    $keep = @()
    foreach ($d in ($o['data'] | Select-Object -First 6)) {
      $forms = @(); foreach ($f in $d['japanese']) { $forms += ,@([string]$f['word'], [string]$f['reading']) }
      $keep += ,@{ f = $forms; j = @($d['jlpt']); c = [bool]$d['is_common'] }
    }
    $script:jisho[$q] = $keep
    $n++
    if ($n % 40 -eq 0) { [IO.File]::WriteAllText($jishoFile, $js.Serialize($script:jisho), $u); Write-Host "  Jisho 검색 $($n)개…" }
    Start-Sleep -Milliseconds ($DelayMs + 100)
  }
  if ($n) { [IO.File]::WriteAllText($jishoFile, $js.Serialize($script:jisho), $u) }
  return $n
}

$prof = "$env:TEMP\rkjlpt"
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tools\test-server.ps1`"", '-Port', "$P", '-Root', "`"$root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'
  if (-not (Go $ws "http://localhost:$P/index.html" 'document.querySelector(".group")!==null&&document.readyState==="complete"' 40)) { throw '사이트가 열리지 않았어요.' }
  $terms = Eval $ws '(()=>{const seen=new Set(),out=[];for(const s of quizData().songs)for(const it of s.items){if(it.gram||!it.term||!it.mean||seen.has(it.term))continue;seen.add(it.term);out.push(it.term)}return JSON.stringify(out)})()'
  $termList = $js.DeserializeObject($terms)
  $plainOf = { param($t) [regex]::Replace([string]$t, '\{([^{}|]+)\|([^{}|]+)\}', '$1') }
  "퀴즈 단어 $($termList.Count)개"
  $new = Find-Naver ($termList | ForEach-Object { & $plainOf $_ } | Select-Object -Unique)
  "네이버에서 새로 찾은 단어 $($new)개"
  $resolve = [IO.File]::ReadAllText("$here\resolve.js", $u)
  $anki = [IO.File]::ReadAllText("$here\anki-v.json", $u)
  $list = [IO.File]::ReadAllText("$here\jlpt-list.json", $u)
  $manual = New-Object System.Collections.Generic.List[object]
  foreach ($l in [IO.File]::ReadAllLines("$here\manual.tsv", $u)) { if ($l.Trim() -and -not $l.StartsWith('#')) { $c = $l -split "`t"; $manual.Add(@($c[0], $c[1].Trim())) } }
  $run = {
    $null = Eval $ws ("window.CACHE=" + $js.Serialize($script:cache) + ";window.JISHO=" + $js.Serialize($script:jisho) + ";window.TERMS=" + $terms + ";window.ANKI=" + $anki + ";window.LIST=" + $list + ";window.MANUAL=" + $js.Serialize($manual) + ";1")
    return $js.DeserializeObject((Eval $ws $resolve))
  }
  $out = & $run
  # Jisho에서 더 찾을 말, 끝의 조사를 뗀 말(僕ら → 僕), manual.tsv에 적은 낱말을 찾아보고 다시 고른다
  for ($i = 0; $i -lt 3 -and ($out['need'].Count -or $out['jneed'].Count); $i++) {
    $n2 = Find-Naver $out['need']; $n3 = Find-Jisho $out['jneed']
    if (-not $n2 -and -not $n3) { break }
    "더 찾은 말: 네이버 $($n2)개, Jisho $($n3)개"
    $out = & $run
  }
  $map = $out['map']
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($k in $map.Keys) { $v = $map[$k]; $val = if ($v -is [string]) { '"' + $v + '"' } else { "$v" }; $lines.Add('  ' + $js.Serialize([string]$k) + ': ' + $val) }
  $head = [IO.File]::ReadAllText("$here\jlpt-head.txt", $u)
  $before = if (Test-Path "$root\jlpt.js") { [IO.File]::ReadAllText("$root\jlpt.js", $u) } else { '' }
  $body = $head + "window.JLPT = {`n" + ($lines -join ",`n") + "`n};`n"
  if ($body -eq $before) { "jlpt.js는 바뀐 것이 없어요(급수 $($lines.Count)개)." }
  else { [IO.File]::WriteAllText("$root\jlpt.js", $body, $u); "jlpt.js를 새로 썼어요(급수 $($lines.Count)개). GitHub에 jlpt.js를 올려 주세요." }
  $st = $out['stats']
  "네이버 $($st['naverLevel']) · Anki 덱 $($st['ankiOnly']['b'] + $st['ankiOnly']['m'] + $st['ankiOnly']['a']) · 공개 목록 $($st['list']) · Jisho $($st['jisho']) · 같은 낱말의 다른 모양 $($st['same']) · 이어진 표현(추정) $($st['phrase']) · 어림(추정) $($st['guess']) · 급수 안 붙임 $($st['none'])"
  if ($out['missing'].Count) { "manual.tsv에 적은 낱말의 급수를 못 찾은 것 $($out['missing'].Count)개: " + ($out['missing'] -join ' / ') }
  if ($out['todo'].Count) { "아직 분류하지 않은 단어 $($out['todo'].Count)개(manual.tsv에 적어 주세요): " + ($out['todo'] -join ' / ') }
  if ($Dump) {
    $sm = $out['samples']; $o = New-Object System.Collections.Generic.List[string]
    foreach ($k in 'list', 'jisho', 'same', 'phrase') { $o.Add("## $k"); foreach ($x in $sm[$k]) { $o.Add([string]$x) } }
    [IO.File]::WriteAllLines($Dump, $o, (New-Object Text.UTF8Encoding($true)))
  }
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'rkjlpt'
}
