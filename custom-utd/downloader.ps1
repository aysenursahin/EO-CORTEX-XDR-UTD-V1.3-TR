$downloadUrl = "http://www.torsque.com/7zip.exe"
$downloadPath = "C:\7zip.exe"

# Download 7-Zip installer
Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
