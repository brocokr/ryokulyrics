param([string]$Work, [string]$Site = 'site24', [int]$P = 8871, [int]$DebugPort = 9401)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = "$Work\$Site"
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$prof = (Split-Path $Work) + '\pq2'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
function Hash($ws, $h) { $null = Eval $ws "location.hash='$h';1"; Start-Sleep -Milliseconds 700 }
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  Set-Device $ws 1100 900 $false '' 'light'
  $b = "http://localhost:$P/"
  # 예전 기록(해석 포함)이 있는 상태로 시작
  $null = Go $ws ($b + 'index.html') 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  $null = Eval $ws 'localStorage.setItem("ryokushaka-lyrics:quiz",JSON.stringify({kinds:["word","line","read"],n:10,best:{},wrong:{"full1-1:lzzz":2}}));1'
  $null = Go $ws ($b + 'index.html?x=1') 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  'migrated kinds: ' + (Eval $ws 'JSON.stringify(qrec.kinds)+" v="+qrec.v')
  'banner: ' + (Eval $ws '[...document.querySelectorAll(".pban")].map(a=>a.innerText.replace(/\s+/g," ")).join(" | ")')
  'stats: ' + (Eval $ws '(()=>{const t=performance.now();const Q=quizData();const k={};Q.songs.forEach(s=>s.bank.forEach(q=>k[q.kind]=(k[q.kind]||0)+1));return JSON.stringify({songs:Q.songs.length,...k,ms:Math.round(performance.now()-t)})})()')
  'bad items: ' + (Eval $ws '(()=>{const Q=quizData();const b=Q.songs.flatMap(s=>s.bank);return "dup choices "+b.filter(q=>new Set(q.c).size!==4).length+", dup keys "+(b.length-Object.keys(Q.keys).length)+", gram with lv "+b.filter(q=>q.kind==="gram"&&q.lv).length+", gram flag mismatch "+b.filter(q=>q.kind!=="read"&&(q.kind==="gram")!==(/^[～〜~]|=|→/.test(q.term))).length})()')
  'levels: ' + (Eval $ws '(()=>{const Q=quizData();return QLEVELS.map(n=>{const b=levelBank(n);return "n"+n+":"+b.filter(q=>q.kind==="word").length+"w/"+b.filter(q=>q.kind==="read").length+"r"}).join(" ")})()')
  'level check: ' + (Eval $ws '(()=>{const out=[];for(const n of QLEVELS){const b=levelBank(n);const ok={5:[5,"b","e5"],4:[4,"m","e4"],3:[3,"m","e3"],2:[2,"a","e2"],1:[1,"a","e1"]}[n];const bad=b.filter(q=>!ok.includes(q.lv)).length;const ks=b.map(q=>q.kind+RQ.lvKey(q.term));out.push(n+":bad"+bad+",dup"+(ks.length-new Set(ks).size)+",gram"+b.filter(q=>q.kind==="gram").length)}return out.join(" ")})()')
  'removed words: ' + (Eval $ws '(()=>{const Q=quizData();const gone=Object.keys(window.JLPT).filter(k=>window.JLPT[k]===0);const b=Q.songs.flatMap(s=>s.bank);const G=new Set(gone);const goneMeans=new Set();for(const s of Q.songs)for(const it of s.items)if(!it.gram&&G.has(RQ.lvKey(it.term)))goneMeans.add(it.mean);const keep=new Set();for(const s of Q.songs)for(const it of s.items)if(it.gram||!G.has(RQ.lvKey(it.term)))keep.add(it.mean);return gone.length+" words; asked "+b.filter(q=>q.kind!=="gram"&&G.has(RQ.lvKey(q.term))).length+"; no-level questions left "+b.filter(q=>q.kind!=="gram"&&!q.lv).length+"; used as choice "+b.filter(q=>q.kind!=="read"&&q.c.some(c=>goneMeans.has(c)&&!keep.has(c))).length+"; notes kept "+Q.songs.flatMap(s=>s.items).filter(it=>!it.gram&&G.has(RQ.lvKey(it.term))).length})()')
  'partition: ' + (Eval $ws '(()=>{const Q=quizData();const all=new Set(Q.songs.flatMap(s=>s.bank).filter(q=>q.kind!=="gram").map(q=>q.kind+RQ.lvKey(q.term)));const got=new Set(QLEVELS.flatMap(n=>levelBank(n).map(q=>q.kind+RQ.lvKey(q.term))));return all.size+" vs "+got.size})()')
  Hash $ws '#/quiz'
  'home: ' + (Eval $ws '[...document.querySelectorAll(".seg")].map(s=>[...s.querySelectorAll("button")].map(x=>x.textContent+(x.getAttribute("aria-pressed")==="true"?"*":"")).join(",")).join(" | ")') + ' wrongBtn=' + (Eval $ws '[...document.querySelectorAll(".quiz-go")].map(a=>a.textContent).join("/")')
  'cards: ' + (Eval $ws '[...document.querySelectorAll(".quiz-lv")].map(a=>a.innerText.replace(/\s+/g," ")+"="+a.getAttribute("href")).join(" | ")')
  'first song: ' + (Eval $ws 'document.querySelector(".quiz-song").innerText.replace(/\s+/g," ")')
  'groups: ' + (Eval $ws '[...document.querySelectorAll(".group h2")].map(h=>h.textContent).join(",")')
  Shot $ws "$Work\q2-home.png"
  foreach ($n in 5, 3, 1) {
    Hash $ws "#/quiz/n$n"
    "level n${n}: title=" + (Eval $ws 'document.title') + ' list=' + (Eval $ws 'qrun.list.length') + ' kinds=' + (Eval $ws '[...new Set(qrun.list.map(q=>q.kind))].join(",")') + ' lv=' + (Eval $ws 'JSON.stringify([...new Set(qrun.list.map(q=>q.lv))])') + ' card=' + (Eval $ws 'document.querySelector(".quiz-top").innerText.replace(/\s+/g," ")')
    if ($n -eq 5) { Shot $ws "$Work\q2-n5.png" }
  }
  Hash $ws '#/quiz/n5'
  $null = Eval $ws 'document.querySelector("[data-qa]").click();1'
  'feedback: ' + (Eval $ws 'document.getElementById("qfb").innerText.replace(/\s+/g," ")')
  Shot $ws "$Work\q2-fb.png"
  $null = Eval $ws 'document.querySelector("[data-qnext]").click();1'
  for ($i = 1; $i -lt 10; $i++) { $null = Eval $ws '(()=>{const o=[...document.querySelectorAll("[data-qa]")];o[Math.floor(Math.random()*o.length)].click();document.querySelector("[data-qnext]").click();return 1})()' }
  'done: ' + (Eval $ws 'document.querySelector(".qz-score").textContent+" | "+document.querySelector(".qz-sub").textContent+" | best="+JSON.stringify(qrec.best)')
  $null = Eval $ws '(document.querySelector("[data-qmiss]")||document.body).click();1'
  'miss rerun: list=' + (Eval $ws 'qrun.list.length+" bestId="+qrun.bestId')
  for ($i = 0; $i -lt 10; $i++) { $null = Eval $ws '(()=>{const o=document.querySelector("[data-qa]");if(!o)return 0;qrun.opts.forEach((x,k)=>{if(x.ok)document.querySelectorAll("[data-qa]")[k].click()});document.querySelector("[data-qnext]").click();return 1})()' }
  'miss done: ' + (Eval $ws '(document.querySelector(".qz-score")||{}).textContent+" | "+(document.querySelector(".qz-sub")||{}).textContent+" | best="+JSON.stringify(qrec.best)')
  # 문법만 고른 상태로 급수 퀴즈
  Hash $ws '#/quiz'
  $null = Eval $ws 'document.querySelector("[data-qk=word]").click();document.querySelector("[data-qk=read]").click();1'
  'gram only: ' + (Eval $ws 'JSON.stringify(qrec.kinds)')
  Hash $ws '#/quiz/n4'
  'n4 with gram only: ' + (Eval $ws 'qrun.list.length+" "+[...new Set(qrun.list.map(q=>q.kind))].join(",")')
  Hash $ws '#/quiz/full1/1'
  'song gram only: ' + (Eval $ws 'qrun.list.length+" "+[...new Set(qrun.list.map(q=>q.kind))].join(",")+" ask="+document.querySelector(".qz-ask").textContent+" chip="+!!document.querySelector(".qz-lv")')
  Shot $ws "$Work\q2-gram.png"
  Hash $ws '#/quiz'
  $null = Eval $ws 'document.querySelector("[data-qk=word]").click();document.querySelector("[data-qk=read]").click();1'
  Hash $ws '#/quiz/all'
  'all: ' + (Eval $ws 'qrun.list.length+" "+qrun.list.map(q=>q.kind[0]).join("")')
  Hash $ws '#/quiz/wrong'
  'wrong: ' + (Eval $ws 'document.body.innerText.includes("낼 문제가")+" run="+(qrun&&qrun.title)')
  Hash $ws '#/s/full4/7'
  'song link: ' + (Eval $ws '!!document.querySelector(".quiz-link")')
  Hash $ws '#/s/full4/3'
  'song without study link: ' + (Eval $ws '!!document.querySelector(".quiz-link")')
  # 급수표가 없을 때
  Hash $ws '#/quiz'
  'no jlpt: ' + (Eval $ws '(()=>{const j=window.JLPT;window.JLPT={};QUIZ=null;renderQuizHome();const r=document.querySelectorAll(".quiz-lv").length;window.JLPT=j;QUIZ=null;renderQuizHome();return r+" -> "+document.querySelectorAll(".quiz-lv").length})()')
  Set-Device $ws 390 844 $true '' 'dark'
  Hash $ws '#/quiz'
  'mobile overflow: ' + (Eval $ws 'document.documentElement.scrollWidth')
  Shot $ws "$Work\q2-home-m.png"
  Set-Device $ws 320 700 $true '' 'light'
  Start-Sleep -Milliseconds 400
  'mobile 320 overflow: ' + (Eval $ws 'document.documentElement.scrollWidth')
  Hash $ws '#/quiz/n0'
  'old n0 link: ' + (Eval $ws 'document.querySelector("h1")&&document.querySelector("h1").textContent+" cards="+document.querySelectorAll(".quiz-lv").length')
  'mobile n0: ' + (Eval $ws 'document.documentElement.scrollWidth')
  'errors: ' + (($script:Errors | Where-Object { $_ -and $_ -notlike '*favicon*' -and $_ -notlike '*manifest*' -and $_ -notlike '*ERR_*' } | ForEach-Object { $_.Substring(0, [Math]::Min(200, $_.Length)) } | Select-Object -Unique) -join ' || ')
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\pq2'
}
