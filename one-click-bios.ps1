[CmdletBinding()]
param(
    [string]$ShortcutName = "1 Click BIOS",
    [string]$ScriptUrl = "https://raw.githubusercontent.com/luizbizzio/one-click-bios/main/one-click-bios.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$ShortcutName = [string]$ShortcutName

if ([string]::IsNullOrWhiteSpace($ShortcutName)) {
    throw "ShortcutName cannot be empty."
}

$ShortcutName = $ShortcutName.Trim()

if ($ShortcutName.EndsWith('.')) {
    throw "ShortcutName cannot end with a period."
}

if ($ShortcutName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
    throw "ShortcutName contains invalid file name characters."
}

if ([string]::IsNullOrWhiteSpace($ScriptUrl)) {
    throw "ScriptUrl cannot be empty."
}

$powershellExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$shutdownExe = "$env:WINDIR\System32\shutdown.exe"
$schTasksExe = "$env:WINDIR\System32\schtasks.exe"
$wscriptExe = "$env:WINDIR\System32\wscript.exe"

if (-not (Test-Path -LiteralPath $powershellExe)) {
    throw "powershell.exe not found: $powershellExe"
}

$isAdmin = Test-Admin

if (-not $isAdmin) {
    $scriptPath = $null

    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
        $scriptPath = $PSCommandPath
    } else {
        $scriptPath = Join-Path $env:TEMP "one-click-bios.ps1"
        Invoke-WebRequest -Uri $ScriptUrl -UseBasicParsing -OutFile $scriptPath

        if (-not (Test-Path -LiteralPath $scriptPath)) {
            throw "Failed to download installer script: $ScriptUrl"
        }
    }

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$scriptPath`"",
        "-ShortcutName", "`"$ShortcutName`"",
        "-ScriptUrl", "`"$ScriptUrl`""
    ) -join " "

    try {
        Start-Process -FilePath $powershellExe -Verb RunAs -WindowStyle Hidden -ArgumentList $args
        exit 0
    } catch {
        throw "Administrator elevation was cancelled or failed."
    }
}

$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$userId = $currentIdentity.Name
$userNameSafe = ($env:USERNAME -replace '[\\/:*?"<>| ]', '_')

$taskName = "OneClickBIOS_$userNameSafe"
$programsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
$menuFolderName = "1 Click BIOS"
$menuFolderPath = Join-Path $programsPath $menuFolderName
$installDir = Join-Path $env:APPDATA "OneClickBIOS"

$shortcutPath = Join-Path $menuFolderPath ($ShortcutName + ".lnk")
$uninstallShortcutPath = Join-Path $menuFolderPath ("Uninstall " + $ShortcutName + ".lnk")

$vbsPath = Join-Path $installDir "launcher.vbs"
$uninstallPath = Join-Path $installDir "uninstall.ps1"

$oldRootShortcutPath = Join-Path $programsPath ($ShortcutName + ".lnk")
$oldRootUninstallShortcutPath = Join-Path $programsPath ("Uninstall " + $ShortcutName + ".lnk")
$oldVbsInProgramsPath = Join-Path $programsPath ($ShortcutName + ".vbs")
$oldLauncherPath = Join-Path $installDir "launcher.ps1"

if (-not (Test-Path -LiteralPath $menuFolderPath)) {
    New-Item -ItemType Directory -Path $menuFolderPath -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $shutdownExe)) {
    throw "shutdown.exe not found: $shutdownExe"
}

if (-not (Test-Path -LiteralPath $schTasksExe)) {
    throw "schtasks.exe not found: $schTasksExe"
}

if (-not (Test-Path -LiteralPath $wscriptExe)) {
    throw "wscript.exe not found: $wscriptExe"
}

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Unregister-ScheduledTask -TaskName "OneClickBIOS" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$action = New-ScheduledTaskAction -Execute $shutdownExe -Argument "/r /fw /t 0 /f"
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings
$task.Description = "Restart directly into BIOS/UEFI firmware settings"

Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

foreach ($path in @(
    $shortcutPath,
    $uninstallShortcutPath,
    $oldRootShortcutPath,
    $oldRootUninstallShortcutPath,
    $oldVbsInProgramsPath,
    $vbsPath,
    $oldLauncherPath
)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}

$vbs = @"
Option Explicit
Dim ws, result, cmd, code
Set ws = CreateObject("WScript.Shell")
result = MsgBox("Restart now and enter BIOS/UEFI firmware settings?", vbYesNo + vbQuestion, "$ShortcutName")
If result = vbYes Then
    cmd = """" & "$schTasksExe" & """" & " /Run /TN " & """" & "$taskName" & """"
    code = ws.Run(cmd, 0, True)
    If code <> 0 Then
        MsgBox "Failed to start the BIOS task.", vbCritical, "$ShortcutName"
    End If
End If
"@

Set-Content -LiteralPath $vbsPath -Value $vbs -Encoding Unicode

$uninstallScript = @"
[CmdletBinding()]
param(
    [switch]`$SkipConfirm
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

function Test-Admin {
    `$id = [Security.Principal.WindowsIdentity]::GetCurrent()
    `$p = New-Object Security.Principal.WindowsPrincipal(`$id)
    `$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

`$powershellExe = "$powershellExe"
`$scriptPath = `$PSCommandPath
`$taskName = "$taskName"
`$shortcutPath = "$shortcutPath"
`$uninstallShortcutPath = "$uninstallShortcutPath"
`$oldRootShortcutPath = "$oldRootShortcutPath"
`$oldRootUninstallShortcutPath = "$oldRootUninstallShortcutPath"
`$oldVbsInProgramsPath = "$oldVbsInProgramsPath"
`$oldLauncherPath = "$oldLauncherPath"
`$vbsPath = "$vbsPath"
`$menuFolderPath = "$menuFolderPath"
`$installDir = "$installDir"

`$ws = New-Object -ComObject WScript.Shell

try {
    if (-not `$SkipConfirm) {
        `$result = `$ws.Popup("Uninstall ${ShortcutName}?", 0, "Uninstall ${ShortcutName}", 4 + 48)
        if (`$result -ne 6) {
            exit 0
        }
    }

    if (-not (Test-Admin)) {
        `$args = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden",
            "-File", ('"{0}"' -f `$scriptPath),
            "-SkipConfirm"
        ) -join " "

        try {
            Start-Process -FilePath `$powershellExe -Verb RunAs -WindowStyle Hidden -ArgumentList `$args
            exit 0
        } catch {
            `$ws.Popup("Administrator elevation was cancelled or failed.", 0, "Uninstall ${ShortcutName}", 48) | Out-Null
            exit 1
        }
    }

    Unregister-ScheduledTask -TaskName `$taskName -Confirm:`$false -ErrorAction SilentlyContinue | Out-Null
    Unregister-ScheduledTask -TaskName "OneClickBIOS" -Confirm:`$false -ErrorAction SilentlyContinue | Out-Null

    foreach (`$path in @(
        `$shortcutPath,
        `$uninstallShortcutPath,
        `$oldRootShortcutPath,
        `$oldRootUninstallShortcutPath,
        `$oldVbsInProgramsPath,
        `$oldLauncherPath,
        `$vbsPath
    )) {
        if (Test-Path -LiteralPath `$path) {
            Remove-Item -LiteralPath `$path -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path -LiteralPath `$menuFolderPath) {
        if (-not (Get-ChildItem -LiteralPath `$menuFolderPath -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath `$menuFolderPath -Force -ErrorAction SilentlyContinue
        }
    }

    `$ws.Popup("${ShortcutName} was removed.", 0, "Uninstall ${ShortcutName}", 64) | Out-Null

    `$cmdExe = "$env:WINDIR\System32\cmd.exe"
    if (Test-Path -LiteralPath `$cmdExe) {
        `$cleanup = 'ping 127.0.0.1 -n 3 >nul & del /f /q "' + `$scriptPath + '" & if exist "' + `$installDir + '" rmdir /s /q "' + `$installDir + '"'
        Start-Process -FilePath `$cmdExe -ArgumentList ('/c ' + `$cleanup) -WindowStyle Hidden
    }
} catch {
    `$msg = `$_.Exception.Message
    if ([string]::IsNullOrWhiteSpace(`$msg)) {
        `$msg = "Unknown uninstall error."
    }
    `$ws.Popup(("Uninstall failed: " + `$msg), 0, "Uninstall ${ShortcutName}", 16) | Out-Null
}
"@

