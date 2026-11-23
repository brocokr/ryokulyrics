# Finds Japanese titles that wrap in the middle of a word (a line break where there is no space and no <wbr>).
param([string]$Root = (Split-Path (Split-Path $PSScriptRoot)), [string]$Out = "$env:TEMP\ryoku-banner", [int]$P = 8891, [int]$D = 9421)
$ErrorActionPreference = 'Stop'
$work = $PSScriptRoot
. "$work\cdp.ps1"
$null = New-Item -ItemType Directory -Force $Out
$tool = (Split-Path $PSScriptRoot) + '\test-server.ps1'
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $D "$Out\pftt"
$bad = '(sel=>{const out=[];for(const e of document.querySelectorAll(sel)){if(!e.getClientRects().length)continue;const w=document.createTreeWalker(e,NodeFilter.SHOW_TEXT);let n;while(n=w.nextNode()){if(n.parentElement.closest(".read,.star"))continue;const s=n.data;let prev=null;for(let i=0;i<s.length;i++){const r=document.createRange();r.setStart(n,i);r.setEnd(n,i+1);const b=r.getBoundingClientRect();if(!b.width)continue;if(prev!==null&&b.top>prev+8&&!/[\s\u3001-]/.test(s[i-1]))out.push(s.slice(0,i)+"/"+s.slice(i));prev=b.top}}}return out.length+(out.length?" :: "+[...new Set(out)].join(" , "):"")})'
try {
  $ws = Connect-Page $D
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  $b = "http://localhost:$P"
  foreach ($wv in 1144, 900, 768, 430, 390, 360, 320) {
    Set-Device $ws $wv 900 ($wv -lt 761) '' 'dark'
    $null = Go $ws "$b/index.html" 'document.querySelector(".group")!==null&&document.readyState==="complete"'
    $null = Eval $ws 'document.fonts.ready.then(()=>1)'
    Start-Sleep -Milliseconds 700
    "$wv home: " + (Eval $ws ($bad + '(".album-title")'))
    $res = @()
    foreach ($k in (Eval $ws 'ALBUMS.filter(a=>a.tracks.length>1).map(a=>a.key).join(",")').Split(',')) {
      $null = Eval $ws "location.hash='#/a/$k';1"; Start-Sleep -Milliseconds 120
      $r = Eval $ws ($bad + '(".album-name,.tjp")')
      if ($r -ne '0') { $res += "$k $r" }
    }
    "$wv albums: " + $(if ($res) { $res -join ' ; ' } else { 'ok' })
    $null = Eval $ws "location.hash='#/quiz';1"; Start-Sleep -Milliseconds 700
    "$wv quiz: " + (Eval $ws ($bad + '(".qs-t")'))
    $res = @()
    foreach ($k in 'single7/1', 'full3/4', 'full5/7', 'mini1/5', 'single8/2', 'full5/13') {
      $null = Eval $ws "location.hash='#/s/$k';1"; Start-Sleep -Milliseconds 250
      $r = Eval $ws ($bad + '(".song-title,.pager span")')
      if ($r -ne '0') { $res += "$k $r" }
    }
    "$wv songs: " + $(if ($res) { $res -join ' ; ' } else { 'ok' })
    $null = Go $ws "$b/call/index.html?lang=ko" 'document.querySelector(".song")!==null'
    $null = Eval $ws 'document.querySelectorAll("details").forEach(d=>d.open=true);document.fonts.ready.then(()=>1)'
    Start-Sleep -Milliseconds 600
    "$wv call: " + (Eval $ws ($bad + '(".song-title,.sl-jp")'))
  }
  'errors: ' + (($script:Errors | Where-Object { $_ -notlike '*favicon*' -and $_ -notlike '*youtube*' } | Select-Object -Unique) -join ' || ')
} finally {
  Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue
  Stop-TestChrome 'pftt'
}
