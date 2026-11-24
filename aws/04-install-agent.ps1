# ---------------------------------------------------------------------------
# 04 - Cortex XDR agent'ini SADECE VICTIM makinelerine kurar
#
# UTD lab'inda agent yalnizca VICTIM makinede calisir (attacker'da agent yok).
# Agent'i AMI'ye (base makineye) GOMMEYIN: klonlar ayni cihaz kimligini tasir
# ve konsolda tek endpoint gibi gorunur. Bu yuzden agent, klonlar acildiktan
# sonra her victim'a ayri ayri bu script ile kurulur.
#
# Kurulum komutu aws\agent-install-command.ps1 dosyasindan, MSI ise
# aws\installers\UTD_XDR_AGENT__x64.msi dosyasindan okunur. Ikisi de
# tenant'a ozel oldugu icin .gitignore'dadir.
#
# Once tek makinede deneyin:
#   .\04-install-agent.ps1 -Only UTD-VICTIM01
# Sonra tum victim'lara:
#   .\04-install-agent.ps1
# Agent zaten kurulu olan makineler atlanir.
# ---------------------------------------------------------------------------
param([string[]]$Only)
. "$PSScriptRoot\common.ps1"

$cmdFile = Join-Path $PSScriptRoot "agent-install-command.ps1"
if (-not (Test-Path $cmdFile)) {
    throw "agent-install-command.ps1 bulunamadi. agent-install-command.example.ps1'den olusturup XDR konsolundaki komutu yapistirin."
}
$installCmd = Get-Content $cmdFile -Raw
$cmdLine = @($installCmd -split "`r?`n" | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") }) -join " "
if (-not $cmdLine) { throw "agent-install-command.ps1 icinde calistirilacak bir komut yok." }

# ----- MSI'yi private S3 bucket'a yukle, presign linki olustur -----
$msiLocal = Join-Path (Join-Path $PSScriptRoot "installers") "UTD_XDR_AGENT__x64.msi"
if (-not (Test-Path $msiLocal)) {
    throw "aws\installers\UTD_XDR_AGENT__x64.msi bulunamadi. XDR konsolundan indirip bu klasore koyun."
}
$acct   = (Invoke-Aws @("sts", "get-caller-identity")).Account
$bucket = if ($AgentMsiBucket) { $AgentMsiBucket } else { "eo-utd-workshop-$acct-$Region" }
$exists = $true
try { Invoke-Aws @("s3api", "head-bucket", "--bucket", $bucket) | Out-Null } catch { $exists = $false }
if (-not $exists) {
    Write-Host "==> S3 bucket olusturuluyor: $bucket" -ForegroundColor Cyan
    $cb = @("s3api", "create-bucket", "--bucket", $bucket)
    if ($Region -ne "us-east-1") { $cb += @("--create-bucket-configuration", "LocationConstraint=$Region") }
    Invoke-Aws $cb | Out-Null
    Invoke-Aws @("s3api", "put-public-access-block", "--bucket", $bucket, "--public-access-block-configuration",
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true") | Out-Null
}
Write-Host "==> Agent MSI yukleniyor: s3://$bucket/UTD_XDR_AGENT__x64.msi" -ForegroundColor Cyan
Invoke-Aws @("s3api", "put-object", "--bucket", $bucket, "--key", "UTD_XDR_AGENT__x64.msi", "--body", $msiLocal) | Out-Null

$presignArgs = @("s3", "presign", "s3://$bucket/UTD_XDR_AGENT__x64.msi", "--expires-in", "7200", "--region", $Region)
if ($AwsProfile) { $presignArgs += @("--profile", $AwsProfile) }
$url = (& aws @presignArgs | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $url.StartsWith("https://")) { throw "Agent MSI icin indirme linki olusturulamadi." }

# msiexec parametrelerini ayikla, /i hedefini indirilen dosyaya cevir, sessiz kur
$msiArgs = $cmdLine
if ($msiArgs -match '(?i)^\s*msiexec(\.exe)?\s+(.+)$') { $msiArgs = $Matches[2].Trim() }
$msiArgs = $msiArgs -replace '(?i)/i\s+("[^"]+"|\S+)', '/i "C:\WorkshopSetup\UTD_XDR_AGENT__x64.msi"'
if ($msiArgs -notmatch '(?i)/q')         { $msiArgs += ' /qn' }
if ($msiArgs -notmatch '(?i)/norestart') { $msiArgs += ' /norestart' }
if ($msiArgs -notmatch '(?i)/l')         { $msiArgs += ' /l*v "C:\WorkshopSetup\agent-install.log"' }
Write-Host "msiexec $msiArgs" -ForegroundColor DarkGray

$installBlock = @'
New-Item -ItemType Directory -Force -Path 'C:\WorkshopSetup' | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri '__URL__' -OutFile 'C:\WorkshopSetup\UTD_XDR_AGENT__x64.msi' -UseBasicParsing
Write-Output "Agent MSI indirildi: $((Get-Item 'C:\WorkshopSetup\UTD_XDR_AGENT__x64.msi').Length) bayt"
$p = Start-Process -FilePath msiexec.exe -ArgumentList '__ARGS__' -Wait -PassThru
Write-Output "msiexec cikis kodu: $($p.ExitCode)"
if (@(0, 3010) -notcontains $p.ExitCode) {
    if (Test-Path 'C:\WorkshopSetup\agent-install.log') { Get-Content 'C:\WorkshopSetup\agent-install.log' -Tail 25 }
    exit 1
}
'@
$installBlock = $installBlock.Replace('__URL__', $url).Replace('__ARGS__', $msiArgs.Replace("'", "''"))

# ----- SADECE VICTIM makineler -----
$instances = @(Get-WorkshopInstances -Only $Only -Role victim | Where-Object { $_.State -eq "running" })
if ($instances.Count -eq 0) { throw "Calisan VICTIM instance'i bulunamadi (agent yalnizca victim'lara kurulur)." }

Wait-SsmOnline $instances

$script = @"
if (`$env:COMPUTERNAME -notlike '$VictimPrefix*') {
    Write-Output "HATA: Bu makine VICTIM degil (`$env:COMPUTERNAME). Agent yalnizca victim'lara kurulur."
    exit 1
}
`$svc = Get-Service | Where-Object { `$_.DisplayName -like '$XdrServicePattern' }
if (`$svc) { Write-Output "Agent zaten kurulu: `$(`$svc.DisplayName) [`$(`$svc.Status)]"; exit 0 }

# ----- XDR agent kurulumu -----
$installBlock
# ----- Kurulum sonu -----

Start-Sleep -Seconds 20
`$svc = Get-Service | Where-Object { `$_.DisplayName -like '$XdrServicePattern' }
if (`$svc) { Write-Output "Agent kuruldu: `$(`$svc.DisplayName) [`$(`$svc.Status)]"; exit 0 }
Write-Output "UYARI: Kurulum calisti ama '$XdrServicePattern' adli servis bulunamadi."
Write-Output "Servis adini Get-Service ile kontrol edip config.ps1'deki XdrServicePattern'i duzeltin."
exit 1
"@

Write-Host "==> XDR agent kuruluyor: $($instances.Count) VICTIM makine" -ForegroundColor Cyan
$sent = Send-SsmScript -InstanceIds @($instances | ForEach-Object { $_.InstanceId }) -Script $script -Comment "xdr agent install"
Wait-SsmCommands -Sent $sent -Instances $instances | Out-Null
Write-Host "Not: Konsolda endpoint'lere UTD tag'i + Report policy atamayi unutmayin (tenant tarafi, bir kez)."
Write-Host "Siradaki adim: 05-pair-victim-ip.ps1"
