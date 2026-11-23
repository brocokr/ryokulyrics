param([string]$Work, [string]$Site = 'site16', [string]$Route = '#/s/full5/2', [string]$Out = 'render-seishun.txt', [int]$P = 8821, [int]$DebugPort = 9354)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = "$Work\$Site"
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$prof = (Split-Path $Work) + '\pm3'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'
  $null = Invoke-Cdp $ws 'Runtime.enable'
  $null = Invoke-Cdp $ws 'Log.enable'
  $null = Invoke-Cdp $ws 'Emulation.setDeviceMetricsOverride' @{ width = 1100; height = 900; deviceScaleFactor = 1; mobile = $false }
  $b = "http://localhost:$P/"
  $null = Go $ws ($b + 'index.html') 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  $null = Eval $ws "location.hash='$Route';1"; Start-Sleep -Milliseconds 900
  'song: rows=' + (Eval $ws 'document.querySelectorAll(".row").length') + ' warn=' + (Eval $ws 'JSON.stringify([...document.querySelectorAll(".warn")].map(w=>w.textContent))') + ' study blocks=' + (Eval $ws 'document.querySelectorAll(".study").length') + ' rows with notes=' + (Eval $ws '[...document.querySelectorAll(".row")].filter(r=>r.querySelector(".study .item, .study details")).length')
  'empty subs: ' + (Eval $ws '(()=>{document.querySelectorAll(".row").forEach(r=>{try{setStudyOpen(r,true)}catch(e){}});document.querySelectorAll("details").forEach(d=>d.open=true);return [...document.querySelectorAll(".d-sub")].filter(s=>{let n=s.nextElementSibling;return !n||n.classList.contains("d-sub")}).map(s=>s.textContent).join(" | ")})()')
  'rows without notes: ' + (Eval $ws '[...document.querySelectorAll(".row")].map((r,i)=>[i+1,r.querySelector(".study")&&r.querySelector(".study").innerText.trim().length]).filter(x=>!x[1]).map(x=>x[0]).join(",")')
  $txt = Eval $ws '(()=>{const rows=[...document.querySelectorAll(".row")];return rows.map((r,i)=>{const s=r.querySelector(".study");return "##### "+(i+1)+" "+r.querySelector(".jp").textContent.replace(/\s+/g,"").slice(0,24)+"\n"+(s?s.innerText:"")}).join("\n")})()'
  [IO.File]::WriteAllText("$Work\$Out", $txt, (New-Object Text.UTF8Encoding($true)))
  'rendered chars: ' + $txt.Length
  'errors: ' + (($script:Errors | Where-Object { $_ -and $_ -notlike '*favicon*' -and $_ -notlike '*manifest*' -and $_ -notlike '*ERR_*' } | ForEach-Object { $_.Substring(0, [Math]::Min(170, $_.Length)) } | Select-Object -Unique) -join ' || ')
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\pm3'
}
