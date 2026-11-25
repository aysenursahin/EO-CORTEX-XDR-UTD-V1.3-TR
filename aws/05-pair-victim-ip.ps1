# ---------------------------------------------------------------------------
# 05 - Her ATTACKER'a eslesen VICTIM'in private IP'sini masaustune yazar
#
# UTD lab'inin en cok hata yapilan adimi, attacker'da calistirilan
#   Client1.exe <VICTIM-IP> localhost
# komutundaki IP. Bu script, Pair tag'ine gore attacker<->victim eslestirmesini
# yapar ve her attacker makinesinin masaustune VICTIM makinesinin PRIVATE IP'si
# ile hostname'ini yazar. Katilimci IP arayip not almaz, hazir komutu yapistirir.
#
# ONEMLI: Client1.exe/RevShell PRIVATE IP kullanir. Stop/Start'ta private IP
# DEGISMEZ; bu yuzden bir gun once calistirip stop etseniz bile IP gecerli
# kalir. Yine de idempotent oldugundan workshop sabahi Start sonrasi bir kez
# daha calistirmak zarar vermez (makine terminate/relaunch olduysa kurtarir).
#
# Kullanim:
#   .\05-pair-victim-ip.ps1                        # tum attacker'lar
#   .\05-pair-victim-ip.ps1 -Only UTD-ATTACKER01    # tek attacker
# ---------------------------------------------------------------------------
param([string[]]$Only)
. "$PSScriptRoot\common.ps1"

$all       = @(Get-WorkshopInstances)
$victims   = @($all | Where-Object { $_.Role -eq "victim" })
$attackers = @($all | Where-Object { $_.Role -eq "attacker" -and $_.State -eq "running" })
if ($Only) { $attackers = @($attackers | Where-Object { $Only -contains $_.Name }) }
if ($attackers.Count -eq 0) { throw "Calisan ATTACKER instance'i bulunamadi." }

# Pair -> victim esleme tablosu
$victimOf = @{}
foreach ($v in $victims) { if ($v.Pair) { $victimOf[$v.Pair] = $v } }

# Eslestirmeyi once ekranda goster
$plan = foreach ($a in $attackers) {
    $v = $victimOf[$a.Pair]
    [pscustomobject]@{
        Attacker   = $a.Name
        Pair       = $a.Pair
        Victim     = if ($v) { $v.Host } else { "(EKSIK)" }
        VictimIp   = if ($v) { $v.PrivateIp } else { "" }
        InstanceId = $a.InstanceId
    }
}
$plan | Format-Table Attacker, Pair, Victim, VictimIp -AutoSize

$ready = @($plan | Where-Object { $_.VictimIp })
$missing = @($plan | Where-Object { -not $_.VictimIp })
if ($missing.Count -gt 0) {
    Write-Host "UYARI: Su attacker'larin esi bulunamadi veya victim IP'si yok: $(($missing | ForEach-Object { $_.Attacker }) -join ', ')" -ForegroundColor Yellow
}
if ($ready.Count -eq 0) { throw "Yazilacak eslesme yok." }

$targets = @($attackers | Where-Object { $p = $_; ($ready | Where-Object { $_.InstanceId -eq $p.InstanceId }) })
Wait-SsmOnline $targets

$sent = @()
foreach ($row in $ready) {
    $script = @"
`$u    = '$WorkshopUser'
`$desk = "C:\Users\`$u\Desktop"
New-Item -ItemType Directory -Force -Path `$desk | Out-Null
`$txt = @'
================================
  SENIN VICTIM MAKINEN
================================
Hostname : $($row.Victim)
IP       : $($row.VictimIp)

Hazir komutlar (kopyala-yapistir):

[Bolum 1] Initial access
cd C:\x_test\client
Client1.exe $($row.VictimIp) localhost

[Bolum 2] RevShell adiminda ATTACKER IP sorulur:
ipconfig | findstr IPv4
'@
Set-Content -Path "`$desk\VICTIM-BILGISI.txt" -Value `$txt -Encoding UTF8
Write-Output "VICTIM-BILGISI.txt yazildi: $($row.Victim) / $($row.VictimIp)"
"@
    $inst = $attackers | Where-Object { $_.InstanceId -eq $row.InstanceId }
    $sent += Send-SsmScript -InstanceIds @($row.InstanceId) -Script $script -Comment "pair-ip $($row.Attacker)" -ExecutionTimeoutSeconds 120
}

Write-Host "==> Victim IP bilgisi attacker masaustlerine yaziliyor: $($ready.Count) makine" -ForegroundColor Cyan
Wait-SsmCommands -Sent $sent -Instances $targets -TimeoutMinutes 10 | Out-Null
Write-Host "Siradaki adim: 06-check.ps1"
