# Japanese home screen: no Korean left, other screens stay Korean, layout lines up.
param([string]$Root = (Split-Path (Split-Path $PSScriptRoot)), [string]$Out = "$env:TEMP\ryoku-banner", [int]$P = 8881, [int]$D = 9411)
$ErrorActionPreference = 'Stop'
$work = $PSScriptRoot
. "$work\cdp.ps1"
$null = New-Item -ItemType Directory -Force $Out
$tool = (Split-Path $PSScriptRoot) + '\test-server.ps1'
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $D "$Out\pfja"
$left = '(()=>{const H=/[\uac00-\ud7a3]/;const out=[];const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;while(n=w.nextNode()){const p=n.parentElement;if(!p||p.closest("script,style"))continue;if(H.test(n.data)&&p.getClientRects().length)out.push(n.data.trim())}for(const e of document.body.querySelectorAll("[title],[aria-label],[placeholder],[alt]"))for(const a of ["title","aria-label","placeholder","alt"]){const v=e.getAttribute(a);if(v&&H.test(v)&&e.getClientRects().length)out.push(a+"="+v)}return out.join(" | ")})()'
try {
  $ws = Connect-Page $D
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  $b = "http://localhost:$P"
  Set-Device $ws 1144 760 $false '' 'dark'
  $null = Go $ws "$b/index.html" 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  'ko title: ' + (Eval $ws 'document.title') + ' lang=' + (Eval $ws 'String(document.getElementById("app").getAttribute("lang"))')
  $null = Eval $ws 'document.querySelector("[data-lang=ja]").click();document.querySelector(".tl").open=true;1'
  Start-Sleep -Milliseconds 1200
  'ja title: ' + (Eval $ws 'document.title') + ' lang=' + (Eval $ws 'document.getElementById("app").getAttribute("lang")')
  'korean left (home): ' + (Eval $ws $left)
  'footers: ' + (Eval $ws '[...document.querySelectorAll("footer")].map(f=>f.innerText).join(" / ")')
  'labels: ' + (Eval $ws '[...new Set([...document.querySelectorAll(".ord")].map(e=>e.textContent))].join(", ")')
  'meter: ' + (Eval $ws 'document.querySelectorAll(".meter-text")[1].innerText.replace(/\s+/g," ")')
  $null = Eval $ws 'document.querySelector(".tl").open=false;scrollTo(0,0);1'
  Start-Sleep -Milliseconds 500
  Shot $ws "$Out\ja-1144.png"
  # search
  $null = Eval $ws '(()=>{const q=document.getElementById("q");q.value="空";q.dispatchEvent(new Event("input"))})();1'
  Start-Sleep -Milliseconds 400
  'search: ' + (Eval $ws 'document.querySelector(".count").innerText+" first="+document.querySelector(".results li").innerText.replace(/\s+/g," ").slice(0,90)')
  $null = Eval $ws '(()=>{const q=document.getElementById("q");q.value="zzzzqq";q.dispatchEvent(new Event("input"))})();1'
  'search none: ' + (Eval $ws 'document.querySelector(".none").innerText')
  $null = Eval $ws '(()=>{const q=document.getElementById("q");q.value="시작의";q.dispatchEvent(new Event("input"))})();1'
  'search ko: ' + (Eval $ws 'document.querySelector(".results li").innerText.replace(/\s+/g," ").slice(0,90)')
  $null = Eval $ws '(()=>{const q=document.getElementById("q");q.value="";q.dispatchEvent(new Event("input"))})();1'
  # install sheet
  $null = Eval $ws 'openInstallSheet();1'
  Start-Sleep -Milliseconds 400
  'sheet left: ' + (Eval $ws '(()=>{const H=/[\uac00-\ud7a3]/;const s=document.getElementById("installSheet");const o=[];for(const t of s.querySelectorAll("[data-tab]")){t.click();o.push(t.textContent+":"+s.querySelector(".sheet-steps").innerText.replace(/\s+/g," ").slice(0,40))}return o.join(" || ")+" ## ko: "+[...s.querySelectorAll("*")].filter(e=>e.children.length===0&&H.test(e.textContent)).map(e=>e.textContent).join(",")})()')
  Shot $ws "$Out\ja-sheet.png"
  $null = Eval $ws 'document.getElementById("installSheet").close();1'
  # other screens stay Korean
  foreach ($h in @('#/a/full6', '#/quiz', '#/s/full1/2', '#/')) {
    $null = Eval $ws "location.hash='$h';1"
    Start-Sleep -Milliseconds 900
    "$h : " + (Eval $ws '"view="+document.body.dataset.view+" lang="+document.getElementById("app").getAttribute("lang")+" foot="+document.querySelector("footer.made-by").innerText+" nav="+([...document.querySelectorAll(".site-nav:not(.lang-switch) a")].map(a=>a.textContent).join(","))+" title="+document.title')
  }
  # reload keeps Japanese; widths
  foreach ($dv in @(@(1600, 900, $false), @(1144, 760, $false), @(1040, 760, $false), @(1000, 760, $false), @(960, 800, $false), @(930, 800, $false), @(900, 800, $false), @(800, 800, $false), @(768, 800, $false), @(700, 1500, $true), @(430, 1500, $true), @(390, 1500, $true), @(375, 1500, $true), @(360, 1500, $true), @(320, 1500, $true))) {
    Set-Device $ws $dv[0] $dv[1] $dv[2] '' 'light'
    $null = Go $ws "$b/index.html" 'document.querySelector(".group")!==null&&document.readyState==="complete"'
    $null = Eval $ws 'document.fonts.ready.then(()=>1)'
    Start-Sleep -Milliseconds 900
    $m = Eval $ws '(()=>{const r=s=>{const e=typeof s==="string"?document.querySelector(s):s;return e.getBoundingClientRect()};const q=s=>[...document.querySelectorAll(s)];const R=Math.round;return "bottoms="+R(r(".home-banners").bottom*10)/10+"/"+R(r(".official").bottom*10)/10+" titleTop="+q(".pban-t b").map(e=>R(r(e).top)).join(",")+" titleH="+q(".pban-t b").map(e=>R(r(e).height)).join(",")+" smallH="+q(".pban-t small").map(e=>R(r(e).height)).join(",")+" goTop="+q(".pban-go").map(e=>R(r(e).top)).join(",")+" goH="+q(".pban-go").map(e=>R(r(e).height)).join(",")+" goOver="+q(".pban-go").filter(e=>e.scrollWidth>e.clientWidth).length+" h1H="+R(r(".top h1").height)+" off="+(()=>{const m=new Map();q(".official a").forEach(a=>{const k=R(r(a).top);m.set(k,(m.get(k)||0)+1)});return [...m.values()].join("+")})()+" sw="+document.documentElement.scrollWidth})()'
    "$($dv[0]) ja: $m"
    Shot $ws "$Out\ja-$($dv[0]).png"
  }
  $null = Eval $ws 'document.querySelector("[data-lang=ko]").click();1'
  Start-Sleep -Milliseconds 500
  'back to ko: ' + (Eval $ws 'document.title+" "+document.querySelector("footer.copyright").innerText+" lang="+document.getElementById("app").getAttribute("lang")')
  'japanese UI left in ko: ' + (Eval $ws '[...document.querySelectorAll(".pban, .official, .members, .bar, .group > h2, .group > .sub, .tl summary, .app-row")].map(e=>e.innerText).join(" ").match(/[\u3040-\u30ff]+/g)')
  'errors: ' + (($script:Errors | Where-Object { $_ -notlike '*favicon*' } | Select-Object -Unique) -join ' || ')
} finally {
  Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue
  Stop-TestChrome 'pfja'
}
