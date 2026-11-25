# Call guide setlist banner: closed/open, Korean/Japanese, widths, day buttons.
param([string]$Root = (Split-Path (Split-Path $PSScriptRoot)), [string]$Out = "$env:TEMP\ryoku-banner", [int]$P = 8981, [int]$D = 9511)
$ErrorActionPreference = 'Stop'
$work = $PSScriptRoot
. "$work\cdp.ps1"
$null = New-Item -ItemType Directory -Force $Out
$tool = (Split-Path $PSScriptRoot) + '\test-server.ps1'
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
if (Test-Path "$Out\pfsb") { Remove-Item -Recurse -Force "$Out\pfsb" -ErrorAction SilentlyContinue }
$null = Start-TestChrome $D "$Out\pfsb"
try {
  $ws = Connect-Page $D
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  $b = "http://localhost:$P"
  $mjs = '(()=>{const R=x=>Math.round(x*10)/10,r=s=>document.querySelector(s).getBoundingClientRect();const H=r(".sl-head"),T=r(".sl-title"),M=r(".sl-meta"),G=r(".sl-toggle"),D=r(".days");return "head "+R(H.width)+"x"+R(H.height)+" title "+R(T.top)+"-"+R(T.bottom)+" meta "+R(M.top)+"-"+R(M.bottom)+" toggle "+R(G.top)+"-"+R(G.bottom)+" ["+document.querySelector(".sl-toggle").innerText+"] days "+(D.width?R(D.top)+"-"+R(D.bottom):"hidden")+" gap above "+R(r(".setlist").top-Math.max(r(".pban.lyrics").bottom,r(".poster img").bottom))+" sw "+document.documentElement.scrollWidth+" over "+[...document.querySelectorAll(".sl-head,.days,.sl-toggle")].filter(e=>e.scrollWidth>e.clientWidth+1).length})()'
  foreach ($lg in 'ko', 'ja') {
    foreach ($wv in 1144, 800, 641, 390, 360, 320) {
      Set-Device $ws $wv $(if ($wv -lt 641) { 1500 } else { 900 }) ($wv -lt 641) '' $(if ($lg -eq 'ko') { 'dark' } else { 'light' })
      $null = Go $ws "$b/call/index.html?lang=$lg" 'document.querySelector(".song")!==null'
      $null = Eval $ws 'document.getElementById("setlist").open=false;document.fonts.ready.then(()=>1)'
      Start-Sleep -Milliseconds 900
      "$lg $wv closed: " + (Eval $ws $mjs)
      Shot $ws "$Out\sb-$lg-$wv-c.png"
      $null = Eval $ws 'document.querySelector(".sl-title").click();1'
      Start-Sleep -Milliseconds 400
      "$lg $wv open:   " + (Eval $ws ($mjs -replace '^\(\(\)=>\{', '(()=>{')) + ' rows ' + (Eval $ws 'document.querySelectorAll("#slList li").length')
      Shot $ws "$Out\sb-$lg-$wv-o.png"
    }
  }
  $null = Go $ws "$b/call/index.html?lang=ko" 'document.querySelector(".song")!==null'
  $null = Eval $ws 'document.getElementById("setlist").open=true;1'; Start-Sleep -Milliseconds 300
  'day switch: ' + (Eval $ws '(()=>{const t=()=>[...document.querySelectorAll("#slList .sl-jp")].map(e=>e.textContent)[11];const a=t();document.getElementById("day-1012").click();return a+" -> "+t()+" still open="+document.getElementById("setlist").open+" pressed="+document.querySelector(".day[aria-pressed=true]").textContent})()')
  'toggle by pill: ' + (Eval $ws '(()=>{document.querySelector(".sl-toggle").click();const a=document.getElementById("setlist").open;document.querySelector(".sl-toggle").click();return a+" -> "+document.getElementById("setlist").open})()')
  'caption left: ' + (Eval $ws 'document.querySelectorAll(".poster figcaption").length+" poster link "+document.querySelector(".poster a").getAttribute("href")')
  'errors: ' + (($script:Errors | Where-Object { $_ -notlike '*favicon*' } | Select-Object -Unique) -join ' || ')
} finally {
  Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue
  Stop-TestChrome 'pfsb'
}
