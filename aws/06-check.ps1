# ---------------------------------------------------------------------------
# 06 - Tum makinelerin UTD lab'ina hazir olup olmadigini kontrol eder
#
# Her makine icin: hostname, C:\x_test duzeni, komutlar.txt.
# VICTIM'lar icin ayrica XDR agent servisi ve server\ud klasoru.
# ATTACKER'lar icin masaustunde VICTIM-BILGISI.txt.
# Workshop sabahi da calistirin.
# ---------------------------------------------------------------------------
param([string[]]$Only)
. "$PSScriptRoot\common.ps1"

$instances = @(Get-WorkshopInstances -Only $Only | Where-Object { $_.State -eq "running" })
if ($instances.Count -eq 0) { throw "Calisan workshop instance'i bulunamadi." }

Wait-SsmOnline $instances

# Rol bilgisini SSM scriptine gecirmek icin makineleri role gore ayir
$sentAll = @()
foreach ($inst in $instances) {
    $isVictim = ($inst.Role -eq "victim")
    $script = @"
`$u   = '$WorkshopUser'
`$role = '$($inst.Role)'
`$xtest   = (Test-Path 'C:\x_test\client') -and (Test-Path 'C:\x_test\server')
`$komut   = Test-Path "C:\Users\`$u\Desktop\komutlar.txt"
`$ud      = Test-Path 'C:\x_test\server\ud'
`$victimInfo = Test-Path "C:\Users\`$u\Desktop\VICTIM-BILGISI.txt"
`$agent = 'n/a'
if (`$role -eq 'victim') {
    `$svc = Get-Service | Where-Object { `$_.DisplayName -like '$XdrServicePattern' }
    `$agent = if (`$svc) { "`$(`$svc.Status)" } else { 'YOK' }
}
Write-Output ("Role={0} | Host={1} | x_test={2} | komutlar={3} | ud={4} | agent={5} | victim-bilgisi={6}" -f `$role, `$env:COMPUTERNAME, `$xtest, `$komut, `$ud, `$agent, `$victimInfo)
`$ok = `$xtest -and `$komut
if (`$role -eq 'victim')   { `$ok = `$ok -and `$ud -and (`$agent -eq 'Running') }
if (`$role -eq 'attacker') { `$ok = `$ok -and `$victimInfo }
if (-not `$ok) { exit 1 }
"@
    $sentAll += Send-SsmScript -InstanceIds @($inst.InstanceId) -Script $script -Comment "utd check $($inst.Name)" -ExecutionTimeoutSeconds 300
}

Write-Host "==> Kontrol ediliyor: $($instances.Count) makine" -ForegroundColor Cyan
$results = @(Wait-SsmCommands -Sent $sentAll -Instances $instances -TimeoutMinutes 10)

$failed = @($results | Where-Object { $_.Status -ne "Success" })
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Sorunlu makineler: $(($failed | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor Red
} else {
    Write-Host "Tum makineler hazir." -ForegroundColor Green
}
