# ---------------------------------------------------------------------------
# 07 - Katilimci makinelerini listeler ve participants.csv olusturur
#
# Her pair icin VICTIM ve ATTACKER makinesinin RDP adresi ve kullanici adi.
# Sifre sutununu doldurup katilimcilara dagitabilirsiniz.
# participants.csv .gitignore'da; GitHub'a yuklenmez.
# Not: Durdurulup yeniden baslatilan makinelerin PUBLIC IP'si (RDP adresi)
# degisir; makineleri actiktan sonra bu script'i tekrar calistirin. (Lab ici
# PRIVATE IP degismez, o yuzden 05-pair-victim-ip tekrari sart degildir.)
# ---------------------------------------------------------------------------
. "$PSScriptRoot\common.ps1"

$instances = @(Get-WorkshopInstances)
if ($instances.Count -eq 0) { throw "Workshop instance'i bulunamadi." }

$rows = foreach ($i in ($instances | Sort-Object Pair, Role)) {
    [pscustomobject]@{
        Pair       = $i.Pair
        Rol        = $i.Role
        Makine     = $i.Name
        RdpAdresi  = $i.PublicIp
        Kullanici  = $WorkshopUser
        Sifre      = ""
        Durum      = $i.State
        Yedek      = $(if ($i.Spare -eq "true") { "evet" } else { "" })
        InstanceId = $i.InstanceId
    }
}

$rows | Format-Table Pair, Rol, Makine, RdpAdresi, Durum, Yedek -AutoSize
$csv = Join-Path $PSScriptRoot "participants.csv"
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Host "Kaydedildi: $csv" -ForegroundColor Green
