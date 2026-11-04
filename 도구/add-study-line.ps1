param([string]$File, [string]$Song, [string]$Block, [string]$Backup)
$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding $false
New-Item -ItemType Directory -Force -Path $Backup | Out-Null
Copy-Item -LiteralPath $File -Destination $Backup

$text = [IO.File]::ReadAllText($File, $enc)
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
# 그 곡의 [공부] 칸 내용 범위: [공부] 다음 줄부터 [메모] 앞까지
$rx = [regex]("(?s)(^|\n)###\s*$Song\b.*?\n\[공부\]\r?\n(.*?)(\r?\n\[메모\])")
$m = $rx.Match($text)
if (-not $m.Success) { throw "### $Song 의 [공부] 칸을 찾지 못함" }
$body = $m.Groups[2]
$block = ([IO.File]::ReadAllText($Block, $enc) -replace '\r?\n', $nl).TrimEnd()
$first = ($block -split $nl)[0].Trim()
if ([regex]::IsMatch($body.Value, "(?m)^$([regex]::Escape($first))\s*$")) { throw "[공부]에 이미 '$first' 묶음이 있음" }
$newBody = $body.Value.TrimEnd() + $nl + $nl + $block + $nl
$text = $text.Substring(0, $body.Index) + $newBody + $text.Substring($body.Index + $body.Length)
[IO.File]::WriteAllText($File, $text, $enc)
"추가함: ### $Song [공부]에 '$first' 묶음 ($(($block -split $nl).Count)줄)"
