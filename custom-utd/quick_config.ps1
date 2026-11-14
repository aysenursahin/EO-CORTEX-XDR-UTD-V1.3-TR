# Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Disable IE Enhanced Security Configuration for Users
$UserSettingPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $UserSettingPath -Name "IsInstalled" -Value 0

# Disable IE Enhanced Security Configuration for Administrators
$AdminSettingPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminSettingPath -Name "IsInstalled" -Value 0

# Disable Windows Defender Real-Time Protection
Set-MpPreference -DisableRealtimeMonitoring $true

# Disable Windows Defender Automatic Sample Submission
Set-MpPreference -MAPSReporting 0
