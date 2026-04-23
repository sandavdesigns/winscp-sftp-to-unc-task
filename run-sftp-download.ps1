$ErrorActionPreference = "Stop"

# Konfiguration
$WinScpPath = "C:\Program Files (x86)\WinSCP\WinSCP.com"
$SftpHost = "sftp.example.com"
$SftpUser = "meinuser"
$PrivateKeyPath = "C:\Keys\mein-key.ppk"
$PrivateKeyPassphrase = ""
$RemotePath = "/export"
$TargetPath = "\\fileserver\import\sftp"
$HostKeyFingerprint = ""
$DeleteRemoteFilesAfterDownload = $false

function Test-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Label ist leer. Bitte in der Konfiguration am Skriptanfang eintragen."
    }
}

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

Test-ConfigValue -Value $WinScpPath -Label "WinScpPath"
Test-ConfigValue -Value $SftpHost -Label "SftpHost"
Test-ConfigValue -Value $SftpUser -Label "SftpUser"
Test-ConfigValue -Value $PrivateKeyPath -Label "PrivateKeyPath"
Test-ConfigValue -Value $RemotePath -Label "RemotePath"
Test-ConfigValue -Value $TargetPath -Label "TargetPath"

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

$passphraseOption = if ([string]::IsNullOrWhiteSpace($PrivateKeyPassphrase)) {
    ""
} else {
    "-passphrase=`"$PrivateKeyPassphrase`""
}

$removeOption = if ($DeleteRemoteFilesAfterDownload) { "true" } else { "false" }

$winscpScript = @(
    "option batch abort"
    "option confirm off"
    "open sftp://$SftpUser@$SftpHost/ -privatekey=`"$PrivateKeyPath`" $passphraseOption $hostKeyOption"
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
