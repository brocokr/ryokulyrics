param([string]$Work, [string]$Site = 'site24', [int]$P = 8879, [int]$DebugPort = 9409)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = "$Work\$Site"
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$prof = (Split-Path $Work) + '\prm'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
function Hash($ws, $h) { $null = Eval $ws "location.hash='$h';1"; Start-Sleep -Milliseconds 700 }
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  Set-Device $ws 1100 900 $false '' 'light'
  $null = Go $ws "http://localhost:$P/index.html" 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  $all = Eval $ws '(()=>{const out=[];for(const n of [5,4])for(const q of levelBank(n).filter(q=>q.kind==="word"))out.push(RQ.reading(q.term)+" = "+RQ.romaji(q.term));return [...new Set(out)].sort().join("\n")})()'
  [IO.File]::WriteAllText("$Work\romaji-n45.txt", $all, (New-Object Text.UTF8Encoding($true)))
  'n4/n5 words: ' + ($all -split "`n").Count + ' empty: ' + @($all -split "`n" | Where-Object { $_ -match '= $' }).Count
  'read choices: ' + (Eval $ws '(()=>{const bad=[];let n=0;for(const l of [5,4])for(const q of levelBank(l).filter(q=>q.kind==="read"))for(const c of q.c){n++;const r=RQ.romaji(RQ.markRead(q.term,c));if(!r||/[^a-z'' ]/.test(r))bad.push(RQ.plain(q.term)+":"+c+"="+r)}return n+" choices, bad "+bad.length+" "+bad.slice(0,8).join(" | ")})()')
  'read right vs word: ' + (Eval $ws '(()=>{const d=[];for(const l of [5,4])for(const q of levelBank(l).filter(q=>q.kind==="read")){const a=RQ.romaji(q.term),b=RQ.romaji(RQ.markRead(q.term,q.c[0]));if(a!==b)d.push(RQ.plain(q.term)+" "+a+" / "+b)}return d.length+" "+d.slice(0,10).join(" | ")})()')
  foreach ($n in 5, 4, 3) {
    Hash $ws "#/quiz/n$n"
    "n${n}: button=" + (Eval $ws '(document.querySelector("[data-qrom]")||{}).textContent+" pressed="+(document.querySelector("[data-qrom]")?document.querySelector("[data-qrom]").getAttribute("aria-pressed"):"-")') + ' spans=' + (Eval $ws 'document.querySelectorAll(".qz-rom").length') + ' visible=' + (Eval $ws '[...document.querySelectorAll(".qz-rom")].filter(x=>x.offsetParent!==null).length')
  }
  Hash $ws '#/quiz/n5'
  $null = Eval $ws '(()=>{const i=qrun.list.findIndex(q=>q.kind==="word");[qrun.list[0],qrun.list[i]]=[qrun.list[i],qrun.list[0]];drawQuiz();return 1})()'
  Shot $ws "$Work\rom-off.png"
  $before = Eval $ws '[...document.querySelectorAll(".quiz-opt")].map(b=>b.textContent).join("|")'
  $null = Eval $ws 'document.querySelector("[data-qrom]").click();1'
  'after on: ' + (Eval $ws 'document.querySelector("[data-qrom]").textContent+" visible="+[...document.querySelectorAll(".qz-rom")].filter(x=>x.offsetParent!==null).map(x=>x.textContent).join(",")+" saved="+JSON.parse(localStorage.getItem("ryokushaka-lyrics:quiz")).rom') + ' same options=' + ($before -eq (Eval $ws '[...document.querySelectorAll(".quiz-opt")].map(b=>b.textContent).join("|")'))
  Shot $ws "$Work\rom-word.png"
  $null = Eval $ws 'document.querySelector("[data-qa]").click();1'
  'feedback: ' + (Eval $ws 'document.getElementById("qfb").innerText.replace(/\s+/g," ")')
  $null = Eval $ws '(()=>{const i=qrun.list.findIndex((q,k)=>k>0&&q.kind==="read");[qrun.list[1],qrun.list[i]]=[qrun.list[i],qrun.list[1]];document.querySelector("[data-qnext]").click();return 1})()'
  'read q: ' + (Eval $ws 'document.querySelector(".quiz-q").innerText.replace(/\s+/g," ")+" || "+[...document.querySelectorAll(".quiz-opt")].map(b=>b.innerText.replace(/\s+/g," ")).join(" / ")')
  Shot $ws "$Work\rom-read.png"
  # 새로고침해도 기억, 다른 퀴즈에는 없음
  $null = Go $ws "http://localhost:$P/index.html?y=1#/quiz/n4" 'document.querySelector("[data-qrom]")!==null'
  'reload keeps on: ' + (Eval $ws 'document.querySelector("[data-qrom]").getAttribute("aria-pressed")+" vis="+[...document.querySelectorAll(".qz-rom")].filter(x=>x.offsetParent!==null).length')
  Hash $ws '#/quiz/full1/1'
  'song quiz: button=' + (Eval $ws '!!document.querySelector("[data-qrom]")') + ' spans=' + (Eval $ws 'document.querySelectorAll(".qz-rom").length')
  Hash $ws '#/quiz/n3'
  'n3 while on: button=' + (Eval $ws '!!document.querySelector("[data-qrom]")') + ' spans=' + (Eval $ws 'document.querySelectorAll(".qz-rom").length')
  Hash $ws '#/quiz/n5'
  for ($i = 0; $i -lt 10; $i++) { $null = Eval $ws '(()=>{const o=[...document.querySelectorAll("[data-qa]")];if(!o.length)return 0;const w=qrun.opts.findIndex(x=>!x.ok);o[w].click();document.querySelector("[data-qnext]").click();return 1})()' }
  $null = Eval $ws 'document.querySelector("[data-qmiss]").click();1'
  'miss rerun button: ' + (Eval $ws '!!document.querySelector("[data-qrom]")')
  $null = Eval $ws 'document.querySelector("[data-qrom]").click();1'
  'off again: vis=' + (Eval $ws '[...document.querySelectorAll(".qz-rom")].filter(x=>x.offsetParent!==null).length+" saved="+JSON.parse(localStorage.getItem("ryokushaka-lyrics:quiz")).rom')
  'estimate label left: ' + (Eval $ws '(()=>{const Q=quizData();return Q.songs.flatMap(s=>s.bank).filter(q=>q.lv&&/추정/.test(lvText(q.lv))).length+" e-level text="+lvText("e3")})()')
  Set-Device $ws 390 844 $true '' 'dark'
  $null = Eval $ws 'qrec.rom=true;1'
  Hash $ws '#/quiz/n4'
  $null = Eval $ws '(()=>{const i=qrun.list.findIndex(q=>q.kind==="read");[qrun.list[0],qrun.list[i]]=[qrun.list[i],qrun.list[0]];drawQuiz();return 1})()'
  'mobile overflow: ' + (Eval $ws 'document.documentElement.scrollWidth')
  Shot $ws "$Work\rom-m.png"
  Set-Device $ws 320 700 $true '' 'light'
  Start-Sleep -Milliseconds 300
  'mobile 320 overflow: ' + (Eval $ws 'document.documentElement.scrollWidth')
  'errors: ' + (($script:Errors | Where-Object { $_ -and $_ -notlike '*favicon*' -and $_ -notlike '*manifest*' -and $_ -notlike '*ERR_*' } | ForEach-Object { $_.Substring(0, [Math]::Min(200, $_.Length)) } | Select-Object -Unique) -join ' || ')
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\prm'
}
