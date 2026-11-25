# ---------------------------------------------------------------------------
# 03 - Her makinenin hostname'ini Name tag'ine gore degistirir
#      ve roluna gore masaustu arkaplanini ayarlar
#
# AMI'den acilan tum makineler base makinenin adini tasir. Bu script her
# birini kendi adina (UTD-VICTIM01 / UTD-ATTACKER01, ...) cevirir, roluna
# gore wallpaper'i (C:\WorkshopSetup\wallpapers\<rol>.png) ayarlar ve
# makineyi yeniden baslatir. Zaten dogru adda olanlara dokunmaz.
#
# Kullanim:
#   .\03-rename-hosts.ps1                        # tum makineler
#   .\03-rename-hosts.ps1 -Only UTD-VICTIM01      # tek makine
# ---------------------------------------------------------------------------
param([string[]]$Only)
. "$PSScriptRoot\common.ps1"

$instances = @(Get-WorkshopInstances -Only $Only | Where-Object { $_.State -eq "running" })
if ($instances.Count -eq 0) { throw "Calisan workshop instance'i bulunamadi." }

Wait-SsmOnline $instances

$sent = @()
foreach ($inst in $instances) {
    # exit 3010: SSM makineyi yeniden baslatir ve script'i tekrar calistirir.
    # Ikinci calismada hostname dogru oldugu icin wallpaper ayarlanip exit 0.
    $script = @"
# Disk AMI'den buyuk acildiysa C: bolumunu bos alana genislet
try {
    `$max = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
    if (`$max -gt (Get-Partition -DriveLetter C).Size + 1GB) { Resize-Partition -DriveLetter C -Size `$max; Write-Output "C: genisletildi" }
} catch { Write-Output "C: genisletilemedi: `$(`$_.Exception.Message)" }

# ----- Role gore masaustu arkaplani (kullanici hive'ina yazilir) -----
`$u   = '$WorkshopUser'
`$img = 'C:\WorkshopSetup\wallpapers\$($inst.Role).png'
if (Test-Path `$img) {
    try {
        `$sid  = (New-Object System.Security.Principal.NTAccount(`$u)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        `$hive = "Registry::HKEY_USERS\`$sid"; `$tmp = `$false
        if (-not (Test-Path `$hive)) { reg.exe load 'HKU\utd_tmp' "C:\Users\`$u\NTUSER.DAT" | Out-Null; `$hive = 'Registry::HKEY_USERS\utd_tmp'; `$tmp = `$true }
        Set-ItemProperty "`$hive\Control Panel\Desktop" -Name Wallpaper      -Value `$img
        Set-ItemProperty "`$hive\Control Panel\Desktop" -Name WallpaperStyle -Value '10'
        Set-ItemProperty "`$hive\Control Panel\Desktop" -Name TileWallpaper  -Value '0'
        if (`$tmp) { [gc]::Collect(); reg.exe unload 'HKU\utd_tmp' | Out-Null }
        Write-Output "Wallpaper ($($inst.Role)) ayarlandi"
    } catch { Write-Output "Wallpaper ayarlanamadi: `$(`$_.Exception.Message)" }
}

`$new = '$($inst.Host)'
if (`$env:COMPUTERNAME -eq `$new) { Write-Output "Hostname: `$new"; exit 0 }
Rename-Computer -NewName `$new -Force
Write-Output "Hostname `$new olarak degistirildi, yeniden baslatiliyor"
exit 3010
"@
    $sent += Send-SsmScript -InstanceIds @($inst.InstanceId) -Script $script -Comment "rename $($inst.Name)"
}

Write-Host "==> Hostname + wallpaper degisiklikleri bekleniyor (yeniden baslatma dahil)..." -ForegroundColor Cyan
Wait-SsmCommands -Sent $sent -Instances $instances | Out-Null
Write-Host "Siradaki adim: 04-install-agent.ps1 (agent sadece VICTIM makinelere kurulur)"
