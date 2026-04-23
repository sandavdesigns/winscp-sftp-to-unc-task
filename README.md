# SFTP nach UNC per geplanter Windows-Aufgabe

Diese Variante ist fuer deinen Fall praktisch, weil `*.ppk` direkt von **WinSCP** unterstuetzt wird.  
Fuer den Windows-Taskplaner ist das meist die stabilste Loesung.

## Was du brauchst

1. **WinSCP installieren**
   - Download: https://winscp.net/
   - Standardpfad ist meistens:
     - `C:\Program Files (x86)\WinSCP\WinSCP.com`
     - oder `C:\Program Files\WinSCP\WinSCP.com`

2. Im Skript oben in der **Konfiguration** diese Werte eintragen:
   - `WinScpPath`
   - `SftpHost`
   - `SftpUser`
   - `PrivateKeyPath` zur `*.ppk`
   - optional `PrivateKeyPassphrase`, falls die `*.ppk` passwortgeschuetzt ist
   - `RemotePath` auf dem SFTP
   - `TargetPath` als UNC-Pfad, z. B. `\\server\freigabe\eingang`
   - `WorkingDirectory`, z. B. `C:\SftpTransferTask`
   - optional `HostKeyFingerprint`
   - optional `DeleteRemoteFilesAfterDownload = $true`

3. Sicherstellen, dass das Konto der geplanten Aufgabe:
   - auf die `*.ppk` zugreifen darf
   - Schreibrechte auf dem UNC-Pfad hat
   - den SFTP-Server erreichen kann

## Dateien

- [run-sftp-download.ps1](/Users/davidmuller/Documents/Codex/2026-04-23-ich-brauche-in-tool-poweshell-oder/run-sftp-download.ps1)

## Konfiguration im Skript

```powershell
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
```

## Beispielaufruf

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Pfad\run-sftp-download.ps1"
```

## Als geplante Aufgabe einrichten

Programm/Skript:

```text
powershell.exe
```

Argumente:

```text
-ExecutionPolicy Bypass -File "C:\Pfad\run-sftp-download.ps1"
```

Empfehlungen im Taskplaner:

- "Unabhaengig von der Benutzeranmeldung ausfuehren"
- "Mit hoechsten Privilegien ausfuehren" nur wenn wirklich noetig
- Ein dediziertes Service-Konto verwenden
- Testweise zuerst manuell in genau diesem Benutzerkontext starten

## Wichtige Hinweise

- Wenn der Server einen **Host Key Fingerprint** vorgibt, trag ihn in der Skriptvariable `HostKeyFingerprint` ein. Das ist sicherer als der eingebaute Fallback `acceptnew`.
- Wenn die `*.ppk` mit einer Passphrase geschuetzt ist, trag sie in `PrivateKeyPassphrase` ein. Wenn nicht, leer lassen.
- Verwende fuer `WorkingDirectory`, den Skriptpfad und moeglichst auch den Key-Pfad am besten keine Umlaute oder Sonderzeichen.
- UNC-Pfade funktionieren nur, wenn das Task-Konto wirklich auf die Freigabe zugreifen darf.
- Netzlaufwerke wie `Z:` besser **nicht** verwenden, sondern direkt `\\server\share\...`.
- Falls du statt kompletter Synchronisation nur einzelne Dateien ziehen willst, kann das Skript leicht angepasst werden.

## Troubleshooting

- Wenn kein WinSCP-Log erzeugt wird, ist WinSCP oft gar nicht gestartet. Dann zuerst `WinScpPath` pruefen.
- Das Skript schreibt temporaere Dateien und Logs jetzt in `WorkingDirectory`, z. B. `C:\SftpTransferTask`. Verwende dort keinen Pfad mit Umlauten.
- Die geplante Aufgabe sollte mit einem Benutzer laufen, der Schreibrechte auf den Skriptordner, den UNC-Pfad und die `*.ppk` hat.
