$ErrorActionPreference = 'Stop'

$package = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $env:LOCALAPPDATA 'Nenyoo\Plus\Themes\Player Options Classic'

New-Item -ItemType Directory -Force -Path (Join-Path $target 'fonts') | Out-Null
Copy-Item -LiteralPath (Join-Path $package 'theme.lua') -Destination (Join-Path $target 'theme.lua') -Force
Copy-Item -LiteralPath (Join-Path $package 'fonts\KaushanScript-Regular.ttf') -Destination (Join-Path $target 'fonts\KaushanScript-Regular.ttf') -Force

Write-Host 'Installed Player Options Classic/theme.' -ForegroundColor Cyan
