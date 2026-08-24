$ErrorActionPreference = 'Stop'

$package = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $env:LOCALAPPDATA 'Nenyoo\Plus\Themes\Nova'

New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -LiteralPath (Join-Path $package 'theme.lua') -Destination (Join-Path $target 'theme.lua') -Force

Write-Host 'Installed Nova/theme.' -ForegroundColor Magenta
Write-Host 'Open Nenyoo Settings > Load Theme and pick Nova/theme.'
