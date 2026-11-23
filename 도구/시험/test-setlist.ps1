param([string]$Work, [string]$Site = 'site16', [int]$P = 8826, [int]$DebugPort = 9359)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = "$Work\$Site"
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$shots = "$Work\shots-sl"; New-Item -ItemType Directory -Force $shots | Out-Null
$prof = (Split-Path $Work) + '\ps1'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
$measure = @'
(()=>{const s=document.querySelector('.setlist').getBoundingClientRect();const r=q=>{const e=document.querySelector(q);if(!e)return 'none';const b=e.getBoundingClientRect();if(!b.width&&!b.height)return 'hidden';return Math.round(b.left-s.left)+','+Math.round(b.top-s.top)+','+Math.round(b.width)+'x'+Math.round(b.height)};return 'box='+Math.round(s.width)+'x'+Math.round(s.height)+' title='+r('.sl-title')+' meta='+r('.sl-meta')+' days='+r('.days')+' chev='+r('.sl-head .chev')+' list='+r('.sl-list')+' foot='+r('.sl-foot')+' rows='+document.querySelectorAll('.sl-list li').length})()
'@
$center = '(()=>{const b=document.querySelector("SEL").getBoundingClientRect();return Math.round(b.left+b.width/2)+","+Math.round(b.top+b.height/2)})()'
function Click-At($ws, [string]$Sel) {
  $xy = (Eval $ws ($center.Replace('SEL', $Sel))).Split(',')
  $x = [int]$xy[0]; $y = [int]$xy[1]
  $null = Invoke-Cdp $ws 'Input.dispatchMouseEvent' @{ type = 'mousePressed'; x = $x; y = $y; button = 'left'; clickCount = 1 }
  $null = Invoke-Cdp $ws 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = $x; y = $y; button = 'left'; clickCount = 1 }
  Start-Sleep -Milliseconds 350
}
function Press-Enter($ws) {
  $null = Invoke-Cdp $ws 'Input.dispatchKeyEvent' @{ type = 'keyDown'; key = 'Enter'; code = 'Enter'; windowsVirtualKeyCode = 13; nativeVirtualKeyCode = 13; text = "`r" }
  $null = Invoke-Cdp $ws 'Input.dispatchKeyEvent' @{ type = 'keyUp'; key = 'Enter'; code = 'Enter'; windowsVirtualKeyCode = 13; nativeVirtualKeyCode = 13 }
  Start-Sleep -Milliseconds 350
}
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'
  $null = Invoke-Cdp $ws 'Runtime.enable'
  $null = Invoke-Cdp $ws 'Log.enable'
  $mobile = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36'
  $desk = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
  $ready = 'document.querySelectorAll(".song").length>=26&&document.readyState==="complete"&&lyricState==="done"'
  $b = "http://localhost:$P/call/"
  $top = 'document.querySelector(".setlist").scrollIntoView({block:"start"});scrollBy(0,-110);1'
  $open = 'document.querySelector(".setlist").open'

  # before (original file) at 3 widths
  foreach ($c in @(@('pc', 1280, 900, $false), @('tab', 800, 900, $false), @('mob', 390, 844, $true))) {
    Set-Device $ws $c[1] $c[2] $c[3] $(if ($c[3]) { $mobile } else { $desk }) 'dark'
    $null = Go $ws ($b + 'before.html') $ready; $null = Eval $ws 'document.fonts.ready.then(()=>1)'; Start-Sleep -Milliseconds 500
    "BEFORE $($c[0]): " + (Eval $ws $measure)
    $null = Eval $ws $top; Start-Sleep -Milliseconds 300
    Shot $ws "$shots\before-$($c[0]).png"
  }

  # default state
  Set-Device $ws 1280 900 $false $desk 'dark'
  $null = Go $ws ($b + 'index.html') $ready; $null = Eval $ws 'document.fonts.ready.then(()=>1)'; Start-Sleep -Milliseconds 500
  'default: open=' + (Eval $ws $open) + ' songs=' + (Eval $ws 'document.querySelectorAll(".song").length') + ' saved=' + (Eval $ws 'String(localStorage.getItem("ryokulyrics:setlist"))')
  'closed pc: ' + (Eval $ws $measure)
  $null = Eval $ws $top; Start-Sleep -Milliseconds 300
  Shot $ws "$shots\pc-closed.png"

  # open with a real mouse click on the title
  Click-At $ws '.sl-title'
  'after title click: open=' + (Eval $ws $open) + ' saved=' + (Eval $ws 'String(localStorage.getItem("ryokulyrics:setlist"))')
  'open pc: ' + (Eval $ws $measure)
  $null = Eval $ws $top; Start-Sleep -Milliseconds 300
  Shot $ws "$shots\pc-open.png"

  # day buttons must not fold the box
  Click-At $ws '#day-1012'
  'after day2 click: open=' + (Eval $ws $open) + ' pressed=' + (Eval $ws '[...document.querySelectorAll(".day")].map(b=>b.getAttribute("aria-pressed")).join("/")') + ' row12=' + (Eval $ws 'document.querySelectorAll(".sl-list li")[11].querySelector(".sl-jp").textContent') + ' row14=' + (Eval $ws 'document.querySelectorAll(".sl-list li")[13].querySelector(".sl-jp").textContent')
  $null = Eval $ws 'document.querySelector(".days").dispatchEvent(new MouseEvent("click",{bubbles:true,cancelable:true}));1'; Start-Sleep -Milliseconds 300
  'after gap click: open=' + (Eval $ws $open)
  $null = Eval $ws 'document.getElementById("day-1011").focus();1'
  Press-Enter $ws
  'after Enter on day1: open=' + (Eval $ws $open) + ' pressed=' + (Eval $ws '[...document.querySelectorAll(".day")].map(b=>b.getAttribute("aria-pressed")).join("/")') + ' row12=' + (Eval $ws 'document.querySelectorAll(".sl-list li")[11].querySelector(".sl-jp").textContent')
  $null = Eval $ws 'document.querySelector(".sl-head").focus();1'
  Press-Enter $ws
  'after Enter on summary: open=' + (Eval $ws $open)
  Press-Enter $ws
  'after Enter again: open=' + (Eval $ws $open)

  # jump link
  Click-At $ws '.jump[data-id=hajimari]'
  Start-Sleep -Milliseconds 900
  'jump: songOpen=' + (Eval $ws 'document.getElementById("song-hajimari").open') + ' setlistOpen=' + (Eval $ws $open) + ' songTop=' + (Eval $ws 'Math.round(document.getElementById("song-hajimari").getBoundingClientRect().top)')

  # remembered open across sizes (+ shots), then ja
  foreach ($c in @(@('pc-light', 1280, 900, $false, 'light', ''), @('tab-800', 800, 900, $false, 'dark', ''), @('w641', 641, 900, $false, 'dark', ''), @('mobile-dark', 390, 844, $true, 'dark', ''), @('mobile-light', 390, 844, $true, 'light', ''), @('narrow', 320, 640, $true, 'dark', ''), @('ja-pc', 1280, 900, $false, 'dark', '?lang=ja'), @('ja-641', 641, 900, $false, 'dark', '?lang=ja'), @('ja-mobile', 390, 844, $true, 'dark', '?lang=ja'))) {
    Set-Device $ws $c[1] $c[2] $c[3] $(if ($c[3]) { $mobile } else { $desk }) $c[4]
    $null = Go $ws ($b + 'index.html' + $c[5]) $ready; $null = Eval $ws 'document.fonts.ready.then(()=>1)'; Start-Sleep -Milliseconds 500
    "$($c[0]) open=" + (Eval $ws $open) + ' overflow=' + (Eval $ws 'document.documentElement.scrollWidth>innerWidth') + ' ' + (Eval $ws $measure)
    $null = Eval $ws $top; Start-Sleep -Milliseconds 300
    Shot $ws "$shots\$($c[0])-open.png"
    $null = Eval $ws 'document.querySelector(".setlist").open=false;1'; Start-Sleep -Milliseconds 300
    "$($c[0]) closed " + (Eval $ws $measure)
    $null = Eval $ws $top; Start-Sleep -Milliseconds 300
    Shot $ws "$shots\$($c[0])-closed.png"
    $null = Eval $ws 'document.querySelector(".setlist").open=true;1'; Start-Sleep -Milliseconds 300
  }

  # close, reload: stays closed
  Set-Device $ws 1280 900 $false $desk 'dark'
  $null = Go $ws ($b + 'index.html') $ready; Start-Sleep -Milliseconds 400
  'reloaded: open=' + (Eval $ws $open)
  Click-At $ws '.sl-head .chev'
  'after chevron click: open=' + (Eval $ws $open) + ' saved=' + (Eval $ws 'String(localStorage.getItem("ryokulyrics:setlist"))')
  $null = Go $ws ($b + 'index.html?r=2') $ready; Start-Sleep -Milliseconds 400
  'reloaded after close: open=' + (Eval $ws $open)
  # arriving from the lyric page with a hash still works while folded
  $null = Go $ws ($b + 'index.html?r=3#song-mela') $ready; Start-Sleep -Milliseconds 900
  'hash arrive: songOpen=' + (Eval $ws 'document.getElementById("song-mela").open') + ' setlistOpen=' + (Eval $ws $open)
  # search still works
  $null = Eval $ws '(()=>{const q=document.getElementById("q");q.value="mela";q.dispatchEvent(new Event("input"));})();1'; Start-Sleep -Milliseconds 400
  'search mela: cards=' + (Eval $ws 'document.querySelectorAll(".song").length')
  'errors: ' + (($script:Errors | Where-Object { $_ -and $_ -notlike '*favicon*' -and $_ -notlike '*manifest*' -and $_ -notlike '*ERR_*' } | ForEach-Object { $_.Substring(0, [Math]::Min(170, $_.Length)) } | Select-Object -Unique) -join ' || ')
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\ps1'
}
