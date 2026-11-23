param([string]$Root = 'D:\code\녹황색사회 가사', [string]$Album = 'full4', [int]$No = 7, [string]$Title = '', [int]$P = 8861, [int]$DebugPort = 9391)
# Opens the real site and checks one song: warnings on the song page, its quiz data, the quiz screen, and the call guide.
$ErrorActionPreference = 'Stop'
. "$Root\도구\jlpt\cdp.ps1"
$prof = "$env:TEMP\rknew"
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\도구\test-server.ps1`"", '-Port', "$P", '-Root', "`"$Root`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'; $null = Invoke-Cdp $ws 'Runtime.enable'
  $b = "http://localhost:$P/"
  $null = Go $ws ($b + 'index.html') 'document.querySelector(".group")!==null&&document.readyState==="complete"' 40
  $null = Eval $ws "location.hash='#/s/$Album/$No';1"; Start-Sleep -Milliseconds 1200
  'song: rows=' + (Eval $ws 'document.querySelectorAll(".row").length') + ' warn=' + (Eval $ws 'JSON.stringify([...document.querySelectorAll(".warn")].map(w=>w.textContent))') + ' rows with notes=' + (Eval $ws '[...document.querySelectorAll(".row")].filter(r=>r.querySelector(".study .item, .study details")).length') + ' tr rows=' + (Eval $ws '[...document.querySelectorAll(".row")].filter(r=>r.querySelector(".ko, .tr, .trans")).length')
  'quiz data: ' + (Eval $ws "(()=>{const d=quizData();const s=d.songs.find(s=>Object.values(s).some(v=>typeof v==='string'&&v.includes('$Title'))||(s.track&&typeof s.track==='object'&&Object.values(s.track).some(v=>typeof v==='string'&&v.includes('$Title'))));if(!s)return 'song not found ('+d.songs.length+' songs)';const it=s.items||[];return d.songs.length+' songs; this song items='+it.length+' words='+it.filter(x=>!x.gram&&x.term&&x.mean).length+' grammar='+it.filter(x=>x.gram).length+' keys='+Object.keys(s).join(',')})()")
  $null = Eval $ws "location.hash='#/quiz/$Album/$No';1"; Start-Sleep -Milliseconds 1200
  'quiz screen: ' + (Eval $ws '(document.querySelector("main")||document.body).innerText.replace(/\s+/g," ").slice(0,260)')
  $null = Eval $ws "location.hash='#/quiz';1"; Start-Sleep -Milliseconds 900
  'quiz home lists song: ' + (Eval $ws "document.body.innerText.includes('$Title')")
  $null = Go $ws ($b + 'call/index.html') 'document.readyState==="complete"' 30
  Start-Sleep -Milliseconds 1500
  'call guide missing-line msgs: ' + (Eval $ws "(document.body.innerText.match(/번째 줄을 찾지 못했어요/g)||[]).length")
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'rknew'
}
