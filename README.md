# EO Cortex XDR UTD Workshop Lab (V1.3-TR)

Cortex XDR **UTD – Attack & Detect** threat hunting workshop'u için lab makinelerini hazırlayan script'ler. Katılımcıların zip indirme, "foo" parolası, IP not alma gibi hata yapılan hazırlık adımlarını ortadan kaldırıp doğrudan saldırı + avlama senaryosuna geçmesini hedefler.

Akış AES workshop iskeletinin aynısıdır, iki farkla:

1. Makineler **çift** açılır: her katılımcı için bir **VICTIM** + bir **ATTACKER**. XDR agent **yalnız VICTIM'da** çalışır.
2. İşin yarısı **konsol tarafıdır** (Query Builder, BIOC, Causality) — bunlar image'e girmez; kısayol ve cheat-sheet ile hızlandırılır.

Tek bir **base makine** hazırlanır, ondan **AMI** alınır, AMI'den katılımcı sayısı kadar **çift** açılır, XDR agent sadece victim'lara **SSM Run Command** ile kurulur. Hiçbir makineye tek tek RDP yapmanız gerekmez.

## Repo içeriği

| Dosya | Ne yapar | Nerede çalışır |
| --- | --- | --- |
| `scripts/utd-stage.ps1` | Base makineyi UTD için hazırlar: Defender/Firewall kapatır, `C:\x_test` için exclusion ekler, zip'leri **doğru sırada** açar, `server\ud` klasörünü, wallpaper'ları, `komutlar.txt` ve kısayolları yerleştirir | Base makine |
| `komutlar.txt` | Katılımcı masaüstündeki hazır komut/sorgu listesi | Base makine (stage kopyalar) |
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

## 1. Base makineyi oluştur (AWS konsolu)

EC2 → **Launch instance**: Windows Server 2022 Base, `t3.large`, 60 GiB gp3, public IP enable, RDP kuralı **My IP**, IAM instance profile `UtdWorkshopSSMProfile` (yoksa önce `aws/00-create-ssm-role.ps1`). Katılımcı hesabını açın (`aes-user`, admin) ve bu kullanıcıyla bağlanın.

## 2. Base makineyi hazırla (`aes-user`, yönetici PowerShell)

Repoyu indirin, `scripts/` altına **utd.zip** ve **x_test.zip**'i, `scripts/wallpapers/` altına arkaplanları koyun, sonra:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\utd-stage.ps1 -WorkshopUser aes-user
```

Script sonunda kontrol listesinde tüm satırlar `True` olmalı. **XDR agent'ı base makineye kurmayın.**

## 3. AWS ayarlarını yap (base makinede DEĞİL)

```powershell
cp aws/config.example.ps1 aws/config.ps1
cp aws/agent-install-command.example.ps1 aws/agent-install-command.ps1
# config.ps1'i doldurun (BaseInstanceId, SubnetId, SecurityGroupId, PairCount...)
# agent-install-command.ps1'e XDR konsolundaki msiexec komutunu yapıştırın
# aws/installers/ altına UTD_XDR_AGENT__x64.msi koyun
./00-create-ssm-role.ps1
```

## 4. AMI al

```powershell
./01-create-ami.ps1
```

## 5. Çiftleri aç, hazırla, eşleştir

```powershell
./02-launch-instances.ps1     # VICTIM01/ATTACKER01, ...
./03-rename-hosts.ps1         # hostname + role göre wallpaper
./04-install-agent.ps1        # agent SADECE victim'lara
./05-pair-victim-ip.ps1       # victim IP -> attacker masaüstü
```

Önce `PairCount=1` ile pilot yapın; sorunsuzsa sayıyı artırıp 02–05'i tekrar çalıştırın (var olan makineler atlanır).

## 6. Kontrol ve liste

```powershell
./06-check.ps1
./07-list-instances.ps1
```

## Workshop günü

```powershell
./08-power.ps1 -Action Start
./07-list-instances.ps1       # RDP (public) IP'leri yenile
./05-pair-victim-ip.ps1       # garanti (private IP değişmez ama idempotent)
./06-check.ps1
```

## Workshop sonrası

```powershell
./99-cleanup.ps1              # makineleri siler
./99-cleanup.ps1 -DeleteAmi   # AMI + snapshot'ları da siler
```

## Bu repoda olmayanlar

Repo public'tir. `aws/config.ps1`, `aws/agent-install-command.ps1`, `aws/participants.csv`, `installers/*.msi` ve lab zip'leri (`utd.zip`, `x_test.zip`) yereldir ve `.gitignore` ile dışarıda tutulur.
