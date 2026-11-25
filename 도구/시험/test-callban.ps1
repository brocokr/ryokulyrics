# Call guide banners: alignment at many widths, Korean and Japanese, links.
param([string]$Root = (Split-Path (Split-Path $PSScriptRoot)), [string]$Out = "$env:TEMP\ryoku-banner", [int]$P = 8961, [int]$D = 9491)
$ErrorActionPreference = 'Stop'
$work = $PSScriptRoot
. "$work\cdp.ps1"
$null = New-Item -ItemType Directory -Force $Out
$tool = (Split-Path $PSScriptRoot) + '\test-server.ps1'
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $D "$Out\pfcb"
try {
  $ws = Connect-Page $D
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  $b = "http://localhost:$P"
  foreach ($lg in 'ko', 'ja') {
    foreach ($wv in 1600, 1144, 1040, 1000, 800, 700, 641, 600, 430, 390, 360, 320) {
      Set-Device $ws $wv $(if ($wv -lt 641) { 1300 } else { 760 }) ($wv -lt 641) '' $(if ($lg -eq 'ko') { 'dark' } else { 'light' })
      $null = Go $ws "$b/call/index.html?lang=$lg" 'document.querySelector(".song")!==null'
      $null = Eval $ws 'document.fonts.ready.then(()=>1)'
      Start-Sleep -Milliseconds 900
      "$lg $wv " + (Eval $ws '(()=>{const R=x=>Math.round(x*10)/10,r=s=>document.querySelector(s).getBoundingClientRect();const L=r(".pban.lyrics"),N=r(".pban.ryoku"),G=r(".pban.ig"),P=r(".poster img"),K=r(".kicker"),T=r(".head-text");const t=s=>R(r(s+" .pban-t b").top);return "lyrics "+R(L.width)+"x"+R(L.height)+" note "+R(N.width)+"x"+R(N.height)+" ig "+R(G.width)+"x"+R(G.height)+" | tops kicker "+R(K.top)+" ig "+R(G.top)+" poster "+R(P.top)+" | bottoms lyrics "+R(L.bottom)+" note "+R(N.bottom)+" ig "+R(G.bottom)+" poster "+R(P.bottom)+" | rights ig "+R(G.right)+" note "+R(N.right)+" | titles "+t(".pban.lyrics")+","+t(".pban.ryoku")+","+t(".pban.ig")+" | sw "+document.documentElement.scrollWidth+" over "+[...document.querySelectorAll(".pban-go,.pban-t")].filter(e=>e.scrollWidth>e.clientWidth+1).length})()')
      Shot $ws "$Out\cb-$lg-$wv.png"
    }
  }
  'links: ' + (Eval $ws '[...document.querySelectorAll(".pban a")].map(a=>a.textContent.trim().replace(/\s+/g," ")+"="+a.getAttribute("href")+(a.target?"(new)":"")).join(" | ")')
  $null = Go $ws "$b/call/index.html?lang=ko" 'document.querySelector(".song")!==null'
  'ko links: ' + (Eval $ws '[...document.querySelectorAll(".pban-go a")].map(a=>a.textContent).join(" | ")')
  'songs: ' + (Eval $ws 'document.querySelectorAll(".song").length+" missing "+(document.body.innerText.match(/번째 줄을 찾지 못했어요/g)||[]).length')
  'errors: ' + (($script:Errors | Where-Object { $_ -notlike '*favicon*' } | Select-Object -Unique) -join ' || ')
} finally {
  Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue
  Stop-TestChrome 'pfcb'
}
