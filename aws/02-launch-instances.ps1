# ---------------------------------------------------------------------------
# 02 - AMI'den katilimci makinelerini CIFT olarak acar
#
# Her pair icin bir VICTIM + bir ATTACKER acar:
#   UTD-VICTIM01 / UTD-ATTACKER01, UTD-VICTIM02 / UTD-ATTACKER02, ...
# Her instance Role (victim|attacker) ve Pair (01, 02, ...) tag'leriyle acilir;
# 05-pair-victim-ip.ps1 bu tag'lerle eslestirmeyi yapar.
#
# Ayni isimde calisan bir instance varsa onu atlar; script tekrar calistirilabilir.
# ---------------------------------------------------------------------------
. "$PSScriptRoot\common.ps1"
Assert-Configured @("SubnetId", "SecurityGroupId", "InstanceType", "InstanceProfile")

# AMI: config'te yoksa en yeni workshop AMI'si
if ($AmiId) {
    $latest = (Invoke-Aws @("ec2", "describe-images", "--image-ids", $AmiId)).Images | Select-Object -First 1
} else {
    $imgs = Invoke-Aws @("ec2", "describe-images", "--owners", "self",
        "--filters", "Name=tag:Workshop,Values=$WorkshopTag", "Name=state,Values=available")
    $latest = $imgs.Images | Sort-Object CreationDate -Descending | Select-Object -First 1
}
if (-not $latest) { throw "Workshop AMI'si bulunamadi. Once 01-create-ami.ps1 calistirin." }
$ami = $latest.ImageId
Write-Host "AMI: $ami ($($latest.Name))" -ForegroundColor Cyan

# Disk boyutu: VolumeSizeGiB AMI'deki diskten buyukse kok disk buyutulerek acilir
$blockFile = $null
if ($VolumeSizeGiB) {
    $root    = $latest.RootDeviceName
    $amiSize = ($latest.BlockDeviceMappings | Where-Object { $_.DeviceName -eq $root }).Ebs.VolumeSize
    if ([int]$VolumeSizeGiB -gt [int]$amiSize) {
        $blockFile = New-JsonArgFile @(@{ DeviceName = $root; Ebs = @{ VolumeSize = [int]$VolumeSizeGiB; VolumeType = "gp3"; DeleteOnTermination = $true } })
        Write-Host "Disk: $amiSize GiB -> $VolumeSizeGiB GiB" -ForegroundColor Cyan
    }
}

$existing   = @((Get-WorkshopInstances) | ForEach-Object { $_.Name })
$totalPairs = $PairCount + $SparePairs
$newIds     = @()

function New-Machine {
    param([string]$Name, [string]$Role, [string]$Pair, [string]$Spare)
    if ($existing -contains $Name) { Write-Host "  $Name zaten var, atlandi"; return }

    $tags = @(
        @{ ResourceType = "instance"; Tags = @(
            @{ Key = "Name";     Value = $Name },
            @{ Key = "Workshop"; Value = $WorkshopTag },
            @{ Key = "Role";     Value = $Role },
            @{ Key = "Pair";     Value = $Pair },
            @{ Key = "Spare";    Value = $Spare }) },
        @{ ResourceType = "volume"; Tags = @(
            @{ Key = "Name";     Value = $Name },
            @{ Key = "Workshop"; Value = $WorkshopTag }) }
    )
    $argList = @("ec2", "run-instances",
        "--image-id", $ami,
        "--instance-type", $InstanceType,
        "--count", "1",
        "--subnet-id", $SubnetId,
        "--security-group-ids", $SecurityGroupId,
        "--associate-public-ip-address",
        "--iam-instance-profile", "Name=$InstanceProfile",
        "--metadata-options", "HttpTokens=required,HttpEndpoint=enabled",
        "--tag-specifications", (New-JsonArgFile $tags))
    if ($KeyName)   { $argList += @("--key-name", $KeyName) }
    if ($blockFile) { $argList += @("--block-device-mappings", $blockFile) }

    # Yeni olusturulan IAM profile'in yayilmasi birkac saniye surebilir
    for ($try = 1; $try -le 4; $try++) {
        try { $res = Invoke-Aws $argList; break }
        catch {
            if ($try -lt 4 -and $_.Exception.Message -like "*Invalid IAM Instance Profile*") {
                Write-Host "  IAM profile henuz hazir degil, 15 sn sonra tekrar deneniyor..."
                Start-Sleep -Seconds 15
            } else { throw }
        }
    }
    $id = $res.Instances[0].InstanceId
    $script:newIds += $id
    Write-Host ("  {0} acildi: {1}{2}" -f $Name, $id, $(if ($Spare -eq "true") { " (yedek)" } else { "" })) -ForegroundColor Green
}

for ($i = 1; $i -le $totalPairs; $i++) {
    $pair  = "{0:D2}" -f $i
    $spare = if ($i -gt $PairCount) { "true" } else { "false" }
    New-Machine -Name ("{0}{1}" -f $VictimPrefix,   $pair) -Role "victim"   -Pair $pair -Spare $spare
    New-Machine -Name ("{0}{1}" -f $AttackerPrefix, $pair) -Role "attacker" -Pair $pair -Spare $spare
}

if ($newIds.Count -gt 0) {
    Write-Host "==> Instance'larin calismasi bekleniyor..." -ForegroundColor Cyan
    Invoke-Aws (@("ec2", "wait", "instance-running", "--instance-ids") + $newIds) | Out-Null
}

Get-WorkshopInstances | Format-Table Name, InstanceId, State, Role, Pair, PublicIp, Spare -AutoSize
Write-Host "Windows'un acilip SSM'e kaydolmasi 5-10 dakika surebilir."
Write-Host "Siradaki adim: 03-rename-hosts.ps1"
