# installers/

Bu klasore XDR konsolundan indirdiginiz Windows agent paketini
`UTD_XDR_AGENT__x64.msi` adiyla koyun. Dosya tenant'a ozeldir ve
`.gitignore` ile GitHub'dan dislanir. `aws/04-install-agent.ps1`
bu MSI'yi private S3 uzerinden yalnizca VICTIM makinelerine dagitir.
