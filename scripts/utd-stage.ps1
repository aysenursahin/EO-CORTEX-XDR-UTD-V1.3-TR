# ---------------------------------------------------------------------------
# utd-stage.ps1 - Base makineyi UTD lab'i icin hazirlar (AMI almadan ONCE)
#
# Bu script BASE makinede, $WorkshopUser (aes-user) ile acilmis YONETICI
# PowerShell'de calisir. Yaptigi her sey AMI ile tum katilimci makinelerine
# kopyalanir. Amac: katilimcinin zip indirme/parola/extract adimlarini ve
# "foo" parolasini tamamen ortadan kaldirmak.
#
# KRITIK SIRALAMA:
#   1) Once Defender exclusion + Defender/Firewall kapat   <-- bunlar extract'ten ONCE
#   2) Sonra zip'leri ac
# Aksi halde w_win.exe ve diger ornek binary'ler, AMI alinirken Defender
# tarafindan quarantine'e dusup klonlara BOZUK gider.
#
# Gereken dosyalar (bu klasorde ya da parametreyle verin):
#   - utd.zip            (torsque.com/utd.zip - parola: foo)
#   - x_test.zip         (parola: foo)  -> C:\x_test\{client,server}
#   - wallpapers\victim-backgroud.png, wallpapers\attacker-backgroud.png
#   - komutlar.txt       (repodaki surum)
#
# Kullanim (base makinede, yonetici PowerShell):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\utd-stage.ps1 -WorkshopUser aes-user
# ---------------------------------------------------------------------------
param(
    [string]$WorkshopUser = "aes-user",
    [string]$UtdZip       = "",   # bos ise bu klasorde utd.zip aranir, yoksa UtdZipUrl'den indirilir
    [string]$UtdZipUrl    = "http://www.torsque.com/utd.zip",
    [string]$XTestZip     = "",   # bos ise bu klasorde x_test.zip aranir
    [string]$ZipPassword  = "foo",
    [string]$WallpaperDir = "",   # bos ise bu klasordeki wallpapers\ kullanilir
    [string]$KomutlarFile = "",   # bos ise bu klasorde / ust klasorde komutlar.txt aranir
    [string]$ConsoleUrl   = "https://torsque.xdr.de.paloaltonetworks.com/dashboard",
    [string]$GuideUrl     = "https://torsque.xdr.de.paloaltonetworks.com/dashboard"
)
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-Local {
    param([string]$Given, [string[]]$Candidates)
    if ($Given -and (Test-Path $Given)) { return (Resolve-Path $Given).Path }
    foreach ($c in $Candidates) { if (Test-Path $c) { return (Resolve-Path $c).Path } }
    return $null
}

Write-Host "==> UTD base stage basliyor" -ForegroundColor Cyan

# --- 1a. IE ESC + Defender + Firewall kapat (lab'in kendi quick_config.ps1'i) ---
# Lab ortamidir; tek dedektor VICTIM'daki XDR agent olsun diye Defender kapatilir.
# Rehberdeki quick_config.ps1'in aynisi repoda custom-utd\ altinda; onu calistiririz.
Write-Host "==> quick_config.ps1 (Defender / Firewall / IE ESC)" -ForegroundColor Cyan
$quick = Resolve-Local $null @("$here\..\custom-utd\quick_config.ps1", "$here\custom-utd\quick_config.ps1")
if ($quick) {
    try { & $quick; Write-Host "    quick_config.ps1 calisti: $quick" }
    catch { Write-Host "    UYARI: quick_config.ps1 hata verdi: $($_.Exception.Message)" -ForegroundColor Yellow }
} else {
    Write-Host "    quick_config.ps1 bulunamadi, inline kapatma uygulaniyor" -ForegroundColor Yellow
    try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue } catch {}
    try { Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False } catch {}
    foreach ($k in @(
        'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}',
        'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}')) {
        if (Test-Path $k) { Set-ItemProperty $k -Name IsInstalled -Value 0 -ErrorAction SilentlyContinue }
    }
}

# --- 1b. Defender exclusion'lari EKLE (extract'ten ONCE) ---
Write-Host "==> Defender exclusion: C:\x_test ve stage klasoru" -ForegroundColor Cyan
$stageDir = "C:\WorkshopSetup"
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
foreach ($p in @("C:\x_test", $stageDir)) {
    try { Add-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue } catch {}
}

# --- 2. 7-Zip bul (parolali zip icin gerekli; Expand-Archive parola desteklemez) ---
$sevenZip = Resolve-Local $null @("C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe", "$stageDir\7zr.exe")
if (-not $sevenZip) {
    Write-Host "==> 7-Zip bulunamadi, 7zr.exe indiriliyor" -ForegroundColor Cyan
    $sevenZip = "$stageDir\7zr.exe"
    try { Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -OutFile $sevenZip -UseBasicParsing }
    catch { throw "7-Zip bulunamadi ve indirilemedi. 7-Zip'i elle kurup -SevenZip ile yolunu verin. ($($_.Exception.Message))" }
}
Write-Host "    7-Zip: $sevenZip"

function Expand-Protected {
    param([string]$Zip, [string]$Dest, [string]$Password)
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    & $sevenZip x "$Zip" "-o$Dest" "-p$Password" -aoa -y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Extract basarisiz ($Zip -> $Dest), 7-Zip kodu $LASTEXITCODE. Parolayi kontrol edin." }
}

