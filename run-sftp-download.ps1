param(
    [Parameter(Mandatory = $true)]
    [string]$WinScpPath,

    [Parameter(Mandatory = $true)]
    [string]$SftpHost,

    [Parameter(Mandatory = $true)]
    [string]$SftpUser,

    [Parameter(Mandatory = $true)]
    [string]$PrivateKeyPath,

    [Parameter(Mandatory = $true)]
    [string]$RemotePath,

    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [string]$HostKeyFingerprint = "",

    [switch]$DeleteRemoteFilesAfterDownload
)

$ErrorActionPreference = "Stop"

function Test-RequiredPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label nicht gefunden: $Path"
    }
}

Test-RequiredPath -Path $WinScpPath -Label "WinSCP"
Test-RequiredPath -Path $PrivateKeyPath -Label "Private Key"

if (-not (Test-Path -LiteralPath $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}

$scriptDir = Split-Path -Parent $PSCommandPath
$logDir = Join-Path $scriptDir "logs"

if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$winscpScriptPath = Join-Path $env:TEMP "winscp-$timestamp.txt"
$sessionLogPath = Join-Path $logDir "winscp-session-$timestamp.log"
$xmlLogPath = Join-Path $logDir "winscp-transfer-$timestamp.xml"

$hostKeyOption = if ([string]::IsNullOrWhiteSpace($HostKeyFingerprint)) {
    "-hostkey=acceptnew"
} else {
    "-hostkey=`"$HostKeyFingerprint`""
}

$removeOption = if ($DeleteRemoteFilesAfterDownload) { "true" } else { "false" }

$winscpScript = @(
    "option batch abort"
    "option confirm off"
    "open sftp://$SftpUser@$SftpHost/ -privatekey=`"$PrivateKeyPath`" $hostKeyOption"
    "lcd `"$TargetPath`""
    "cd `"$RemotePath`""
    "synchronize local -transfer=binary -delete=$removeOption `"$TargetPath`" `"$RemotePath`""
    "exit"
)

Set-Content -LiteralPath $winscpScriptPath -Value $winscpScript -Encoding ASCII

try {
    & $WinScpPath `
        "/ini=nul" `
        "/log=$sessionLogPath" `
        "/xmllog=$xmlLogPath" `
        "/script=$winscpScriptPath"

    if ($LASTEXITCODE -ne 0) {
        throw "WinSCP ist mit Exit-Code $LASTEXITCODE fehlgeschlagen. Siehe Log: $sessionLogPath"
    }

    Write-Host "Download erfolgreich abgeschlossen."
    Write-Host "Ziel: $TargetPath"
    Write-Host "Session-Log: $sessionLogPath"
    Write-Host "XML-Log: $xmlLogPath"
}
finally {
    if (Test-Path -LiteralPath $winscpScriptPath) {
        Remove-Item -LiteralPath $winscpScriptPath -Force -ErrorAction SilentlyContinue
    }
}
