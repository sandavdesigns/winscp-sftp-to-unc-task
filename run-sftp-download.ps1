$ErrorActionPreference = "Stop"

# Konfiguration
$WinScpPath = "C:\Program Files (x86)\WinSCP\WinSCP.com"
$SftpHost = "sftp.example.com"
$SftpUser = "meinuser"
$PrivateKeyPath = "C:\Keys\mein-key.ppk"
$PrivateKeyPassphrase = ""
$RemotePath = "/export"
$TargetPath = "\\fileserver\import\sftp"
$WorkingDirectory = "C:\SftpTransferTask"
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
Test-ConfigValue -Value $WorkingDirectory -Label "WorkingDirectory"

Test-RequiredPath -Path $WinScpPath -Label "WinSCP"
Test-RequiredPath -Path $PrivateKeyPath -Label "Private Key"

if (-not (Test-Path -LiteralPath $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}

$logDir = Join-Path $WorkingDirectory "logs"
$tempDir = Join-Path $WorkingDirectory "temp"

if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
    New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$winscpScriptPath = Join-Path $tempDir "winscp-$timestamp.txt"
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

$utf8BomEncoding = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllLines($winscpScriptPath, $winscpScript, $utf8BomEncoding)

try {
    $argumentList = @(
        "/ini=nul"
        "/log=$sessionLogPath"
        "/xmllog=$xmlLogPath"
        "/script=$winscpScriptPath"
    )

    $process = Start-Process `
        -FilePath $WinScpPath `
        -ArgumentList $argumentList `
        -Wait `
        -PassThru `
        -NoNewWindow

    $exitCode = $process.ExitCode

    if ($exitCode -ne 0) {
        $sessionLogExists = Test-Path -LiteralPath $sessionLogPath
        $xmlLogExists = Test-Path -LiteralPath $xmlLogPath

        if ($sessionLogExists -or $xmlLogExists) {
            throw "WinSCP ist mit Exit-Code $exitCode fehlgeschlagen. Session-Log: $sessionLogPath | XML-Log: $xmlLogPath"
        }

        throw "WinSCP ist mit Exit-Code $exitCode fehlgeschlagen, aber es wurde kein Log geschrieben. Bitte pruefe WinScpPath, Berechtigungen auf den Skriptordner und ob WinSCP unter dem Task-Benutzer gestartet werden darf."
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