# --- 3a. utd.zip -> stage klasorune ac ---
$utd = Resolve-Local $UtdZip @("$here\utd.zip", "$here\..\utd.zip")
if (-not $utd) {
    Write-Host "==> utd.zip indiriliyor: $UtdZipUrl" -ForegroundColor Cyan
    $utd = "$stageDir\utd.zip"
    Invoke-WebRequest -Uri $UtdZipUrl -OutFile $utd -UseBasicParsing
}
Write-Host "==> utd.zip aciliyor -> $stageDir\utd" -ForegroundColor Cyan
Expand-Protected -Zip $utd -Dest "$stageDir\utd" -Password $ZipPassword

# --- 3b. x_test.zip -> C:\x_test ---
# x_test.zip utd.zip icinden de cikmis olabilir; once parametre/klasor, sonra utd icerigi
$xtest = Resolve-Local $XTestZip @("$here\x_test.zip", "$stageDir\utd\x_test.zip")
if (-not $xtest) {
    $found = Get-ChildItem -Path "$stageDir\utd" -Recurse -Filter "x_test.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $xtest = $found.FullName }
}
if (-not $xtest) { throw "x_test.zip bulunamadi. -XTestZip ile yolunu verin (parola: $ZipPassword)." }
Write-Host "==> x_test.zip aciliyor -> C:\x_test" -ForegroundColor Cyan
Expand-Protected -Zip $xtest -Dest "C:\" -Password $ZipPassword
if (-not (Test-Path "C:\x_test\client") -or -not (Test-Path "C:\x_test\server")) {
    throw "C:\x_test\client veya server olusmadi. x_test.zip icerigini kontrol edin."
}

# --- 4. VICTIM tarafi: server\ud klasoru ---
New-Item -ItemType Directory -Force -Path "C:\x_test\server\ud" | Out-Null
Write-Host "==> C:\x_test\server\ud olusturuldu"

# --- 5. Wallpaper'lari AMI'ye tasinan yere kopyala (03-rename role gore ayarlar) ---
$wpSrc = if ($WallpaperDir) { $WallpaperDir } else { "$here\wallpapers" }
$wpDst = "$stageDir\wallpapers"
New-Item -ItemType Directory -Force -Path $wpDst | Out-Null
$map = @{ "victim-backgroud.png" = "victim.png"; "attacker-backgroud.png" = "attacker.png" }
foreach ($k in $map.Keys) {
    $s = Join-Path $wpSrc $k
    if (Test-Path $s) { Copy-Item $s (Join-Path $wpDst $map[$k]) -Force; Write-Host "    wallpaper: $($map[$k])" }
    else { Write-Host "    UYARI: $k bulunamadi ($wpSrc) - wallpaper atlandi" -ForegroundColor Yellow }
}

# --- 6. Masaustu: komutlar.txt, konsol kisayolu, lab rehberi kisayolu ---
$desk = "C:\Users\$WorkshopUser\Desktop"
New-Item -ItemType Directory -Force -Path $desk | Out-Null
$kom = Resolve-Local $KomutlarFile @("$here\..\komutlar.txt", "$here\komutlar.txt")
if ($kom) { Copy-Item $kom "$desk\komutlar.txt" -Force; Write-Host "==> komutlar.txt masaustune kopyalandi" }
else { Write-Host "UYARI: komutlar.txt bulunamadi, atlandi" -ForegroundColor Yellow }

[IO.File]::WriteAllText("$desk\XDR Konsol.url",      "[InternetShortcut]`r`nURL=$ConsoleUrl`r`n")
[IO.File]::WriteAllText("$desk\UTD Lab Rehberi.url", "[InternetShortcut]`r`nURL=$GuideUrl`r`n")
Write-Host "==> Masaustu kisayollari: XDR Konsol, UTD Lab Rehberi"

# Tarayici favorileri (Chrome/Edge yonetilen yer imleri)
$bm = @(
    @{ toplevel_name = 'UTD Workshop' },
    [ordered]@{ name = 'XDR Konsol';      url = $ConsoleUrl },
    [ordered]@{ name = 'UTD Lab Rehberi'; url = $GuideUrl }
)
$json = ConvertTo-Json -InputObject $bm -Compress
foreach ($key in @('HKLM:\SOFTWARE\Policies\Google\Chrome', 'HKLM:\SOFTWARE\Policies\Microsoft\Edge')) {
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name 'ManagedBookmarks'   -Value $json -Type String
    Set-ItemProperty -Path $key -Name 'BookmarkBarEnabled' -Value 1     -Type DWord
}

Write-Host ""
Write-Host "==> Kontrol listesi" -ForegroundColor Cyan
"{0,-34} {1}" -f "C:\x_test\client",            (Test-Path "C:\x_test\client")
"{0,-34} {1}" -f "C:\x_test\server\ud",         (Test-Path "C:\x_test\server\ud")
"{0,-34} {1}" -f "wallpapers\victim.png",       (Test-Path "$wpDst\victim.png")
"{0,-34} {1}" -f "wallpapers\attacker.png",     (Test-Path "$wpDst\attacker.png")
"{0,-34} {1}" -f "Desktop\komutlar.txt",        (Test-Path "$desk\komutlar.txt")
"{0,-34} {1}" -f "Defender realtime kapali",    ((Get-MpPreference).DisableRealtimeMonitoring)
Write-Host ""
Write-Host "Base makine UTD icin hazir. AGENT'I BASE MAKINEYE KURMAYIN." -ForegroundColor Green
Write-Host "Siradaki adim: aws\01-create-ami.ps1" -ForegroundColor Green
