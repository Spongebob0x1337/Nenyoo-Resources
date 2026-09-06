$ErrorActionPreference = 'Stop'

$package = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $env:LOCALAPPDATA 'Nenyoo\Plus\Themes\Team Psycos'
$fontTarget = Join-Path $target 'fonts'

New-Item -ItemType Directory -Force -Path $fontTarget | Out-Null
Copy-Item -LiteralPath (Join-Path $package 'theme.lua') -Destination (Join-Path $target 'theme.lua') -Force

Write-Host 'Installed Team Psycos/theme.' -ForegroundColor Cyan
Write-Host 'Open Nenyoo Theme Settings and load Team Psycos/theme.'
