# home banners, official links and fonts: -Sizes (layout at many widths), -Pages -Fonts (fonts really used). Screenshots go to -Out.
param([string]$Root = (Split-Path (Split-Path $PSScriptRoot)), [string]$Out = "$env:TEMP\ryoku-banner", [int]$P = 8854, [int]$D = 9385, [switch]$Fonts, [switch]$Sizes, [switch]$Pages)
$ErrorActionPreference = 'Stop'
$work = $PSScriptRoot
. "$work\cdp.ps1"
$null = New-Item -ItemType Directory -Force $Out
$tool = (Split-Path $PSScriptRoot) + '\test-server.ps1'
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $D "$Out\pf4"
try {
  $ws = Connect-Page $D
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  $b = "http://localhost:$P"
  if ($Sizes) {
    foreach ($dv in @(@(1600, 900, $false, 'dark'), @(1144, 760, $false, 'light'), @(1040, 760, $false, 'dark'), @(1000, 800, $false, 'light'), @(900, 800, $false, 'light'), @(800, 900, $false, 'dark'), @(761, 900, $false, 'light'), @(700, 1500, $true, 'light'), @(430, 1500, $true, 'dark'), @(390, 1500, $true, 'light'), @(360, 1500, $true, 'dark'), @(320, 1500, $true, 'light'))) {
      Set-Device $ws $dv[0] $dv[1] $dv[2] '' $dv[3]
      $null = Go $ws "$b/index.html" 'document.querySelector(".group")!==null&&document.readyState==="complete"'
      $null = Eval $ws 'document.fonts.ready.then(()=>1)'
      Start-Sleep -Milliseconds 900
      $m = Eval $ws '(()=>{const r=s=>{const e=typeof s==="string"?document.querySelector(s):s;return e.getBoundingClientRect()};const q=s=>[...document.querySelectorAll(s)];const R=Math.round;return "kicker="+R(r(".kicker").top)+" img="+R(r(".hero img").top)+" | bannersBottom="+R(r(".home-banners").bottom*10)/10+" officialBottom="+R(r(".official").bottom*10)/10+" | pic="+q(".pban-pic").map(e=>R(r(e).width)+"x"+R(r(e).height)).join(",")+" | titleTop="+q(".pban-t b").map(e=>R(r(e).top)).join(",")+" | smallH="+q(".pban-t small").map(e=>R(r(e).height)).join(",")+" | goTop="+q(".pban-go").map(e=>R(r(e).top)).join(",")+" goH="+q(".pban-go").map(e=>R(r(e).height)).join(",")+" | h1H="+R(r(".top h1").height)+" | off="+(()=>{const m=new Map();q(".official a").forEach(a=>{const k=R(r(a).top);m.set(k,(m.get(k)||0)+1)});return [...m.values()].join("+")})()+" trunc="+q(".members b,.official a,.pban-go a").filter(e=>e.scrollWidth>e.clientWidth+1).length+" | sw="+document.documentElement.scrollWidth})()'
      "$($dv[0]): $m"
      Shot $ws "$Out\s-$($dv[0]).png"
    }
  }
  if ($Pages) {
    Set-Device $ws 1144 900 $false '' 'light'
    $list = @(
      @('home', '/index.html', 'document.querySelector(".group")!==null'),
      @('album', '/index.html#/a/full6', 'document.querySelector(".tracks")!==null'),
      @('song', '/index.html#/s/full6/8', 'document.querySelector(".song-title")!==null'),
      @('quiz', '/index.html#/quiz', 'document.querySelector(".quiz-songs")!==null'),
      @('quizn5', '/index.html#/quiz/n5', 'document.querySelector(".quiz-card")!==null'),
      @('quizall', '/index.html#/quiz/all', 'document.querySelector(".quiz-card")!==null'),
      @('call', '/call/index.html', 'document.querySelector(".song")!==null'),
      @('callja', '/call/index.html?lang=ja', 'document.querySelector(".song")!==null'),
      @('callko', '/call/index.html?lang=ko', 'document.querySelector(".song")!==null'))
    foreach ($x in $list) {
      $null = Go $ws 'about:blank'
      $ok = Go $ws ($b + $x[1]) $x[2]
      $null = Eval $ws 'document.querySelectorAll("details").forEach(d=>d.open=true);document.querySelectorAll(".study-btn").forEach((b,i)=>{if(i<4)b.click()});document.fonts.ready.then(()=>1)'
      Start-Sleep -Milliseconds 1500
      $null = Eval $ws 'document.fonts.ready.then(()=>1)'
      Shot $ws "$Out\p-$($x[0]).png"
      if ($Fonts) {
        $null = Invoke-Cdp $ws 'DOM.enable'; $null = Invoke-Cdp $ws 'CSS.enable'
        $doc = Invoke-Cdp $ws 'DOM.getDocument' @{ depth = 0 }
        $null = Eval $ws 'document.querySelectorAll("*").forEach(e=>{if([...e.childNodes].some(n=>n.nodeType===3&&n.data.trim())&&e.getClientRects().length)e.setAttribute("data-tt","1")});1'
        $ids = (Invoke-Cdp $ws 'DOM.querySelectorAll' @{ nodeId = $doc['root']['nodeId']; selector = 'body [data-tt]' })['nodeIds']
        $sum = @{}
        $odd = @()
        $k = 0
        foreach ($id in $ids) {
          $k++; if ($k -gt 900) { break }
          $r = Invoke-Cdp $ws 'CSS.getPlatformFontsForNode' @{ nodeId = $id }
          foreach ($f in $r['fonts']) {
            $name = $f['familyName']
            $sum[$name] = [int]$sum[$name] + [int]$f['glyphCount']
            if ($name -notlike 'Noto Sans*' -and $odd.Count -lt 12) { $h = (Invoke-Cdp $ws 'DOM.getOuterHTML' @{ nodeId = $id })['outerHTML']; $odd += "$name :: " + $h.Substring(0, [Math]::Min(150, $h.Length)) }
          }
        }
        "$($x[0]) ok=$ok nodes=$($ids.Count) fonts: " + (($sum.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')
        $odd
      } else { "$($x[0]) ok=$ok" }
    }
  }
  'errors: ' + (($script:Errors | Where-Object { $_ -notlike '*favicon*' } | Select-Object -Unique) -join ' || ')
} finally {
  Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue
  Stop-TestChrome 'ryoku-banner\pf4'
}
