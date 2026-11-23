# Small Chrome DevTools helper for local checks (dot-source this file).
Add-Type -AssemblyName System.Web.Extensions
$script:Json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$script:Json.MaxJsonLength = [int]::MaxValue
$script:Id = 0

function Start-TestChrome([int]$Port, [string]$Profile) {
  $chrome = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
  $args = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
    "--remote-debugging-port=$Port", "--user-data-dir=$Profile", '--window-size=1280,900', 'about:blank')
  $p = Start-Process -FilePath $chrome -ArgumentList $args -PassThru -WindowStyle Hidden
  for ($i = 0; $i -lt 60; $i++) {
    try { $null = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$Port/json/version" -TimeoutSec 2; return $p } catch { Start-Sleep -Milliseconds 500 }
  }
  throw 'chrome did not start'
}

function Connect-Page([int]$Port) {
  $list = $script:Json.DeserializeObject((Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$Port/json/list" -TimeoutSec 5).Content)
  $page = $list | Where-Object { $_['type'] -eq 'page' } | Select-Object -First 1
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $ws.ConnectAsync([Uri]$page['webSocketDebuggerUrl'], [Threading.CancellationToken]::None).Wait()
  return $ws
}

function Invoke-Cdp($Ws, [string]$Method, $Params = @{}, [int]$TimeoutSec = 30) {
  $script:Id++
  $id = $script:Id
  $msg = $script:Json.Serialize(@{ id = $id; method = $Method; params = $Params })
  $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
  $Ws.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()
  $buf = New-Object byte[] 1048576
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    $ms = New-Object IO.MemoryStream
    do {
      $task = $Ws.ReceiveAsync([ArraySegment[byte]]::new($buf), [Threading.CancellationToken]::None)
      if (-not $task.Wait([int][Math]::Max(1000, ($deadline - (Get-Date)).TotalMilliseconds))) { throw "timeout: $Method" }
      $ms.Write($buf, 0, $task.Result.Count)
    } while (-not $task.Result.EndOfMessage)
    $o = $script:Json.DeserializeObject([Text.Encoding]::UTF8.GetString($ms.ToArray()))
    if ($o['id'] -eq $id) {
      if ($o.ContainsKey('error')) { throw "$Method : $($o['error']['message'])" }
      return $o['result']
    }
    if ($o['method'] -eq 'Runtime.exceptionThrown') { $x = $o['params']['exceptionDetails']; $script:Errors += ,("EXC text=[" + $x['text'] + "] desc=[" + $(if($x['exception']){ $x['exception']['description'] + " value=" + $x['exception']['value'] + " class=" + $x['exception']['className'] }) + "] at " + $x['url'] + ":" + $x['lineNumber']) }
    if ($o['method'] -eq 'Log.entryAdded' -and $o['params']['entry']['level'] -eq 'error') { $script:Errors += ,($o['params']['entry']['text'] + ' ' + $o['params']['entry']['url']) }
  }
  throw "timeout: $Method"
}

function Eval($Ws, [string]$Js) {
  $r = Invoke-Cdp $Ws 'Runtime.evaluate' @{ expression = $Js; awaitPromise = $true; returnByValue = $true }
  if ($r.ContainsKey('exceptionDetails')) { throw "eval failed: $($r['exceptionDetails']['exception']['description'])" }
  return $r['result']['value']
}

function Go($Ws, [string]$Url, [string]$ReadyJs = 'document.readyState==="complete"', [int]$WaitSec = 25) {
  $null = Invoke-Cdp $Ws 'Page.navigate' @{ url = $Url }
  $end = (Get-Date).AddSeconds($WaitSec)
  while ((Get-Date) -lt $end) {
    Start-Sleep -Milliseconds 300
    try { if (Eval $Ws $ReadyJs) { return $true } } catch {}
  }
  return $false
}

function Shot($Ws, [string]$Path) {
  $r = Invoke-Cdp $Ws 'Page.captureScreenshot' @{ format = 'png' }
  [IO.File]::WriteAllBytes($Path, [Convert]::FromBase64String($r['data']))
}

function Set-Device($Ws, [int]$W, [int]$H, [bool]$Mobile, [string]$UA, [string]$Scheme = 'light') {
  $null = Invoke-Cdp $Ws 'Emulation.setDeviceMetricsOverride' @{ width = $W; height = $H; deviceScaleFactor = 1; mobile = $Mobile }
  if ($UA) { $null = Invoke-Cdp $Ws 'Emulation.setUserAgentOverride' @{ userAgent = $UA } }
  $null = Invoke-Cdp $Ws 'Emulation.setEmulatedMedia' @{ features = @(@{ name = 'prefers-color-scheme'; value = $Scheme }) }
}

function Stop-TestChrome([string]$Marker) {
  Get-CimInstance Win32_Process -Filter "name='chrome.exe'" | Where-Object { $_.CommandLine -like "*$Marker*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
