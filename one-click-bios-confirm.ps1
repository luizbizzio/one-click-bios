[CmdletBinding()]
param(
    [string]$ShortcutName = "1 Click BIOS"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    $ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`"",
        "-ShortcutName", "`"$ShortcutName`""
    ) -join " "
    Start-Process -FilePath $ps -Verb RunAs -WindowStyle Hidden -ArgumentList $args
    exit
}

$programsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
$shortcutPath = Join-Path $programsPath ($ShortcutName + ".lnk")

$taskName = $ShortcutName
$vbsPath = Join-Path $programsPath ($ShortcutName + ".vbs")

if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force }
if (Test-Path -LiteralPath $vbsPath) { Remove-Item -LiteralPath $vbsPath -Force }

$psTask = @"
Add-Type -AssemblyName PresentationFramework
`$result = [System.Windows.MessageBox]::Show("Your PC will restart and open BIOS/UEFI now.`n`nDo you want to continue?`n`nSave your work before continuing.","One Click BIOS",[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
if(`$result -eq [System.Windows.MessageBoxResult]::Yes){
  & "`$env:WINDIR\System32\shutdown.exe" /r /fw /t 0 /f
}
"@

$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($psTask))

$psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershellw.exe"
if (-not (Test-Path -LiteralPath $psExe)) {
    $psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
}

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
} catch { }

$action = New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $encoded"
$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

$task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

$vbs = @'
Option Explicit
Dim svc, root, t
Set svc = CreateObject("Schedule.Service")
svc.Connect
Set root = svc.GetFolder("\")
Set t = root.GetTask("TASK_NAME")
t.Run ""
'@.Replace("TASK_NAME", $taskName.Replace('"','""'))

Set-Content -LiteralPath $vbsPath -Value $vbs -Encoding ASCII

$wscriptPath = "$env:WINDIR\System32\wscript.exe"
$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($shortcutPath)
$sc.TargetPath = $wscriptPath
$sc.Arguments = '"' + $vbsPath + '"'
$sc.WorkingDirectory = "$env:WINDIR\System32"
$sc.IconLocation = "$env:WINDIR\System32\SHELL32.dll,12"
$sc.Description = "Restart directly into BIOS/UEFI firmware settings"
$sc.Save()

Write-Host "Shortcut created successfully:" -ForegroundColor Green
Write-Host $shortcutPath -ForegroundColor Cyan
