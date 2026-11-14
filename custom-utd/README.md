# custom-utd/

UTD lab'inin kendi PowerShell dosyalari (rehberdeki "Custom UTD Files" ile birebir).
Buradakiler **verbatim** tutulur; davranislari rehberle eslesmeli diye degistirilmez.

| Dosya | Ne yapar | Lab'da ne zaman |
| --- | --- | --- |
| `quick_config.ps1` | Firewall + IE ESC + Defender real-time ve sample submission kapatir | Readiness. `scripts/utd-stage.ps1` base makinede bunu calistirir. |
| `downloader.ps1` | `torsque.com/7zip.exe`'yi `C:\7zip.exe`'ye indirir | Bolum 2. Katilimci index.html portalindan VICTIM'a yukler. |
| `persistency.ps1` | "Download 7-Zip Task" scheduled task'i + startup kisayolu + LowRiskFileTypes | Bolum 2. Katilimci portaldan yukleyip reverse shell'den calistirir. |

> **Not (davranisi degistirmedim):** `persistency.ps1` icindeki scheduled task
> `C:\x_test\server\ud\downlaoder.ps1` yolunu kullaniyor ("downloader" degil,
> **downlaoder** yazim hatasi). Rehberdeki orijinal dosyada da boyle. Task'in
> downloader'i gercekten tetiklemesini istiyorsaniz ya bu yazimi `downloader.ps1`
> yapin ya da yuklenen dosyayi ayni (hatali) adla birakin. Workshop sadece task'in
> OLUSTUGUNU gosterdigi icin (avlama hedefi) bu haliyle de calisir.

`downloader.ps1` ve `persistency.ps1` katilimcinin **lab sirasinda portaldan yukledigi**
payload'lardir; base makinede `server\ud` altina ONCEDEN KONMAZ (yoksa upload demosu
atlanmis olur). Buradaki kopyalar surum kontrolu ve utd.zip icerigini dogrulama icindir.
