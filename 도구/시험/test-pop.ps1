# Popularity ranking and streaming counts (streams.js): home panel, song page, study/quiz order, refresh.
param([string]$Root = (Split-Path (Split-Path $PSScriptRoot)), [string]$Out = "$env:TEMP\ryoku-banner", [int]$P = 9141, [int]$D = 9661)
$ErrorActionPreference = 'Stop'
$work = $PSScriptRoot
. "$work\cdp.ps1"
$null = New-Item -ItemType Directory -Force $Out
$tool = (Split-Path $PSScriptRoot) + '\test-server.ps1'
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
if (Test-Path "$Out\pfpop") { Remove-Item -Recurse -Force "$Out\pfpop" -ErrorAction SilentlyContinue }
$null = Start-TestChrome $D "$Out\pfpop"
try {
  $ws = Connect-Page $D
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  $b = "http://localhost:$P"
  $ready = 'document.querySelector("[data-fold=pop]")!==null'
  Set-Device $ws 1144 1000 $false '' 'dark'
  $null = Go $ws "$b/index.html" $ready
  $null = Eval $ws 'document.fonts.ready.then(()=>1)'
  Start-Sleep -Milliseconds 600
  'first visit: open ' + (Eval $ws 'document.querySelector("[data-fold=pop]").open') + ' | ' + (Eval $ws 'document.querySelector("[data-fold=pop] summary").innerText.replace(/\s+/g," ")') + ' | songs ' + (Eval $ws 'STREAMS.list.length') + ' base ' + (Eval $ws 'STREAMS.updated')
  $v = 'document.querySelector("[data-fold=pop] summary [data-live]").textContent'
  $x1 = Eval $ws $v; Start-Sleep -Milliseconds 3000; $x2 = Eval $ws $v
  "ticks: $x1 -> $x2"
  $null = Eval $ws 'document.querySelector("[data-fold=pop] summary").scrollIntoView({block:"start"});scrollBy(0,-160);1'
  Start-Sleep -Milliseconds 300
  Shot $ws "$Out\pop-closed-1144.png"
  $null = Eval $ws 'document.querySelector("[data-fold=pop] summary").click();1'; Start-Sleep -Milliseconds 500
  Shot $ws "$Out\pop-open-1144.png"
  'top10: ' + (Eval $ws '[...document.querySelectorAll(".pop")].map(a=>a.querySelector(".pop-n").textContent+" "+a.querySelector(".pop-jp").textContent+" "+a.querySelector(".pop-c").innerText.replace(/\s+/g," ")+" "+a.getAttribute("href")).join(" | ")')
  'live matches formula: ' + (Eval $ws '[...document.querySelectorAll(".pop [data-live]")].every(e=>{const s=STREAMS.by[e.dataset.live],v=Number(e.textContent.replace(/,/g,""));return Math.abs(v-(s.n+s.d*(Date.now()-STREAMS.base)/864e5))<3+s.d/86400})')
  'covers loaded: ' + (Eval $ws '[...document.querySelectorAll(".pop img")].map(i=>i.naturalWidth>0).join(",")')
  $null = Eval $ws 'document.querySelector("[data-pop-sort=day]").click();1'; Start-Sleep -Milliseconds 300
  'day: ' + (Eval $ws '[...document.querySelectorAll(".pop")].map(a=>a.querySelector(".pop-n").textContent+" "+a.querySelector(".pop-jp").textContent+" "+a.querySelector(".pop-c").innerText.replace(/\s+/g," ")).join(" | ")') + ' focus ' + (Eval $ws 'document.activeElement.dataset.popSort')
  Shot $ws "$Out\pop-day-1144.png"
  $null = Eval $ws 'document.querySelector("[data-pop-sort=total]").click();document.querySelector("[data-pop-all]").click();1'; Start-Sleep -Milliseconds 400
  'all: ' + (Eval $ws 'document.querySelectorAll(".pop").length+" sorted "+[...document.querySelectorAll(".pop")].every((a,i,l)=>!i||Number(l[i-1].querySelector("[data-live]").textContent.replace(/,/g,""))>=Number(a.querySelector("[data-live]").textContent.replace(/,/g,"")))+" links ok "+[...document.querySelectorAll(".pop")].every(a=>{const[,,k,n]=a.getAttribute("href").split("/");return !!(byKey[k]&&byKey[k].tracks[n-1])})+" "+document.querySelector("[data-pop-all]").textContent')
  Shot $ws "$Out\pop-all-1144.png"
  $null = Eval $ws 'document.querySelector("[data-pop-all]").click();1'; Start-Sleep -Milliseconds 300
  'back to 10: ' + (Eval $ws 'document.querySelectorAll(".pop").length')
  $null = Go $ws 'about:blank'; $null = Go $ws "$b/index.html" $ready; Start-Sleep -Milliseconds 400
  'remembered open: ' + (Eval $ws 'document.querySelector("[data-fold=pop]").open+" timeline "+document.querySelector("[data-fold=tl]").open')
  $null = Eval $ws 'document.querySelector("[data-fold=tl] summary").click();1'; Start-Sleep -Milliseconds 300
  'timeline click: ' + (Eval $ws 'JSON.stringify([prefs.pop,prefs.tl])')
  $null = Eval $ws 'document.querySelector("[data-fold=tl] summary").click();1'
  $null = Eval $ws 'document.querySelector("[data-lang=ja]").click();1'; Start-Sleep -Milliseconds 500
  'ja: ' + (Eval $ws 'document.querySelector("[data-fold=pop]").innerText.replace(/\s+/g," ").slice(0,200)+" ... "+document.querySelector(".pop-note").innerText+" hangul "+/[가-힣]/.test(document.querySelector("[data-fold=pop]").innerText)')
  $null = Eval $ws 'document.querySelector("[data-pop-all]").click();1'; Start-Sleep -Milliseconds 200
  'ja all hangul: ' + (Eval $ws '/[가-힣]/.test(document.querySelector("[data-fold=pop]").innerText)+" "+document.querySelector("[data-pop-all]").textContent')
  $null = Eval $ws 'document.querySelector("[data-pop-all]").click();1'
  $null = Eval $ws 'document.querySelector("[data-fold=pop] summary").scrollIntoView({block:"start"});scrollBy(0,-60);1'; Start-Sleep -Milliseconds 200
  Shot $ws "$Out\pop-ja-1144.png"
  $null = Eval $ws 'document.querySelector("[data-lang=ko]").click();1'; Start-Sleep -Milliseconds 300
  foreach ($wv in 1144, 900, 861, 860, 768, 481, 480, 390, 360, 320) {
    Set-Device $ws $wv $(if ($wv -lt 761) { 1400 } else { 1000 }) ($wv -lt 761) '' $(if ($wv -in 900, 390) { 'light' } else { 'dark' })
    $null = Go $ws 'about:blank'; $null = Go $ws "$b/index.html" $ready
    $null = Eval $ws 'document.fonts.ready.then(()=>1)'; Start-Sleep -Milliseconds 400
    $null = Eval $ws 'document.querySelector("[data-pop-all]").click();document.querySelector("[data-fold=pop] summary").scrollIntoView({block:"start"});scrollBy(0,-20);1'; Start-Sleep -Milliseconds 300
    "$wv : sw " + (Eval $ws 'document.documentElement.scrollWidth+" over "+[...document.querySelectorAll(".pop")].filter(a=>a.scrollWidth>a.clientWidth+1).length+" titles 3+ lines "+[...document.querySelectorAll(".pop-jp")].filter(e=>e.getClientRects().length>2).map(e=>e.textContent).join(",")+" row h "+[...new Set([...document.querySelectorAll(".pop-list li")].map(e=>Math.round(e.getBoundingClientRect().height)))].join(",")+" sum h "+Math.round(document.querySelector("[data-fold=pop] summary").getBoundingClientRect().height)+" min gap "+Math.min(...[...document.querySelectorAll(".pop")].map(a=>{const t=a.querySelector(".pop-jp").getBoundingClientRect(),c=a.querySelector(".pop-c").getBoundingClientRect();return Math.round(Math.abs(t.top-c.top)<30&&c.left>t.left+5?c.left-t.right:99)}))')
    Shot $ws "$Out\pop-$wv.png"
  }
  # song page
  foreach ($wv in 1144, 390, 320) {
    Set-Device $ws $wv $(if ($wv -lt 761) { 1000 } else { 800 }) ($wv -lt 761) '' 'dark'
    foreach ($h in 'full3/5', 'full6/8') {
      $null = Go $ws 'about:blank'; $null = Go $ws "$b/index.html#/s/$h" 'document.querySelector(".song-head")!==null'; Start-Sleep -Milliseconds 500
      "$wv song $h : " + (Eval $ws '(document.querySelector(".song-plays")||{innerText:"-"}).innerText.replace(/\s+/g," ")+" sw "+document.documentElement.scrollWidth')
      Shot $ws ("$Out\pop-song-$wv-" + ($h -replace '/', '') + '.png')
    }
  }
  'songs without plays: ' + (Eval $ws 'ALL.filter(t=>!t.inst&&!streamOf(t)).map(t=>t.jp).filter((x,i,a)=>a.indexOf(x)===i).join(", ")')
  'names not matched: ' + (Eval $ws 'STREAMS_DATA.tracks.filter(([n])=>!STREAMS.by[norm(STREAM_NAMES[n]||n)]).map(x=>x[0]).join(", ")')
  # lists
  foreach ($wv in 1144, 390, 320) {
    Set-Device $ws $wv $(if ($wv -lt 761) { 1500 } else { 1000 }) ($wv -lt 761) '' 'dark'
    foreach ($h in 'study', 'quiz') {
      $null = Eval $ws 'localStorage.setItem("ryokushaka-lyrics:prefs", JSON.stringify({...prefs, songSort:"album"}));1'
      $null = Go $ws 'about:blank'; $null = Go $ws "$b/index.html#/$h" 'document.querySelector(".song-sort")!==null'
      $null = Eval $ws 'document.fonts.ready.then(()=>1)'; Start-Sleep -Milliseconds 400
      $n1 = Eval $ws 'document.querySelectorAll(".quiz-song").length+" in "+document.querySelectorAll(".quiz-songs").length'
      $null = Eval $ws 'document.querySelector(".song-sort").scrollIntoView({block:"start"});scrollBy(0,-120);1'; Start-Sleep -Milliseconds 200
      Shot $ws "$Out\pop-$h-album-$wv.png"
      $y1 = Eval $ws 'Math.round(document.querySelector(".song-sort").getBoundingClientRect().top)'
      $null = Eval $ws 'document.querySelector("[data-song-sort=pop]").click();1'; Start-Sleep -Milliseconds 400
      $y2 = Eval $ws 'Math.round(document.querySelector(".song-sort").getBoundingClientRect().top)'
      "$wv $h : album $n1 -> pop " + (Eval $ws 'document.querySelectorAll(".quiz-song").length+" in "+document.querySelectorAll(".quiz-songs").length+", ranks "+[...document.querySelectorAll(".qs-rank")].map(e=>e.textContent).join(" ")+", no data "+[...document.querySelectorAll(".quiz-song")].filter(e=>!e.querySelector(".qs-rank")).map(e=>e.querySelector(".qs-t").textContent).join(",")+" sw "+document.documentElement.scrollWidth+" over "+[...document.querySelectorAll(".quiz-song")].filter(a=>a.scrollWidth>a.clientWidth+1).length+" focus "+document.activeElement.dataset.songSort') + " toggle moved $y1 -> $y2"
      Shot $ws "$Out\pop-$h-pop-$wv.png"
    }
  }
  # no data file
  $null = Eval $ws 'STREAMS=null;location.hash="#/";1'; Start-Sleep -Milliseconds 400
  'no data: home panel ' + (Eval $ws 'document.querySelector("[data-fold=pop]")===null&&document.querySelector("[data-fold=tl]")!==null&&document.querySelectorAll(".album").length')
  $null = Eval $ws 'location.hash="#/study";1'; Start-Sleep -Milliseconds 400
  'no data: study ' + (Eval $ws 'document.querySelector(".song-sort")===null&&document.querySelectorAll(".quiz-songs").length')
  # newer file from the repository
  'refresh: ' + (Eval $ws '(async()=>{setStreams(STREAMS_DATA);const f=window.fetch;window.fetch=async()=>new Response("window.STREAMS_DATA = "+JSON.stringify({updated:"2026-11-24",total:[900000000,450000],tracks:[["Mela!",188000000,70000]]})+";\n");await refreshStreams();const a=STREAMS.updated+" "+STREAMS.list.length;window.fetch=async()=>new Response("broken");await refreshStreams();const b=STREAMS.updated;window.fetch=async()=>{throw new Error("x")};await refreshStreams();window.fetch=f;setStreams(STREAMS_DATA);return a+" / "+b+" / old ignored "+STREAMS.updated})()')
  'bad data: ' + (Eval $ws '(()=>{const k=STREAMS;STREAMS=null;const r=[undefined,{},{updated:"x"},{updated:"2026-01-01",tracks:1}].map(d=>{setStreams(d);return STREAMS===null}).join(",");STREAMS=k;return r})()')
  'errors: ' + (($script:Errors | Where-Object { $_ -notlike '*favicon*' } | Select-Object -Unique) -join ' || ')
} finally {
  Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue
  Stop-TestChrome 'pfpop'
}
