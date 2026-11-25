# ---------------------------------------------------------------------------
# EO Cortex XDR UTD Workshop - AWS ayarlari
#
# Bu dosyayi ayni klasore config.ps1 adiyla kopyalayip doldurun:
#     Copy-Item config.example.ps1 config.ps1
# config.ps1 .gitignore'da; GitHub'a yuklenmez.
# ---------------------------------------------------------------------------

# AWS bolgesi ve AWS CLI profili
$Region     = "eu-north-1"
$AwsProfile = ""   # CloudShell'de bos birakin; kendi PC'nizde profil adi (or. "default")

# Workshop kaynaklarini isaretleyen tag. Script'ler sadece bu tag'li
# instance'lara ve AMI'lere dokunur.
$WorkshopTag = "eo-utd-workshop"

# Katilimci makineleri CIFT acilir: her pair icin bir VICTIM + bir ATTACKER.
# UTD-VICTIM01 / UTD-ATTACKER01, UTD-VICTIM02 / UTD-ATTACKER02, ...
# (Windows hostname'i en fazla 15 karakter; UTD-ATTACKER01 = 14 karakter.)
$VictimPrefix   = "UTD-VICTIM"
$AttackerPrefix = "UTD-ATTACKER"
$PairCount      = 10   # Kac katilimci/cift. Her pair 2 makine acar.
$SparePairs     = 1    # Yedek cift sayisi

# Instance ayarlari
$InstanceType    = "t3.large"
$SubnetId        = "subnet-xxxxxxxx"   # Internete cikisi olan public subnet
$SecurityGroupId = "sg-xxxxxxxx"       # RDP (3389) salonun IP'sinden. Instance-arasi trafik (8000/8001/9999) 02-launch tarafindan otomatik acilir.
$VolumeSizeGiB   = 60                  # Disk boyutu (GiB). AMI'deki diskten buyukse klonlarda buyutulur
$KeyName         = ""                  # Opsiyonel; xdr-user AMI'den geldigi icin sart degil

# Base makine ve AMI
$BaseInstanceId = "i-xxxxxxxx"            # utd-stage.ps1'in calistigi base makine
$AmiName        = "eo-utd-workshop-base"  # Sonuna tarih eklenir
$AmiId          = ""                      # Bos birakilirsa en yeni workshop AMI'si kullanilir

# SSM icin IAM rolu (00-create-ssm-role.ps1 olusturur)
$RoleName        = "UtdWorkshopSSMRole"
$InstanceProfile = "UtdWorkshopSSMProfile"

# Katilimcilarin RDP ile baglandigi Windows kullanicisi
$WorkshopUser = "xdr-user"

# Cortex XDR agent servisinin Windows'taki goruntu adi (Get-Service DisplayName).
# Ilk victim makinesinde agent'i kurduktan sonra kontrol edip gerekirse duzeltin.
# Cortex XDR agent servisi genelde "Cortex XDR" / "CyveraService" adiyla gelir.
$XdrServicePattern = "*Cortex*"

# Agent MSI'nin yuklenecegi private S3 bucket. Bos birakilirsa
# eo-utd-workshop-<hesap-no>-<bolge> adiyla otomatik olusturulur.
$AgentMsiBucket = ""

# Lab rehberinin web adresi (masaustune kisayol + tarayici favorisi)
$LabGuideUrl = "https://eo-utd-workshop.onrender.com/"

# XDR konsol adresi (eslesen her makineye tarayici favorisi + masaustu kisayolu)
$XdrConsoleUrl = "https://torsque.xdr.de.paloaltonetworks.com/dashboard"

# Repo'nun raw adresi (06-update-komutlar / 05-pair-victim-ip buradan ceker)
$RepoRawBase = "https://raw.githubusercontent.com/aysenursahin/EO-CORTEX-XDR-UTD-V1.3-TR/main"
