param([string]$Work, [string]$Site = 'site16', [int]$P = 8824, [int]$DebugPort = 9357)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = "$Work\$Site"
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$shots = "$Work\shots-tl2"; New-Item -ItemType Directory -Force $shots | Out-Null
$prof = (Split-Path $Work) + '\pt2'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'
  $null = Invoke-Cdp $ws 'Runtime.enable'
  $null = Invoke-Cdp $ws 'Log.enable'
  $mobile = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36'
  $desk = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
  $ready = 'document.querySelector(".tl")!==null&&document.querySelector(".group")!==null&&document.readyState==="complete"'
  $b = "http://localhost:$P/"
  Set-Device $ws 1280 900 $false $desk 'dark'
  $null = Go $ws ($b + 'index.html?t=1') $ready; Start-Sleep -Milliseconds 800
  'default: open=' + (Eval $ws 'document.querySelector(".tl").open') + ' height=' + (Eval $ws 'Math.round(document.querySelector(".tl").getBoundingClientRect().height)') + ' groups=' + (Eval $ws 'document.querySelectorAll(".group").length') + ' albums=' + (Eval $ws 'document.querySelectorAll(".album").length') + ' summary=' + (Eval $ws 'document.querySelector(".tl summary").innerText.replace(/\s+/g," ")')
  $null = Eval $ws 'document.querySelector(".tl").scrollIntoView({block:"start"});scrollBy(0,-90);1'; Start-Sleep -Milliseconds 400
  Shot $ws "$shots\pc-closed.png"
  $null = Eval $ws 'document.querySelector(".tl summary").click();1'; Start-Sleep -Milliseconds 500
  'opened: open=' + (Eval $ws 'document.querySelector(".tl").open') + ' height=' + (Eval $ws 'Math.round(document.querySelector(".tl").getBoundingClientRect().height)') + ' years=' + (Eval $ws '[...document.querySelectorAll(".year")].map(y=>y.querySelector(".year-y").textContent+":"+y.querySelectorAll(".rel").length).join(" ")') + ' rels=' + (Eval $ws 'document.querySelectorAll(".rel").length') + ' covers=' + (Eval $ws '[...document.querySelectorAll(".cover.thumb")].filter(c=>!c.classList.contains("none")).length')
  'links: ' + (Eval $ws '[...document.querySelectorAll(".rel")].map(a=>a.getAttribute("href")).join(" ")')
  foreach ($c in @(@('pc-dark', 1280, 900, $false, 'dark'), @('pc-light', 1280, 900, $false, 'light'), @('tab-800', 800, 900, $false, 'dark'), @('mobile-dark', 390, 844, $true, 'dark'), @('mobile-light', 390, 844, $true, 'light'), @('narrow', 320, 640, $true, 'dark'))) {
    Set-Device $ws $c[1] $c[2] $c[3] $(if ($c[3]) { $mobile } else { $desk }) $c[4]
    $null = Go $ws ($b + "index.html?s=" + $c[0]) $ready; Start-Sleep -Milliseconds 700
    "$($c[0]) remembered open=" + (Eval $ws 'document.querySelector(".tl").open') + ' overflow=' + (Eval $ws 'document.documentElement.scrollWidth>innerWidth') + ' height=' + (Eval $ws 'Math.round(document.querySelector(".tl").getBoundingClientRect().height)') + ' clipped=' + (Eval $ws '[...document.querySelectorAll(".rel-title")].filter(e=>e.scrollWidth>e.clientWidth+1).length')
    $null = Eval $ws 'document.querySelector(".tl").scrollIntoView({block:"start"});scrollBy(0,-90);1'; Start-Sleep -Milliseconds 400
    Shot $ws "$shots\$($c[0]).png"
  }
  Set-Device $ws 1280 900 $false $desk 'dark'
  $null = Go $ws ($b + 'index.html?k=1') $ready; Start-Sleep -Milliseconds 500
  $null = Eval $ws '(()=>{const q=document.getElementById("q");q.value="starry";q.dispatchEvent(new Event("input"));})();1'; Start-Sleep -Milliseconds 400
  'search: results=' + (Eval $ws 'document.querySelectorAll(".results a").length') + ' tl=' + (Eval $ws 'document.querySelectorAll(".tl").length')
  $null = Eval $ws '(()=>{const q=document.getElementById("q");q.value="";q.dispatchEvent(new Event("input"));})();1'; Start-Sleep -Milliseconds 300
  $null = Eval $ws 'document.querySelector(".tl summary").click();1'; Start-Sleep -Milliseconds 400
  $null = Go $ws ($b + 'index.html?k=2') $ready; Start-Sleep -Milliseconds 500
  'closed and reloaded: open=' + (Eval $ws 'document.querySelector(".tl").open')
  $null = Eval $ws 'document.querySelector(".tl summary").click();1'; Start-Sleep -Milliseconds 300
  $null = Eval $ws 'document.querySelectorAll(".rel")[3].click();1'; Start-Sleep -Milliseconds 800
  'card click -> ' + (Eval $ws 'location.hash') + ' view=' + (Eval $ws 'document.body.dataset.view')
  'errors: ' + (($script:Errors | Where-Object { $_ -and $_ -notlike '*favicon*' -and $_ -notlike '*manifest*' -and $_ -notlike '*ERR_*' } | ForEach-Object { $_.Substring(0, [Math]::Min(170, $_.Length)) } | Select-Object -Unique) -join ' || ')
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\pt2'
}
