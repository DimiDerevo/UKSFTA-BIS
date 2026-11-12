<#
.SYNOPSIS
    Installs the "bis" command for the current Windows user.

.DESCRIPTION
    The script finds bis.exe in one of two ways:
      1. A bis.exe next to this script (release archive): the script uses that file.
      2. A source checkout: the script builds a self-contained bis.exe.
         This needs the .NET 10 SDK. The installed bis.exe does not need .NET.

    The script copies bis.exe to the install folder and adds that folder to the
    user PATH. Administrator rights are not necessary.

    Run the script again to update bis. Run it with -Uninstall to remove bis.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    # Folder for bis.exe. The default is %LOCALAPPDATA%\Programs\bis.
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\bis'),

    # Do not change the user PATH.
    [switch]$NoPath,

    # Remove bis.exe and remove the install folder from the user PATH.
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$target = Join-Path $InstallDir 'bis.exe'

function Get-UserPath {
    $value = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $value) { return @() }
    return @($value -split ';' | Where-Object { $_ -ne '' })
}

function Set-UserPath([string[]]$entries) {
    [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
}

function Test-SamePath([string]$a, [string]$b) {
    return $a.TrimEnd('\').Equals($b.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
}

if ($Uninstall) {
    if (Test-Path $target) { Remove-Item -Force $target }
    if ((Test-Path $InstallDir) -and -not (Get-ChildItem $InstallDir)) { Remove-Item $InstallDir }
    if (-not $NoPath) {
        Set-UserPath (Get-UserPath | Where-Object { -not (Test-SamePath $_ $InstallDir) })
    }
    Write-Host "Removed bis from $InstallDir"
    return
}

# 1. Find or build bis.exe.
$bundled = Join-Path $root 'bis.exe'
$project = Join-Path $root 'BIS.CLI\BIS.CLI.csproj'

if (Test-Path $bundled) {
    $source = $bundled
    Write-Host "Using $source"
}
elseif (Test-Path $project) {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'The .NET 10 SDK is necessary to build from source. Get it from https://dotnet.microsoft.com/download'
    }

    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $rid = "win-$arch"
    $publishDir = Join-Path $root "artifacts\publish\$rid"
    Write-Host "Building bis for $rid ..."

    dotnet publish $project -c Release -r $rid --self-contained true `
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:DebugType=none -o $publishDir
    if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

    $source = Join-Path $publishDir 'BIS.CLI.exe'
}
else {
    throw "Cannot find bis.exe or BIS.CLI\BIS.CLI.csproj next to this script ($root)."
}

# 2. Copy bis.exe to the install folder.
New-Item -ItemType Directory -Force $InstallDir | Out-Null
Copy-Item -Force $source $target
Write-Host "Installed $target"

# 3. Add the install folder to the user PATH.
if (-not $NoPath) {
    $entries = Get-UserPath
    if (-not ($entries | Where-Object { Test-SamePath $_ $InstallDir })) {
        Set-UserPath ($entries + $InstallDir)
        Write-Host "Added $InstallDir to the user PATH."
    }
    if (-not (($env:Path -split ';') | Where-Object { Test-SamePath $_ $InstallDir })) {
        $env:Path = "$env:Path;$InstallDir"
    }
}

Write-Host ''
Write-Host 'Done. Open a new terminal, then run: bis --help'
