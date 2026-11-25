# Study mode (#/study): decks, cards, list, saving, keyboard, layout.
param([string]$Root = (Split-Path (Split-Path $PSScriptRoot)), [string]$Out = "$env:TEMP\ryoku-banner", [int]$P = 8921, [int]$D = 9451)
$ErrorActionPreference = 'Stop'
$work = $PSScriptRoot
. "$work\cdp.ps1"
$null = New-Item -ItemType Directory -Force $Out
$tool = (Split-Path $PSScriptRoot) + '\test-server.ps1'
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
if (Test-Path "$Out\pfst") { Remove-Item -Recurse -Force "$Out\pfst" -ErrorAction SilentlyContinue }
$null = Start-TestChrome $D "$Out\pfst"
function Hash($ws, $h) { $null = Eval $ws "location.hash='$h';1"; Start-Sleep -Milliseconds 500 }
function Key($ws, $k) { $null = Eval $ws "document.activeElement&&document.activeElement.blur();document.body.dispatchEvent(new KeyboardEvent('keydown',{key:'$k',bubbles:true,cancelable:true}));1"; Start-Sleep -Milliseconds 120 }
try {
  $ws = Connect-Page $D
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'; $null = Invoke-Cdp $ws 'Log.enable'
  $b = "http://localhost:$P"
  Set-Device $ws 1144 900 $false '' 'light'
  $null = Go $ws "$b/index.html#/study" 'document.querySelector(".quiz-songs")!==null&&document.readyState==="complete"'
  $null = Eval $ws 'document.fonts.ready.then(()=>1)'
  Start-Sleep -Milliseconds 800
  'data: ' + (Eval $ws '(()=>{const t=performance.now();STUDY=null;const S=studyData();return JSON.stringify({ms:Math.round(performance.now()-t),songs:S.songs.length,uniq:S.uniq.length,word:S.uniq.filter(x=>x.kind==="word").length,gram:S.uniq.filter(x=>x.kind==="gram").length,levels:S.levels.map(l=>l.n+":"+l.items.length).join(" ")})})()')
  'quiz songs: ' + (Eval $ws 'quizData().songs.length+" level words "+QLEVELS.map(n=>n+":"+levelBank(n).filter(q=>q.kind==="word").length).join(" ")')
  'home: ' + (Eval $ws 'document.querySelector("h1").textContent+" | "+[...document.querySelectorAll(".qz-btns a")].map(a=>a.textContent+"="+a.getAttribute("href")).join(" | ")+" | nav "+[...document.querySelectorAll(".site-nav a")].map(a=>a.textContent+(a.getAttribute("aria-current")?"*":"")).join(",")')
  Shot $ws "$Out\st-home.png"
  # every detail renders
  'all details: ' + (Eval $ws '(()=>{let bad=0,empty=0,n=0;srun={deck:{song:null}};for(const x of studyData().uniq){n++;try{const h=stDetail(x)+stLine(x,true);if(!x.jp)empty++;if(/undefined|\[object/.test(h))bad++}catch(e){bad++}}srun=null;return n+" items, bad "+bad+", without line "+empty})()')
  # song deck
  Hash $ws '#/study/full6/8'
  'song: ' + (Eval $ws 'document.title+" | "+document.querySelector("#stMeter").innerText+" | "+document.querySelector(".quiz-prog").innerText.replace(/\s+/g," ")+" | term "+document.querySelector(".qz-term").innerText.replace(/\s+/g,"")+" | back "+!!document.querySelector(".st-mean")')
  Shot $ws "$Out\st-card-front.png"
  Key $ws ' '
  'opened: ' + (Eval $ws '"mean="+document.querySelector(".st-mean").innerText+" btns="+[...document.querySelectorAll(".st-btns button")].map(x=>x.textContent).join("/")+" line="+document.querySelector(".st-line").innerText.replace(/\s+/g," ").slice(0,60)')
  Shot $ws "$Out\st-card-back.png"
  Key $ws '2'
  'after 2: ' + (Eval $ws 'document.querySelector(".quiz-prog").innerText.replace(/\s+/g," ")+" known="+Object.keys(srec.known).length+" meter="+document.querySelector("#stMeter").innerText')
  Key $ws 'Enter'; Key $ws '1'
  'after 1: ' + (Eval $ws 'document.querySelector(".quiz-prog").innerText.replace(/\s+/g," ")+" known="+Object.keys(srec.known).length+" again="+Object.keys(srec.again).length')
  Key $ws 'ArrowLeft'
  'left: ' + (Eval $ws 'document.querySelector(".quiz-prog").innerText.replace(/\s+/g," ")')
  Key $ws 'ArrowRight'
  # finish the deck with clicks
  $null = Eval $ws '(()=>{for(let g=0;g<40&&document.querySelector("[data-st-open]");g++){document.querySelector("button[data-st-open]").click();document.querySelector("[data-st-yes]").click()}})();1'
  Start-Sleep -Milliseconds 300
  'done: ' + (Eval $ws 'document.querySelector(".quiz-card").innerText.replace(/\s+/g," ")+" | "+[...document.querySelectorAll(".qz-btns a")].map(a=>a.getAttribute("href")).join(" ")')
  Shot $ws "$Out\st-done.png"
  $null = Eval $ws 'document.querySelector("[data-st-more]").click();1'; Start-Sleep -Milliseconds 300
  'more: ' + (Eval $ws 'document.querySelector(".quiz-prog").innerText.replace(/\s+/g," ")+" first="+document.querySelector(".qz-term").innerText.replace(/\s+/g,"")+" all unknown="+srun.list.every(x=>!isKnown(x))')
  # list view
  $null = Eval $ws 'document.querySelector("[data-st-view=list]").click();1'; Start-Sleep -Milliseconds 300
  'list: ' + (Eval $ws 'document.querySelectorAll(".st-list li").length+" rows, known "+document.querySelectorAll(".st-list li.known").length+", checks "+document.querySelectorAll("[data-st-opt]").length')
  $null = Eval $ws 'document.querySelectorAll(".st-list details")[2].open=true;1'; Start-Sleep -Milliseconds 300
  'list open: ' + (Eval $ws 'document.querySelectorAll(".st-list details")[2].querySelector(".st-body").innerText.replace(/\s+/g," ").slice(0,120)')
  $null = Eval $ws '(()=>{const c=document.querySelectorAll("[data-st-chk]");c[20].click();document.querySelector("[data-st-opt=hide]").click()})();1'; Start-Sleep -Milliseconds 300
  'list mark: ' + (Eval $ws '"known "+document.querySelectorAll(".st-list li.known").length+" hide="+document.querySelector(".st-list").className+" meter="+document.querySelector("#stMeter").innerText')
  Shot $ws "$Out\st-list.png"
  $null = Eval $ws 'document.querySelector("[data-st-opt=left]").click();1'; Start-Sleep -Milliseconds 200
  'only left: ' + (Eval $ws '[...document.querySelectorAll(".st-list li")].filter(l=>l.getClientRects().length).length+" visible"')
  $null = Eval $ws 'document.querySelector("[data-st-opt=left]").click();document.querySelector("[data-st-opt=hide]").click();document.querySelector("[data-st-kind=gram]").click();1'; Start-Sleep -Milliseconds 200
  'grammar: ' + (Eval $ws 'document.querySelectorAll(".st-list li").length+" tags "+document.querySelectorAll(".st-list .tag").length')
  $null = Eval $ws 'document.querySelector("[data-st-kind=all]").click();document.querySelector("[data-st-view=card]").click();1'
  # reload keeps
  $null = Go $ws 'about:blank'
  $null = Go $ws "$b/index.html#/study" 'document.querySelector(".quiz-songs")!==null'
  'reload: ' + (Eval $ws '[...document.querySelectorAll(".qz-btns a")].map(a=>a.textContent).join(" | ")+" | known "+Object.keys(srec.known).length')
  # same word in another song counts
  'shared: ' + (Eval $ws '(()=>{const S=studyData();const n=S.songs.map(x=>x.items.filter(isKnown).length);return "songs with known words "+n.filter(Boolean).length+" of "+n.length})()')
  foreach ($h in @('#/study/n5', '#/study/n1', '#/study/all', '#/study/again', '#/study/wrong', '#/study/zzz', '#/study/single7/1', '#/study/single5/1')) {
    Hash $ws $h
    "$h : " + (Eval $ws 'document.title+" | "+(document.querySelector(".quiz-prog")?document.querySelector(".quiz-prog").innerText.replace(/\s+/g," "):"no card")+" | "+(document.querySelector("#stMeter")?document.querySelector("#stMeter").innerText:"")+" | warn "+(document.querySelector(".warn")?document.querySelector(".warn").innerText:"-")+" | rom "+!!document.querySelector("[data-qrom]")+" | view "+!!document.querySelector("[data-st-view]")')
  }
  Hash $ws '#/study/n5'
  $null = Eval $ws 'document.querySelector("[data-qrom]").click();1'; Start-Sleep -Milliseconds 200
  'rom: ' + (Eval $ws '(()=>{const e=document.querySelector(".qz-rom");return e.textContent+" shown="+(getComputedStyle(e).display!=="none")+" btn="+document.querySelector("[data-qrom]").textContent})()')
  $null = Eval $ws 'document.querySelector("[data-qrom]").click();document.querySelector("[data-st-opt=furi]").click();1'; Start-Sleep -Milliseconds 200
  'furi off ruby on face: ' + (Eval $ws 'document.querySelectorAll(".st-face ruby").length+" / opened "+(document.querySelector("button[data-st-open]").click(),document.querySelectorAll(".st-face ruby").length)')
  $null = Eval $ws 'document.querySelector("[data-st-opt=furi]").click();1'
  # wrong list from quiz
  $null = Eval $ws '(()=>{const ks=Object.keys(quizData().keys).slice(0,6);ks.forEach(k=>qrec.wrong[k]=1);saveQuiz()})();1'
  Hash $ws '#/study'
  Hash $ws '#/study/wrong'
  'wrong deck: ' + (Eval $ws 'document.querySelector(".quiz-prog").innerText.replace(/\s+/g," ")+" items "+srun.items.length')
  # quiz result links to study, song page links
  Hash $ws '#/quiz/full6/8'
  $null = Eval $ws '(()=>{for(let g=0;g<30&&document.querySelector("[data-qa]");g++){document.querySelector("[data-qa]").click();document.querySelector("[data-qnext]").click()}})();1'; Start-Sleep -Milliseconds 300
  'quiz done: ' + (Eval $ws '[...document.querySelectorAll(".qz-btns a")].map(a=>a.textContent+"="+a.getAttribute("href")).join(" | ")')
  Hash $ws '#/quiz/n4'
  $null = Eval $ws '(()=>{for(let g=0;g<30&&document.querySelector("[data-qa]");g++){document.querySelector("[data-qa]").click();document.querySelector("[data-qnext]").click()}})();1'; Start-Sleep -Milliseconds 300
  'quiz n4 done: ' + (Eval $ws '[...document.querySelectorAll(".qz-btns a")].map(a=>a.textContent+"="+a.getAttribute("href")).join(" | ")')
  Hash $ws '#/s/full6/8'
  'song links: ' + (Eval $ws '[...document.querySelectorAll(".song-links a")].map(a=>a.textContent+"="+a.getAttribute("href")).join(" | ")')
  Hash $ws '#/'
  'home banner: ' + (Eval $ws '[...document.querySelectorAll(".pban")][1].innerText.replace(/\s+/g," ")+" | "+[...document.querySelectorAll(".pban")][1].querySelector(".pic-quiz").getAttribute("href")+" | nav "+[...document.querySelectorAll(".site-nav:not(.lang-switch) a")].map(a=>a.textContent).join(",")')
  # widths
  foreach ($wv in 1144, 768, 390, 360, 320) {
    Set-Device $ws $wv 1300 ($wv -lt 761) '' 'dark'
    foreach ($h in @('#/study', '#/study/full6/8', '#/study/n5')) {
      $null = Go $ws 'about:blank'
      $null = Go $ws "$b/index.html$h" 'document.querySelector(".quiz-songs,.st-card")!==null'
      Start-Sleep -Milliseconds 400
      $null = Eval $ws '(()=>{const b=document.querySelector("button[data-st-open]");if(b)b.click()})();1'
      Start-Sleep -Milliseconds 200
      "$wv $h sw=" + (Eval $ws 'document.documentElement.scrollWidth+" nav="+Math.round(document.querySelector(".site-nav").getBoundingClientRect().width)+" navH="+Math.round(document.querySelector(".site-nav").getBoundingClientRect().height)')
      Shot $ws ("$Out\st-$wv-" + ($h -replace '[#/]', '') + '.png')
    }
    $null = Go $ws "$b/call/index.html?lang=ja" 'document.querySelector(".song")!==null'
    "$wv call ja sw=" + (Eval $ws 'document.documentElement.scrollWidth+" nav="+[...document.querySelectorAll(".site-nav:not(.lang-switch) a")].map(a=>a.textContent+"="+a.getAttribute("href")).join(",")')
    $null = Go $ws "$b/call/index.html?lang=ko" 'document.querySelector(".song")!==null'
  }
  'errors: ' + (($script:Errors | Where-Object { $_ -notlike '*favicon*' -and $_ -notlike '*youtube*' } | Select-Object -Unique) -join ' || ')
} finally {
  Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue
  Stop-TestChrome 'pfst'
}
