[CmdletBinding()]
param(
    [ValidateSet('Visual', 'Smoke')]
    [string]$Mode = 'Visual'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "DINX QEMU: $Message"
}

function Require-PositiveInteger([string]$Name, [int]$Value) {
    if ($Value -lt 1) {
        Fail "$Name must be a positive integer"
    }
}

function Get-Setting([string]$Name, [int]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }
    $parsed = 0
    if (-not [int]::TryParse($value, [Globalization.NumberStyles]::Integer, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        Fail "$Name must be an integer"
    }
    return $parsed
}

function Quote-ProcessArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Get-QemuPath {
    $configured = [Environment]::GetEnvironmentVariable('DINX_QEMU')
    if (-not [string]::IsNullOrWhiteSpace($configured)) {
        if (-not (Test-Path -LiteralPath $configured -PathType Leaf)) {
            Fail "DINX_QEMU does not point to a file: $configured"
        }
        return (Resolve-Path -LiteralPath $configured).Path
    }
    $command = Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        $command = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
    }
    if ($null -eq $command) {
        Fail 'qemu-system-x86_64.exe is not installed or is not on PATH'
    }
    return $command.Source
}

function Get-FreePort {
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally {
        $listener.Stop()
    }
}

function Connect-Monitor([int]$Port, [System.Diagnostics.Process]$Process) {
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        if ($Process.HasExited) {
            Fail "QEMU exited before opening its monitor (status $($Process.ExitCode))"
        }
        $candidate = New-Object System.Net.Sockets.TcpClient
        try {
            $async = $candidate.BeginConnect([System.Net.IPAddress]::Loopback, $Port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne(1000)) {
                $candidate.EndConnect($async)
                $candidate.NoDelay = $true
                $stream = $candidate.GetStream()
                $stream.ReadTimeout = 250
                $buffer = New-Object byte[] 4096
                while ($stream.DataAvailable) {
                    [void]$stream.Read($buffer, 0, $buffer.Length)
                }
                return $candidate
            }
        } catch {
            $candidate.Close()
        }
        $candidate.Close()
        Start-Sleep -Milliseconds 500
    }
    Fail "QEMU monitor did not open on 127.0.0.1:$Port"
}

function Send-MonitorCommand([System.Net.Sockets.TcpClient]$Monitor, [string]$Command) {
    $stream = $Monitor.GetStream()
    $bytes = [Text.Encoding]::ASCII.GetBytes("$Command`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
    Start-Sleep -Milliseconds 500
    $buffer = New-Object byte[] 4096
    while ($stream.DataAvailable) {
        [void]$stream.Read($buffer, 0, $buffer.Length)
    }
}

function Send-Keys([System.Net.Sockets.TcpClient]$Monitor, [string]$Keys) {
    if ([string]::IsNullOrWhiteSpace($Keys)) {
        return
    }
    foreach ($key in $Keys.Split(',')) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            Fail 'QEMU key list contains an empty key'
        }
        Send-MonitorCommand $Monitor "sendkey $($key.Trim())"
    }
}

