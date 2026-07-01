[CmdletBinding()]
param(
    [string]$InstallRoot = $env:GRADENCE_CODE_INSTALL_ROOT
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Repo = 'wmjwmj100/gradence-code-install'
$Asset = 'gradence-code-windows-x64.zip'

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $env:LOCALAPPDATA 'Gradence\Code'
}

$BinDir = Join-Path $InstallRoot 'bin'
$RuntimeRoot = Join-Path $InstallRoot '.runtime'
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gradence-code-' + [guid]::NewGuid().ToString('N'))
$ZipPath = Join-Path $TempRoot $Asset
$ShaPath = Join-Path $TempRoot ($Asset + '.sha256')
$ExtractDir = Join-Path $TempRoot 'extract'

function Normalize-PathEntry {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    try { return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\', '/').ToLowerInvariant() }
    catch { return $Path.TrimEnd('\', '/').ToLowerInvariant() }
}

function Ensure-UserPathEntry {
    param([string]$Directory)
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $needle = Normalize-PathEntry $Directory
    if (@($entries | ForEach-Object { Normalize-PathEntry $_ }) -notcontains $needle) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $Directory) -join ';'), 'User')
    }
    if (@($env:Path -split ';' | ForEach-Object { Normalize-PathEntry $_ }) -notcontains $needle) {
        $env:Path = "$Directory;$env:Path"
    }
}

try {
    New-Item -ItemType Directory -Force -Path $TempRoot, $BinDir, $RuntimeRoot | Out-Null
    $BaseUrl = "https://github.com/$Repo/releases/latest/download"

    Write-Host 'Downloading Gradence Code...'
    Invoke-WebRequest -Uri "$BaseUrl/$Asset" -OutFile $ZipPath -UseBasicParsing
    Invoke-WebRequest -Uri "$BaseUrl/$Asset.sha256" -OutFile $ShaPath -UseBasicParsing

    $Expected = ([regex]::Match((Get-Content $ShaPath -Raw), '[0-9a-fA-F]{64}')).Value.ToLowerInvariant()
    $Actual = (Get-FileHash $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Expected -ne $Actual) { throw 'Checksum mismatch' }

    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractDir -Force
    $SourceExe = Get-ChildItem -LiteralPath $ExtractDir -Recurse -File -Filter 'wecode.exe' | Select-Object -First 1
    if ($null -eq $SourceExe) { throw 'Archive did not contain wecode.exe' }

    $RuntimeDir = Join-Path $RuntimeRoot $Actual.Substring(0, 16)
    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
    $RuntimeExe = Join-Path $RuntimeDir 'gc-runtime.exe'
    Copy-Item -LiteralPath $SourceExe.FullName -Destination $RuntimeExe -Force
    try { Unblock-File -LiteralPath $RuntimeExe } catch { }
    try { (Get-Item -LiteralPath $RuntimeRoot).Attributes = (Get-Item -LiteralPath $RuntimeRoot).Attributes -bor [IO.FileAttributes]::Hidden } catch { }

    $Launcher = Join-Path $BinDir 'wecode.cmd'
    $LauncherBody = @"
@echo off
setlocal
set "GRADENCE_CODE_RUNTIME=$RuntimeExe"
"%GRADENCE_CODE_RUNTIME%" %*
exit /b %ERRORLEVEL%
"@
    Set-Content -LiteralPath $Launcher -Value $LauncherBody -Encoding ASCII

    Ensure-UserPathEntry -Directory $BinDir
    Write-Host "Installed launcher: $Launcher"
    Write-Host 'Open a new terminal and run: wecode'
    & $RuntimeExe --version
} finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
