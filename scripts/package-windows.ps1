param(
  [Parameter(Mandatory = $true)][string]$AppVersion,
  [Parameter(Mandatory = $true)][string]$AppBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $root 'build/windows/x64/runner/Release'
$wxs = Join-Path $root 'windows/installer.wxs'
$obj = Join-Path $root 'build/windows/installer'
$release = Join-Path $root 'release'

if (-not (Test-Path (Join-Path $bundle 'fuckxter_app.exe'))) {
  throw "Windows release bundle not found: $bundle"
}

$heat = Get-Command heat.exe -ErrorAction SilentlyContinue
$candle = Get-Command candle.exe -ErrorAction SilentlyContinue
$light = Get-Command light.exe -ErrorAction SilentlyContinue
if (-not ($heat -and $candle -and $light)) {
  $wixBin = Get-ChildItem "${env:ProgramFiles(x86)}\WiX Toolset v*\bin" `
    -Filter heat.exe -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $wixBin) { throw 'WiX Toolset v3 executables were not found.' }
  $wixPath = $wixBin.Directory.FullName
  $heat = Join-Path $wixPath 'heat.exe'
  $candle = Join-Path $wixPath 'candle.exe'
  $light = Join-Path $wixPath 'light.exe'
}

New-Item -ItemType Directory -Force $obj, $release | Out-Null
$harvested = Join-Path $obj 'bundle.wxs'
& $heat dir $bundle -cg AppFiles -dr INSTALLFOLDER -srd -sreg -sfrag -ag `
  -var var.SourceDir -out $harvested
if ($LASTEXITCODE -ne 0) { throw 'WiX heat failed.' }

& $candle -nologo "-dAppVersion=$AppVersion" "-dAppBuild=$AppBuild" `
  "-dSourceDir=$bundle" -out "$obj\" $wxs $harvested
if ($LASTEXITCODE -ne 0) { throw 'WiX candle failed.' }

$output = Join-Path $release "fuckxter-$AppVersion-$AppBuild-windows-x64.msi"
& $light -nologo -ext WixUIExtension -out $output `
  (Join-Path $obj 'installer.wixobj') (Join-Path $obj 'bundle.wixobj')
if ($LASTEXITCODE -ne 0) { throw 'WiX light failed.' }

if (-not (Test-Path $output)) { throw "MSI was not created: $output" }
Write-Host "Created $output"