param([string]$Work, [int]$P = 8833, [int]$DebugPort = 9366)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = "$Work\site16"
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$prof = (Split-Path $Work) + '\pm10'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
$st = 'JSON.stringify({theme:document.documentElement.dataset.theme||"",pressed:(document.querySelector(".theme-btn")||{getAttribute:()=>"none"}).getAttribute("aria-pressed"),title:(document.querySelector(".theme-btn")||{}).title,bg:getComputedStyle(document.body).backgroundColor,saved:localStorage.getItem("ryokulyrics:theme"),meta:[...document.querySelectorAll("meta[name=theme-color]")].map(m=>m.content).join(",")})'
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  Set-Device $ws 1144 700 $false '' 'light'
  $b = "http://localhost:$P/"
  $null = Go $ws ($b + 'index.html') 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  Start-Sleep -Milliseconds 800
  'home start: ' + (Eval $ws $st)
  $null = Eval $ws 'document.querySelector(".theme-btn").click();1'
  'home after click: ' + (Eval $ws $st)
  Shot $ws "$Work\theme-home-dark.png"
  $null = Go $ws ($b + 'call/index.html') 'document.readyState==="complete"'
  Start-Sleep -Milliseconds 600
  'call loaded: ' + (Eval $ws $st)
  $null = Eval $ws 'document.querySelector(".theme-btn").click();1'
  'call after click: ' + (Eval $ws $st)
  Shot $ws "$Work\theme-call-light.png"
  Set-Device $ws 1144 700 $false '' 'dark'
  $null = Go $ws ($b + 'index.html#/quiz') 'document.querySelector(".quiz-song")!==null'
  Start-Sleep -Milliseconds 600
  'quiz with system dark but saved light: ' + (Eval $ws $st)
  $null = Eval $ws 'localStorage.removeItem("ryokulyrics:theme");1'
  $null = Go $ws ($b + 'index.html') 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  Start-Sleep -Milliseconds 600
  'home no saved, system dark: ' + (Eval $ws $st)
  $null = Eval $ws 'document.querySelector("[data-lang=ja]").click();1'
  'home ja: ' + (Eval $ws $st)
  $null = Eval $ws 'document.querySelector("[data-lang=ko]").click();1'
  Set-Device $ws 390 844 $true '' 'light'
  $null = Go $ws ($b + 'index.html') 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  Start-Sleep -Milliseconds 600
  'mobile: sw=' + (Eval $ws 'document.documentElement.scrollWidth') + ' ' + (Eval $ws $st)
  Shot $ws "$Work\theme-mobile.png"
  $null = Go $ws ($b + 'call/index.html') 'document.readyState==="complete"'
  Start-Sleep -Milliseconds 600
  'mobile call: sw=' + (Eval $ws 'document.documentElement.scrollWidth')
  Shot $ws "$Work\theme-call-mobile.png"
  'errors: ' + (($script:Errors | Where-Object { $_ -and $_ -notlike '*favicon*' -and $_ -notlike '*manifest*' -and $_ -notlike '*ERR_*' } | Select-Object -Unique) -join ' || ')
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\pm10'
}