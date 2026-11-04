param([string]$SiteDir, [string]$Album, [string]$Key, [int]$No, [string]$OutDir)
$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding $false
$page = [IO.File]::ReadAllText((Join-Path $SiteDir 'index.html'), $enc)
$src = [IO.File]::ReadAllText((Join-Path $SiteDir "가사\$Album.js"), $enc)

# 그 곡의 칸만 잘라낸다: "### 번호" 줄부터 다음 "###" 줄 전까지
$lines = $src -split "`r?`n"
$start = -1; $end = $lines.Count
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*###\s*(\d+)') {
    if ($start -ge 0) { $end = $i; break }
    if ([int]$Matches[1] -eq $No) { $start = $i }
  }
}
if ($start -lt 0) { throw "### $No 를 찾지 못함" }
$section = @($lines[$start..($end - 1)] | Where-Object { -not $_.StartsWith('`);') })
$title = (($lines[$start] -replace '^\s*###\s*\d+\s*', '') -replace '\s*·.*$', '').Trim()
$json = ConvertTo-Json -InputObject ($section -join "`n") -Compress

# 앨범 커버를 파일 안에 넣는다
$coverPath = Join-Path $SiteDir "$Album.webp"
$coverJs = if (Test-Path -LiteralPath $coverPath) { "window.EMBED_COVERS = { $Key`: `"data:image/webp;base64,$([Convert]::ToBase64String([IO.File]::ReadAllBytes($coverPath)))`" };" } else { '' }

$inject = "<script>window.SINGLE = { key: `"$Key`", no: $No }; window.EMBED_LYRICS = { `"$Album`": $json }; $coverJs</script>`r`n</head>"
if (([regex]::Matches($page, '</head>')).Count -ne 1) { throw "index.html의 </head>가 하나가 아님" }
$out = $page.Replace('</head>', $inject)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$safe = $title -replace '[\\/:*?"<>|]', '_'
$path = Join-Path $OutDir ("{0}-{1:D2} {2}.html" -f $Album, $No, $safe)
[IO.File]::WriteAllText($path, $out, $enc)
"wrote: $path ($([math]::Round((Get-Item -LiteralPath $path).Length / 1KB)) KB, 곡 칸 $($section.Count)줄)"
