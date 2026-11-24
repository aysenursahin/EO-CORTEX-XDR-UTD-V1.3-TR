# EO Cortex XDR UTD Workshop Lab (V1.3-TR)

Cortex XDR **UTD – Attack & Detect** threat hunting workshop'u için lab makinelerini hazırlayan script'ler. Katılımcıların zip indirme, "foo" parolası, IP not alma gibi hata yapılan hazırlık adımlarını ortadan kaldırıp doğrudan saldırı + avlama senaryosuna geçmesini hedefler.

Akış AES workshop iskeletinin aynısıdır, iki farkla:

1. Makineler **çift** açılır: her katılımcı için bir **VICTIM** + bir **ATTACKER**. XDR agent **yalnız VICTIM'da** çalışır.
2. İşin yarısı **konsol tarafıdır** (Query Builder, BIOC, Causality) — bunlar image'e girmez; kısayol ve cheat-sheet ile hızlandırılır.

Tek bir **base makine** hazırlanır, ondan **AMI** alınır, AMI'den katılımcı sayısı kadar **çift** açılır, XDR agent sadece victim'lara **SSM Run Command** ile kurulur. Hiçbir makineye tek tek RDP yapmanız gerekmez.

## Repo içeriği

| Dosya | Ne yapar | Nerede çalışır |
| --- | --- | --- |
| `scripts/utd-stage.ps1` | Base makineyi UTD için hazırlar: `quick_config.ps1`'i çalıştırır, `C:\x_test` için exclusion ekler, zip'leri **doğru sırada** açar, `server\ud` klasörünü, wallpaper'ları, `komutlar.txt` ve kısayolları yerleştirir | Base makine |
| `custom-utd/` | Lab'ın kendi PowerShell dosyaları (`quick_config.ps1`, `downloader.ps1`, `persistency.ps1`) — verbatim | Base / portal upload |
| `komutlar.txt` | Katılımcı masaüstündeki hazır komut/sorgu listesi | Base makine (stage kopyalar) |
| `site/index.html` | Lab rehberinin web sürümü: yan menü, kopyalanabilir komutlar, bölüm ilerleme takibi; telefonda da çalışır | Render (statik site) |
| `aws/00-create-ssm-role.ps1` | SSM için IAM rolü ve instance profile | CloudShell / eğitmen PC |
| `aws/01-create-ami.ps1` | Base makineden AMI alır (önce UTD hazırlık kontrolü yapar) | CloudShell / eğitmen PC |
| `aws/02-launch-instances.ps1` | AMI'den `UTD-VICTIM01`/`UTD-ATTACKER01`… **çiftlerini** açar | CloudShell / eğitmen PC |
| `aws/03-rename-hosts.ps1` | Hostname'leri çevirir + role göre masaüstü arkaplanını ayarlar | CloudShell / eğitmen PC |
| `aws/04-install-agent.ps1` | Cortex XDR agent'ını **sadece VICTIM** makinelere kurar | CloudShell / eğitmen PC |
| `aws/05-pair-victim-ip.ps1` | Her ATTACKER'a **eşleşen VICTIM'ın private IP'sini** masaüstüne yazar | CloudShell / eğitmen PC |
| `aws/06-check.ps1` | Tüm makinelerin hazır olduğunu kontrol eder (role göre) | CloudShell / eğitmen PC |
| `aws/07-list-instances.ps1` | Katılımcı listesini (`participants.csv`) çıkarır | CloudShell / eğitmen PC |
| `aws/08-power.ps1` | Makineleri başlatır / durdurur | CloudShell / eğitmen PC |
| `aws/99-cleanup.ps1` | Workshop sonrası makineleri (ve istenirse AMI'yi) siler | CloudShell / eğitmen PC |

## Lab rehberi (web)

Katılımcı rehberi `site/` altında tek dosyalık statik sitedir. Yayınlamak için [Render](https://render.com) → **New → Blueprint** → bu repoyu bağlayın → **Apply**; `render.yaml` siteyi `site/` klasöründen yayınlar ve adres `https://eo-utd-workshop.onrender.com/` biçiminde olur. `main`'e her push'ta otomatik güncellenir. Adresi `config.ps1`'deki `LabGuideUrl`/`XdrConsoleUrl` ve `utd-stage.ps1`'e verin ki masaüstü kısayolu ve tarayıcı favorisi doğru yere baksın.

## Neyi nereye koyuyoruz

| Katman | İçerik |
| --- | --- |
| **Image'e göm** (AMI) | `C:\x_test\{client,server}` açılmış hali, `server\ud`, wallpaper'lar, `komutlar.txt`, konsol/rehber kısayolları, Defender/Firewall kapalı |
| **Provisioning'de** (klonlar açılınca) | hostname, role göre wallpaper (03), XDR agent sadece victim'a (04), victim IP → attacker masaüstü (05) |
| **Image'e KOYMA** | **XDR agent** (klonlar aynı cihaz kimliğini taşır), **çalıştırılmış saldırının kendisi** (w_win, reverse shell, net user, malware indirme, hash değiştirme, steganografi — bunlar avlanacak telemetriyi üretir), **malware1.exe'nin önceden indirilmesi** (Bölüm 6 "nereden indi" avı canlı iniş ister) |
| **Tenant tarafı** (bir kez, elle) | UTD endpoint tag'i + Report/BIOC policy |

## ⚠️ Kritik sıralama (build-order)

`utd-stage.ps1` bunu sizin için doğru sırada yapar, ama elle müdahale ederseniz dikkat:

**Önce** Defender'ı kapat + `C:\x_test` için path exclusion ekle, **sonra** zip'leri aç. Aksi halde `w_win.exe` ve diğer örnek binary'ler AMI alınırken Defender tarafından quarantine'e düşer ve klonlara **bozuk** gider.

## VICTIM IP otomasyonu (neden güvenli)

Attacker'ın `Client1.exe <IP> localhost` için kullandığı IP **private IP**'dir ve stop/start'ta **değişmez**. Yani makineleri bir gün önce oluşturup `08-power -Stop` ile durdursanız, sabah `Start` etseniz bile `05-pair-victim-ip.ps1`'in attacker masaüstüne yazdığı IP geçerli kalır. Değişen tek şey **public IP** (RDP adresi) — onu da `07-list-instances.ps1` sabah yenileyerek çözer. `05`'i sabah bir kez daha çalıştırmak zarar vermez (idempotent); yanlışlıkla terminate/relaunch olmuş bir makine olursa kurtarır.

---

## Kurulum (adım adım, CloudShell)

Her şey **eu-north-1**'de olmalı (CloudShell, base makine, AMI aynı bölgede). CloudShell'de `pwsh` ve `aws` CLI hazır gelir.

### 0. Repoyu klonla

```bash
cd ~
git clone https://github.com/aysenursahin/EO-CORTEX-XDR-UTD-V1.3-TR.git
cd EO-CORTEX-XDR-UTD-V1.3-TR/aws
cp config.example.ps1 config.ps1
cp agent-install-command.example.ps1 agent-install-command.ps1
```

`config.ps1`'de `Region` zaten `eu-north-1`. `SubnetId`/`SecurityGroupId`/`BaseInstanceId`'yi base makineyi açınca dolduracağız.

### 1. SSM rolünü oluştur (makine AÇMADAN önce)

```bash
pwsh ./00-create-ssm-role.ps1
```

Sadece IAM instance profile (`UtdWorkshopSSMProfile`) oluşturur. Base makineyi bu profille açacağız.

### 2. Base makineyi aç (AWS Console → EC2 → Launch instance)

Windows Server 2022 Base · `t3.large` · 60 GiB gp3 · public IP enable · RDP (3389) **My IP** · IAM instance profile **`UtdWorkshopSSMProfile`**. Instance ID'yi (`i-xxxxxxxx`) `config.ps1`'e yaz (`BaseInstanceId`, `SubnetId`, `SecurityGroupId`).

### 3. Base'e bağlan, `xdr-user` oluştur

RDP (Administrator) → `net user xdr-user Password123! /add` + `net localgroup administrators xdr-user /add` → `xdr-user` ile tekrar bağlan. (`xdr-user` = `config.ps1`'deki `$WorkshopUser`.)

### 4. Base'e dosyaları koy

GitHub → **Code → Download ZIP**. `x_test.zip`'i `scripts\` altına, wallpaper'ları `scripts\wallpapers\` altına koy. (`utd.zip`'i stage script torsque'tan kendi indirir.)

### 5. Base'i hazırla (`xdr-user`, yönetici PowerShell)

```powershell
cd <repo>\scripts
Set-ExecutionPolicy Bypass -Scope Process -Force
.\utd-stage.ps1 -WorkshopUser xdr-user
```

Kontrol listesinde satırlar `True` olmalı. **XDR agent'ı base makineye KURMAYIN.**

### 6. AMI al (CloudShell)

```bash
pwsh ./01-create-ami.ps1       # base'i kontrol eder, agent kuruluysa durur; 'evet' ile onayla
```

### 7. Çiftleri aç, hazırla, eşleştir

MSI'yi CloudShell'e yükle (**Actions → Upload file**), yerine taşı, sonra:

```bash
mkdir -p installers && mv ~/UTD_XDR_AGENT__x64.msi installers/
# agent-install-command.ps1'e XDR konsolundaki msiexec komutunu yapıştır
pwsh ./02-launch-instances.ps1     # UTD-VICTIM01 / UTD-ATTACKER01 ...
pwsh ./03-rename-hosts.ps1         # hostname + role wallpaper
pwsh ./04-install-agent.ps1        # agent SADECE victim'lara (S3 üzerinden)
pwsh ./05-pair-victim-ip.ps1       # victim IP -> attacker masaüstü
```

Önce `config.ps1`'de `$PairCount = 1` ile pilot yap; sorunsuzsa artırıp 02–05'i tekrar çalıştır (var olan makineler atlanır).

### 8. Kontrol ve liste

```bash
pwsh ./06-check.ps1
pwsh ./07-list-instances.ps1       # participants.csv (RDP adresleri)
```

## Workshop günü

```bash
pwsh ./08-power.ps1 -Action Start
pwsh ./07-list-instances.ps1       # public (RDP) IP'leri yenile
pwsh ./05-pair-victim-ip.ps1       # garanti (private IP değişmez)
pwsh ./06-check.ps1
```

## Workshop sonrası

```bash
pwsh ./99-cleanup.ps1              # makineleri siler
pwsh ./99-cleanup.ps1 -DeleteAmi   # AMI + snapshot'ları da siler
```

## Bu repoda olmayanlar

Repo public'tir. `aws/config.ps1`, `aws/agent-install-command.ps1`, `aws/participants.csv`, `aws/installers/*.msi` ve lab zip'leri (`utd.zip`, `x_test.zip`) yereldir ve `.gitignore` ile dışarıda tutulur.
