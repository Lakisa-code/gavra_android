# QR KOD GENERATOR ZA GAVRA ANDROID
# Koristi PowerShell i online API za generiranje QR koda

param(
    [string]$Text = "https://github.com/bojanbc83/gavra_android/releases/latest",
    [string]$OutputFile = "gavra-android-qr.png",
    [int]$Size = 300
)

Write-Host "🚌 GAVRA ANDROID QR GENERATOR" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$urls = @(
    "https://github.com/bojanbc83/gavra_android/releases/latest",
    "https://github.com/bojanbc83/gavra_android/releases/latest/download/app-release.apk"
)

$descriptions = @(
    "NAJNOVIJA VERZIJA (GitHub Releases)",
    "DIREKTAN DOWNLOAD APK"
)

for ($i = 0; $i -lt $urls.Length; $i++) {
    $url = $urls[$i]
    $desc = $descriptions[$i]
    $filename = "gavra-qr-$($i+1).png"
    
    Write-Host "`n📱 Generiram: $desc" -ForegroundColor Green
    Write-Host "🔗 URL: $url" -ForegroundColor Yellow
    
    try {
        # Koristi Google Charts API za QR kod
        $encodedUrl = [System.Web.HttpUtility]::UrlEncode($url)
        $qrApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=${Size}x${Size}&data=$encodedUrl"
        
        Write-Host "⏳ Downloading QR kod..." -ForegroundColor Blue
        
        # Download QR kod
        Invoke-WebRequest -Uri $qrApiUrl -OutFile $filename -UseBasicParsing
        
        if (Test-Path $filename) {
            Write-Host "✅ QR kod kreiran: $filename" -ForegroundColor Green
            
            # Otvori sliku
            Start-Process $filename
        }
        else {
            Write-Host "❌ Greška pri kreiranju QR koda" -ForegroundColor Red
        }
        
    }
    catch {
        Write-Host "❌ Greška: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 1
}

Write-Host "`n🎯 ZAVRŠENO!" -ForegroundColor Cyan
Write-Host "📁 QR kodovi su sačuvani u trenutnom direktorijumu" -ForegroundColor White
Write-Host "📱 Podeli QR kodove vozačima za najnoviju verziju!" -ForegroundColor White

# Kreiranje HTML pregleda
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>🚌 Gavra Android QR Kodovi</title>
    <style>
        body { font-family: Arial; text-align: center; background: #f0f0f0; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
        .qr-item { margin: 30px 0; padding: 20px; border: 2px solid #333; border-radius: 10px; }
        .qr-item h3 { color: #333; margin-top: 0; }
        .qr-item img { max-width: 300px; }
        .url { font-family: monospace; background: #f5f5f5; padding: 10px; border-radius: 5px; word-break: break-all; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚌 Gavra Android - QR Kodovi</h1>
        <p><strong>Skeniraj QR kod za najnoviju verziju aplikacije!</strong></p>
        
        <div class="qr-item">
            <h3>🔄 NAJNOVIJA VERZIJA</h3>
            <img src="gavra-qr-1.png" alt="QR Kod za najnoviju verziju">
            <div class="url">https://github.com/bojanbc83/gavra_android/releases/latest</div>
            <p>Uvek vodi na najnoviju verziju - ne treba ažuriranje QR koda!</p>
        </div>
        
        <div class="qr-item">
            <h3>⬇️ DIREKTAN DOWNLOAD</h3>
            <img src="gavra-qr-2.png" alt="QR Kod za direktan download">
            <div class="url">https://github.com/bojanbc83/gavra_android/releases/latest/download/app-release.apk</div>
            <p>Direktno skida APK fajl bez browsing-a</p>
        </div>
        
        <div style="margin-top: 30px; padding: 15px; background: #e8f5e8; border-radius: 8px;">
            <h4>💡 Kako koristiti:</h4>
            <p>1. Printaj ili pošalji QR kod vozačima<br>
               2. Oni skeniraju bilo kojom camera app<br>
               3. Automatski download najnovije verzije! 🎯</p>
        </div>
    </div>
</body>
</html>
"@

$htmlContent | Out-File -FilePath "gavra-qr-preview.html" -Encoding UTF8
Start-Process "gavra-qr-preview.html"

Read-Host "`nPritisni ENTER za izlaz"