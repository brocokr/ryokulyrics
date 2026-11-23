param([string]$Work, [string]$Site, [int]$P = 8841, [int]$DebugPort = 9374)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = $Site
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$prof = (Split-Path $Work) + '\pm14'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  foreach ($d in @(@(1144, 700, $false, 'dark', 'home-1144-dark'), @(1144, 700, $false, 'light', 'home-1144'), @(860, 800, $false, 'light', 'home-860'), @(390, 1400, $true, 'light', 'home-390'))) {
    Set-Device $ws $d[0] $d[1] $d[2] '' $d[3]
    $null = Go $ws "http://localhost:$P/index.html" 'document.querySelector(".group")!==null&&document.readyState==="complete"'
    Start-Sleep -Milliseconds 1200
    $m = Eval $ws '(()=>{const r=e=>e.getBoundingClientRect();const k=r(document.querySelector(".kicker")),img=r(document.querySelector(".hero img")),b=[...document.querySelectorAll(".home-banners a")].map(a=>Math.round(r(a).bottom)),off=r(document.querySelector(".official")),cap=r(document.querySelector(".hero figcaption"));return "kickerTop="+Math.round(k.top)+" imgTop="+Math.round(img.top)+" bannersBottom="+b.join(",")+" officialBottom="+Math.round(off.bottom)+" capBottom="+Math.round(cap.bottom)+" sw="+document.documentElement.scrollWidth+" banners="+[...document.querySelectorAll(".home-banners b")].map(x=>x.textContent).join("|")})()'
    $d[4] + ': ' + $m
    Shot $ws "$Work\$($d[4]).png"
  }
  $null = Eval $ws '[...document.querySelectorAll(".home-banners a")][1].click();1'
  Start-Sleep -Milliseconds 600
  'click banner2: ' + (Eval $ws 'location.hash+" view="+document.body.dataset.view')
  $null = Go $ws "http://localhost:$P/index.html" 'document.querySelector(".group")!==null'; $null = Eval $ws 'document.querySelector("[data-lang=ja]").click();1'; Start-Sleep -Milliseconds 400; 'ja h1: ' + (Eval $ws 'document.querySelector(".top h1").innerText+" lede="+!!document.querySelector(".top .lede")'); Shot $ws "$Work\home-ja.png"; $null = Eval $ws 'document.querySelector("[data-lang=ko]").click();1'
  'errors: ' + (($script:Errors | Where-Object { $_ -and $_ -notlike '*favicon*' -and $_ -notlike '*manifest*' -and $_ -notlike '*ERR_*' } | Select-Object -Unique) -join ' || ')
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\pm14'
}