param([int]$Port = 8765, [string]$Root = $PSScriptRoot, [switch]$NoBrowser)
# 가사 노트를 이 컴퓨터 안에서만 여는 작은 서버입니다. 다른 컴퓨터에서는 접속할 수 없습니다.
# 파일로 직접 열면 유튜브 영상이 재생되지 않아서(오류 153) 이 방식으로 엽니다.
$url = "http://localhost:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
try { $listener.Start() } catch {
  # 이미 켜져 있으면 브라우저만 엽니다
  if (-not $NoBrowser) { Start-Process $url }
  exit
}
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.webp' = 'image/webp'; '.jpg' = 'image/jpeg'; '.png' = 'image/png'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.webmanifest' = 'application/manifest+json'
}
$full = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if (-not $NoBrowser) { Start-Process $url }
Write-Host ''
Write-Host "  녹황색사회 가사 노트가 열렸습니다: $url"
Write-Host '  사이트를 보는 동안에는 이 창을 닫지 마세요. 다 봤으면 이 창을 닫으면 됩니다.'
Write-Host ''
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if (-not $rel) { $rel = 'index.html' }
    $path = [IO.Path]::GetFullPath([IO.Path]::Combine($full, $rel))
    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($path.StartsWith($full + '\') -and $types.ContainsKey($ext) -and [IO.File]::Exists($path)) {
      $bytes = [IO.File]::ReadAllBytes($path)
      $ctx.Response.ContentType = $types[$ext]
      $ctx.Response.Headers['Cache-Control'] = 'no-store'
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else { $ctx.Response.StatusCode = 404 }
  } catch { $ctx.Response.StatusCode = 500 } finally { $ctx.Response.Close() }
}
