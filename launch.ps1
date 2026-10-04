# EXFac — double-click or: powershell -ExecutionPolicy Bypass -File .\launch.ps1
# Always launches this Godot project on Windows.

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$candidates = @(
    (Join-Path $PSScriptRoot "godot.exe"),
    (Join-Path $PSScriptRoot "Godot_v4.3-stable_win64.exe"),
    (Join-Path $PSScriptRoot "Godot_v4.4-stable_win64.exe"),
    (Join-Path $env:LOCALAPPDATA "Godot\godot.exe"),
    (Join-Path ${env:ProgramFiles} "Godot\Godot_v4.3-stable_win64.exe"),
    (Join-Path ${env:ProgramFiles} "Godot\godot.exe"),
    (Join-Path $env:USERPROFILE "Downloads\Godot_v4.3-stable_win64.exe"),
    (Join-Path $env:USERPROFILE "Downloads\Godot_v4.4-stable_win64.exe"),
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\Godot Engine\godot.exe"
)

$godot = $null
foreach ($path in $candidates) {
    if ($path -and (Test-Path -LiteralPath $path)) {
        $godot = $path
        break
    }
}

if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source }
}

if (-not $godot) {
    Write-Host @"
Godot 4 not found.

Fix options:
  1) Put Godot_v4.3-stable_win64.exe in:
     $PSScriptRoot
  2) Or add godot.exe to PATH
  3) Or open project.godot in the Godot Project Manager

Download: https://godotengine.org/download/archive/4.3-stable/
"@
    exit 1
}

Write-Host "Launching: $godot"
Write-Host "Project:   $PSScriptRoot"
& $godot --path $PSScriptRoot
exit $LASTEXITCODE