Set-Content -LiteralPath $uninstallPath -Value $uninstallScript -Encoding UTF8

$wsh = New-Object -ComObject WScript.Shell

$sc = $wsh.CreateShortcut($shortcutPath)
$sc.TargetPath = $wscriptExe
$sc.Arguments = '"' + $vbsPath + '"'
$sc.WorkingDirectory = "$env:WINDIR\System32"
$sc.IconLocation = "$env:WINDIR\System32\SHELL32.dll,12"
$sc.Description = "Show confirmation and restart directly into BIOS/UEFI firmware settings"
$sc.Save()

$usc = $wsh.CreateShortcut($uninstallShortcutPath)
$usc.TargetPath = $powershellExe
$usc.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $uninstallPath + '"'
$usc.WorkingDirectory = "$env:WINDIR\System32"
$usc.IconLocation = "$env:WINDIR\SysWOW64\msiexec.exe,0"
$usc.Description = "Uninstall 1 Click BIOS"
$usc.Save()

Write-Host "Start Menu folder created successfully:" -ForegroundColor Green
Write-Host $menuFolderPath -ForegroundColor Cyan
Write-Host "Shortcut created successfully:" -ForegroundColor Green
Write-Host $shortcutPath -ForegroundColor Cyan
Write-Host "Uninstall shortcut created successfully:" -ForegroundColor Green
Write-Host $uninstallShortcutPath -ForegroundColor Cyan
Write-Host "Launcher created successfully:" -ForegroundColor Green
Write-Host $vbsPath -ForegroundColor Cyan
Write-Host "Uninstall script created successfully:" -ForegroundColor Green
Write-Host $uninstallPath -ForegroundColor Cyan
Write-Host "Task created successfully:" -ForegroundColor Green
Write-Host $taskName -ForegroundColor Cyan
