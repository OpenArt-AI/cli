<#
.SYNOPSIS
    OpenArt CLI installer for Windows.

.DESCRIPTION
    Downloads the openart binary for this machine's architecture, verifies it
    against the release checksums, and installs it under your user profile -- no
    administrator rights needed.

    Quick install:
        irm https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.ps1 | iex

    A piped script cannot receive parameters, so for that form set environment
    variables instead:
        $env:OPENART_VERSION = '0.1.0'
        $env:OPENART_INSTALL_DIR = 'C:\tools\openart'
        irm https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.ps1 | iex

    Or save the script and pass parameters normally:
        .\install.ps1 -Version 0.1.0 -InstallDir C:\tools\openart

.PARAMETER Version
    Install this exact version instead of the latest release.

.PARAMETER InstallDir
    Directory to install into. Defaults to %LOCALAPPDATA%\Programs\openart\bin.

.PARAMETER NoVerify
    Skip the SHA-256 checksum check. Not recommended.

.PARAMETER NoPathUpdate
    Do not add the install directory to your user PATH.
#>
[CmdletBinding()]
param(
    [string] $Version = $env:OPENART_VERSION,
    [string] $InstallDir = $env:OPENART_INSTALL_DIR,
    [switch] $NoVerify,
    [switch] $NoPathUpdate
)

$ErrorActionPreference = 'Stop'
# Invoke-WebRequest's progress bar makes downloads several times slower in
# Windows PowerShell, and it renders as garbage when the output is piped.
$ProgressPreference = 'SilentlyContinue'

$Repo = 'OpenArt-AI/cli'
$Binary = 'openart'

function Fail($message) {
    Write-Host "error: $message" -ForegroundColor Red
    exit 1
}

# Windows PowerShell 5.1 still negotiates TLS 1.0 by default, which GitHub
# refuses. PowerShell 7+ already does the right thing.
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# --- Which build do we want? ------------------------------------------------

# On an arm64 machine running the x64 PowerShell, PROCESSOR_ARCHITECTURE reports
# the emulated AMD64 and the real one moves to PROCESSOR_ARCHITEW6432 -- so read
# that first or arm64 users silently get an emulated binary.
$rawArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($rawArch) {
    'AMD64' { $arch = 'amd64' }
    'ARM64' { $arch = 'arm64' }
    default { Fail "unsupported architecture '$rawArch' -- only amd64 and arm64 are built" }
}

if (-not $Version) {
    try {
        $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
        $Version = $latest.tag_name
    } catch {
        Fail "could not determine the latest version ($($_.Exception.Message)) -- retry, or pass -Version"
    }
}
$Version = $Version -replace '^v', ''  # tags carry a v, archive names do not

$archive = "${Binary}_${Version}_windows_${arch}.zip"
$baseUrl = "https://github.com/$Repo/releases/download/v$Version"

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\openart\bin'
}

# --- Download ---------------------------------------------------------------

$tmp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $zip = Join-Path $tmp $archive

    Write-Host "Downloading $Binary $Version (windows/$arch)..."
    try {
        Invoke-WebRequest -Uri "$baseUrl/$archive" -OutFile $zip -UseBasicParsing
    } catch {
        Fail "could not download $baseUrl/$archive -- is $Version a released version? ($($_.Exception.Message))"
    }

    if (-not $NoVerify) {
        $sums = Join-Path $tmp 'checksums.txt'
        try {
            Invoke-WebRequest -Uri "$baseUrl/checksums.txt" -OutFile $sums -UseBasicParsing
        } catch {
            Fail "could not download the checksum file -- re-run with -NoVerify to skip this check"
        }

        $expected = $null
        foreach ($line in Get-Content $sums) {
            $parts = $line -split '\s+', 2
            if ($parts.Count -eq 2 -and $parts[1].Trim() -eq $archive) { $expected = $parts[0].Trim() }
        }
        if (-not $expected) { Fail "$archive is not listed in checksums.txt" }

        # Get-FileHash returns upper case, checksums.txt is lower case; compare
        # and report in one casing so the two hashes can be eyeballed.
        $actual = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        $expected = $expected.ToLowerInvariant()
        if ($actual -ne $expected) {
            Fail "checksum mismatch for ${archive}: got $actual, expected $expected. Do not use this download."
        }
        Write-Host 'Checksum verified.'
    }

    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $extracted = Join-Path $tmp "$Binary.exe"
    if (-not (Test-Path $extracted)) { Fail "the archive did not contain $Binary.exe" }

    # --- Install ------------------------------------------------------------

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $target = Join-Path $InstallDir "$Binary.exe"
    try {
        Copy-Item -Path $extracted -Destination $target -Force
    } catch {
        Fail "could not write $target -- close any running '$Binary' process and try again ($($_.Exception.Message))"
    }

    # Mark of the Web: SmartScreen blocks anything downloaded from the internet
    # until the alternate data stream is cleared.
    Unblock-File -Path $target -ErrorAction SilentlyContinue
} finally {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# --- PATH -------------------------------------------------------------------

if (-not $NoPathUpdate) {
    # Read the stored user PATH rather than $env:PATH: the process copy already
    # has the machine PATH folded in, so appending it back would persist the
    # whole thing into the user scope.
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($entries -notcontains $InstallDir) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $InstallDir) -join ';'), 'User')
        Write-Host "Added $InstallDir to your user PATH."
    }
    # Make it usable in this session too, without waiting for a new shell.
    if (($env:PATH -split ';') -notcontains $InstallDir) {
        $env:PATH = "$InstallDir;$env:PATH"
    }
}
# What the PATH actually holds, not whether we tried to change it: -NoPathUpdate
# is usually passed by people whose PATH is already set up the way they want.
$onPath = (($env:PATH -split ';' | Where-Object { $_ }) -contains $InstallDir)

Write-Host ''
# The install itself already succeeded by this point, so a binary that will not
# launch (a blocked file, a mismatched architecture) must not turn into a
# terminating error under $ErrorActionPreference = 'Stop'.
$reported = try { & $target version 2>$null | Select-Object -First 1 } catch { $null }
if (-not $reported) { $reported = "$Binary $Version" }
Write-Host "Installed $reported to $target" -ForegroundColor Green
Write-Host ''
if ($onPath) {
    Write-Host "Get started with:  $Binary login"
    Write-Host '(open a new terminal if the command is not found)'
} else {
    Write-Host "$InstallDir is not on your PATH. Add it, or run the binary directly:"
    Write-Host "  $target login"
}
