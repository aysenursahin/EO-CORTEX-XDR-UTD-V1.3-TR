# Kurulum — adım adım (CloudShell)

Sıfırdan: SSM rolü → base makine → base hazırlık → AMI → çiftleri aç → agent → victim IP → kontrol.
Her şey **eu-north-1**'de (CloudShell, base makine, AMI aynı bölgede).

---

## 0. CloudShell'de repoyu klonla

```bash
cd ~
git clone https://github.com/aysenursahin/EO-CORTEX-XDR-UTD-V1.3-TR.git
cd EO-CORTEX-XDR-UTD-V1.3-TR/aws
ls
```

`ls` çıktısında `config.example.ps1`, `00-create-ssm-role.ps1` … görünmeli.

```bash
cp config.example.ps1 config.ps1
cp agent-install-command.example.ps1 agent-install-command.ps1
```

`config.ps1`'i aç (`nano config.ps1`), en azından `Region` (eu-north-1, zaten dolu) dışında
`SubnetId`, `SecurityGroupId`'yi şimdilik boş bırakabilirsin — base makineyi açınca dolduracağız.

---

## 1. SSM rolünü oluştur (makine AÇMADAN önce)

```bash
pwsh ./00-create-ssm-role.ps1
```

Bu komut sadece IAM rolü/instance profile (`UtdWorkshopSSMProfile`) oluşturur, makine açmaz.
Base makineyi açarken bu profili ona bağlayacağız.

---

## 2. Base makineyi aç (AWS Console → EC2 → Launch instance)

- **AMI:** Windows Server 2022 Base
- **Instance type:** `t3.large`
- **Disk:** 60 GiB gp3
- **Auto-assign public IP:** Enable
- **Security Group:** RDP (3389) sadece **senin IP'n** (My IP)
- **IAM instance profile:** `UtdWorkshopSSMProfile`
- **Region:** eu-north-1

Açtıktan sonra **Instance ID**'yi (`i-xxxxxxxx`) not al.

`config.ps1`'i güncelle:
```powershell
$BaseInstanceId  = "i-xxxxxxxx"   # base makine
$SubnetId        = "subnet-xxxxxxxx"
$SecurityGroupId = "sg-xxxxxxxx"
```

---

## 3. Base makineye bağlan ve kullanıcıyı aç

RDP ile Administrator bağlan, yönetici bir hesap aç ve onunla tekrar bağlan:

```powershell
net user aes-user Password123! /add
net localgroup administrators aes-user /add
```

> `aes-user` = `config.ps1`'deki `$WorkshopUser`. Başka ad kullanacaksan ikisini de değiştir.

---

## 4. Base'e dosyaları koy (aes-user ile RDP'de)

- GitHub → **Code → Download ZIP** ile repoyu indir, aç.
- `x_test.zip`'i `scripts\` klasörüne koy. (`utd.zip`'i stage script torsque'tan kendi indirir;
  elinde varsa onu da `scripts\` altına koy.)
- `victim-backgroud.png` + `attacker-backgroud.png`'yi `scripts\wallpapers\` altına koy.
  (Yoksa stage uyarı verip atlar, kritik değil.)

---

## 5. Base'i hazırla (aes-user, YÖNETİCİ PowerShell)

```powershell
cd <repo>\scripts
Set-ExecutionPolicy Bypass -Scope Process -Force
.\utd-stage.ps1 -WorkshopUser aes-user
```

Script: quick_config'i çalıştırır (Defender/Firewall/IE ESC kapatır), **önce** `C:\x_test` için
exclusion ekler **sonra** zip'leri açar, `server\ud`'yi, wallpaper'ları, `komutlar.txt` ve
kısayolları koyar. Sonda kontrol listesinde satırlar **True** olmalı.

### ⚠️ Agent'ı base'e KURMA
XDR agent'ı bu makineye kurma — klonlara SSM ile sonra kurulacak (adım 7).

---

## 6. AMI'yi al (CloudShell)

```bash
cd ~/EO-CORTEX-XDR-UTD-V1.3-TR/aws
pwsh ./01-create-ami.ps1
```

Önce base'i kontrol eder (x_test açık mı, `ud` var mı, agent kurulu **değil** mi). Sorun yoksa
`evet` yazıp onayla. AMI hazır olunca ID'yi verir (base makine bu sırada yeniden başlar).

---

## 7. Çiftleri aç, hazırla, eşleştir (CloudShell)

Önce MSI'yi CloudShell'e yükle (sağ üst **Actions → Upload file**), sonra yerine taşı:
```bash
mkdir -p installers
mv ~/UTD_XDR_AGENT__x64.msi installers/
# agent-install-command.ps1'e XDR konsolundaki msiexec komutunu yapıştır
```

```bash
pwsh ./02-launch-instances.ps1     # UTD-VICTIM01 / UTD-ATTACKER01 ...
pwsh ./03-rename-hosts.ps1         # hostname + role wallpaper
pwsh ./04-install-agent.ps1        # agent SADECE victim'lara (S3 üzerinden)
pwsh ./05-pair-victim-ip.ps1       # victim IP -> attacker masaüstü
```

> İlk denemede `config.ps1`'de `$PairCount = 1` yapıp pilot çalış; sorunsuzsa sayıyı artırıp
> 02–05'i tekrar çalıştır (var olan makineler atlanır).

---

## 8. Kontrol ve liste

```bash
pwsh ./06-check.ps1
pwsh ./07-list-instances.ps1       # participants.csv (RDP adresleri)
```

---

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

---

## Yerelde kalan / commit edilmeyen dosyalar (`.gitignore`)

`config.ps1`, `agent-install-command.ps1`, `participants.csv`, `aws/installers/*.msi`,
`scripts/utd.zip`, `scripts/x_test.zip`. Bunlar GitHub'a gitmez; her CloudShell oturumunda
(veya base makinede) yerleştirilir.
