# ---------------------------------------------------------------------------
# Cortex XDR agent kurulum komutu (SADECE VICTIM makinelere kurulur)
#
# 1. Bu dosyayi ayni klasore agent-install-command.ps1 adiyla kopyalayin.
# 2. XDR konsolunda Endpoints > Agent Installations ekranindan Windows
#    installer paketini (UTD_XDR_AGENT__x64.msi) indirin.
# 3. Indirdiginiz MSI'yi aws\installers\ klasorune UTD_XDR_AGENT__x64.msi
#    adiyla koyun (dosya tenant'a ozel oldugu icin .gitignore'da).
# 4. Portalin verdigi msiexec komutunu asagiya yapistirin. UTD agent
#    paketinde dagitim kimligi MSI'nin icinde gelir; cogu zaman komut
#    sadece "msiexec /i UTD_XDR_AGENT__x64.msi" seklindedir.
#
# 04-install-agent.ps1 MSI'yi private bir S3 bucket uzerinden dagitir ve
# /qn /norestart parametrelerini kendisi ekler.
#
# agent-install-command.ps1 .gitignore'da; GitHub'a yuklenmez.
# ---------------------------------------------------------------------------

# UTD agent paketinde dagitim kimligi MSI'nin icinde geldigi icin varsayilan
# komut asagidadir ve HAZIR birakilmistir. Ortaminiz farkli bir komut veriyorsa
# (ozel parametreler), bu satiri konsoldaki komutla degistirin.
msiexec /i UTD_XDR_AGENT__x64.msi
