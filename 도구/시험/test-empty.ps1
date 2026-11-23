param([string]$Work, [string]$Site = 'site16', [int]$P = 8823, [int]$DebugPort = 9356)
. "$Work\cdp.ps1"
$ErrorActionPreference = 'Stop'
$site = "$Work\$Site"
$tool = (Get-ChildItem $site -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'test-server.ps1') } | Select-Object -First 1).FullName + '\test-server.ps1'
$prof = (Split-Path $Work) + '\pm4'
if (Test-Path $prof) { Remove-Item -Recurse -Force $prof }
$s1 = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-Port', "$P", '-Root', "`"$site`"", '-NoBrowser') -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$null = Start-TestChrome $DebugPort $prof
$routes = @('full1/1', 'mini2/2', 'single11/2', 'full2/3', 'full3/4', 'full3/14', 'full5/2', 'full5/7', 'full6/1', 'full6/2', 'full6/3', 'full6/8', 'full6/10', 'full6/12')
try {
  $ws = Connect-Page $DebugPort
  $null = Invoke-Cdp $ws 'Page.enable'
  $null = Invoke-Cdp $ws 'Runtime.enable'
  $null = Invoke-Cdp $ws 'Emulation.setDeviceMetricsOverride' @{ width = 1100; height = 900; deviceScaleFactor = 1; mobile = $false }
  $b = "http://localhost:$P/"
  $null = Go $ws ($b + 'index.html') 'document.querySelector(".group")!==null&&document.readyState==="complete"'
  foreach ($r in $routes) {
    $null = Eval $ws "location.hash='#/s/$r';1"; Start-Sleep -Milliseconds 900
    $res = Eval $ws '(()=>{document.querySelectorAll(".row").forEach(r=>{try{setStudyOpen(r,true)}catch(e){}});document.querySelectorAll("details").forEach(d=>d.open=true);const rows=[...document.querySelectorAll(".row")];const out=[];rows.forEach((row,i)=>{row.querySelectorAll(".d-sub").forEach(s=>{let n=s.nextElementSibling;if(!n||n.classList.contains("d-sub"))out.push((i+1)+":"+s.textContent)})});return document.querySelector("h1,h2")?.textContent.slice(0,20)+" rows="+rows.length+" warn="+document.querySelectorAll(".warn").length+" empty=["+out.join(" | ")+"]"})()'
    "$r  $res"
  }
} finally {
  if ($s1) { Stop-Process -Id $s1.Id -Force -ErrorAction SilentlyContinue }
  Stop-TestChrome 'scratchpad\pm4'
}