function Capture-Screen([System.Net.Sockets.TcpClient]$Monitor, [string]$Path, [string]$Label) {
    $qemuPath = ([IO.Path]::GetFullPath($Path)).Replace('\', '/')
    Send-MonitorCommand $Monitor "screendump `"$qemuPath`""
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "QEMU $Label screendump was not created: $Path"
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 2 -or [Text.Encoding]::ASCII.GetString($bytes, 0, 2) -ne 'P6') {
        Fail "QEMU $Label screendump is not a binary PPM: $Path"
    }
    Write-Host "smoke-iso: $Label screendump: $Path ($($bytes.Length) bytes)"
}

function Stop-Qemu([System.Diagnostics.Process]$Process) {
    if ($null -ne $Process -and -not $Process.HasExited) {
        $Process.Kill()
        [void]$Process.WaitForExit(10000)
    }
}

$timeoutSeconds = if ($Mode -eq 'Visual') { Get-Setting 'DINX_QEMU_TIMEOUT' 90 } else { Get-Setting 'DINX_QEMU_TIMEOUT' 20 }
$memoryMb = Get-Setting 'DINX_QEMU_MEMORY' 2048
$screenshotDelay = Get-Setting 'DINX_QEMU_SCREENSHOT_DELAY' 60
$bootScreenshotDelay = Get-Setting 'DINX_QEMU_BOOT_SCREENSHOT_DELAY' 3
$postScreenshotDelay = Get-Setting 'DINX_QEMU_POST_SCREENSHOT_DELAY' 10
Require-PositiveInteger 'DINX_QEMU_TIMEOUT' $timeoutSeconds
Require-PositiveInteger 'DINX_QEMU_MEMORY' $memoryMb
if ($screenshotDelay -lt 0 -or $postScreenshotDelay -lt 0 -or $bootScreenshotDelay -lt 0) {
    Fail 'screenshot delays must be non-negative integers'
}

$metadataPath = Join-Path $PSScriptRoot 'dinx-iso.json'
if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    Fail "missing ISO metadata: $metadataPath"
}
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if ([string]$metadata.url -notmatch '^https://') {
    Fail 'ISO metadata URL must use HTTPS'
}
if ([string]$metadata.sha512 -notmatch '^[0-9a-fA-F]{128}$') {
    Fail 'ISO metadata SHA-512 is invalid'
}
$isoPath = Join-Path $PSScriptRoot ([string]$metadata.file)
$downloadPath = "$isoPath.download"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Verify-Iso([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA512).Hash.ToLowerInvariant()
    return $actual -eq ([string]$metadata.sha512).ToLowerInvariant()
}

if (-not (Verify-Iso $isoPath)) {
    if (Test-Path -LiteralPath $isoPath -PathType Leaf) {
        Remove-Item -LiteralPath $isoPath -Force
    }
    if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
        Remove-Item -LiteralPath $downloadPath -Force
    }
    Write-Host "smoke-iso: downloading verified ISO from $($metadata.url)"
    Invoke-WebRequest -UseBasicParsing -Uri ([string]$metadata.url) -OutFile $downloadPath
    if (-not (Verify-Iso $downloadPath)) {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        Fail 'downloaded ISO failed SHA-512 verification'
    }
    Move-Item -LiteralPath $downloadPath -Destination $isoPath
}
Write-Host "smoke-iso: ISO SHA-512 verified: $isoPath"

$qemuPath = Get-QemuPath
$port = Get-FreePort
$logPath = Join-Path $PSScriptRoot 'evidence/dinx-qemu-serial.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null
$visual = $Mode -eq 'Visual'
$display = [Environment]::GetEnvironmentVariable('DINX_QEMU_DISPLAY')
if ([string]::IsNullOrWhiteSpace($display)) {
    $display = if ($visual) { 'sdl' } else { 'none' }
}
$bootKeys = [Environment]::GetEnvironmentVariable('DINX_QEMU_BOOT_KEYS')
if ([string]::IsNullOrWhiteSpace($bootKeys)) {
    $bootKeys = 'down,down,ret'
}
$postKeys = [Environment]::GetEnvironmentVariable('DINX_QEMU_POST_KEYS')
if ([string]::IsNullOrWhiteSpace($postKeys)) {
    $postKeys = 'ret,d,i,n,x,ret'
}
$screenshotPath = Join-Path $PSScriptRoot 'evidence/dinx-qemu-graphical.ppm'
$bootScreenshotPath = Join-Path $PSScriptRoot 'evidence/dinx-qemu-boot.ppm'
$postScreenshotPath = Join-Path $PSScriptRoot 'evidence/dinx-qemu-session.ppm'

$rawArguments = @(
    '-accel', 'tcg,thread=multi',
    '-m', [string]$memoryMb,
    '-cdrom', $isoPath,
    '-boot', 'order=d',
    '-display', $display,
    '-monitor', "tcp:127.0.0.1:$port,server=on,wait=off",
    '-serial', "file:$logPath",
    '-netdev', 'user,id=net0',
    '-device', 'virtio-net-pci,netdev=net0',
    '-no-reboot',
    '-no-shutdown'
)
$arguments = ($rawArguments | ForEach-Object { Quote-ProcessArgument ([string]$_) }) -join ' '
$windowStyle = if ($visual) { 'Normal' } else { 'Hidden' }
$process = $null
$monitor = $null
try {
    $process = Start-Process -FilePath $qemuPath -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -PassThru -WindowStyle $windowStyle
    $monitor = Connect-Monitor $port $process
    if ($visual) {
        Start-Sleep -Seconds $bootScreenshotDelay
        Capture-Screen $monitor $bootScreenshotPath 'boot'
    }
    Send-Keys $monitor $bootKeys
    Write-Host "smoke-iso: sent QEMU boot keys: $bootKeys"

    if ($visual) {
        Start-Sleep -Seconds $screenshotDelay
        Capture-Screen $monitor $screenshotPath 'graphical'
        Send-Keys $monitor $postKeys
        Write-Host "smoke-iso: sent post-screenshot QEMU keys: $postKeys"
        Start-Sleep -Seconds $postScreenshotDelay
        Capture-Screen $monitor $postScreenshotPath 'post'
    } else {
        Start-Sleep -Seconds $timeoutSeconds
    }

    if ($process.HasExited) {
        Fail "QEMU exited before the $Mode smoke completed (status $($process.ExitCode))"
    }
    Write-Host "smoke-iso: QEMU remained alive for the $Mode smoke window"
} finally {
    if ($null -ne $monitor) {
        $monitor.Close()
    }
    Stop-Qemu $process
}
