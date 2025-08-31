# Convert downloaded P12 to Base64
# Place the downloaded P12 file in this directory and run this script

param(
    [Parameter(Mandatory=$true)]
    [string]$P12FilePath
)

if (-not (Test-Path $P12FilePath)) {
    Write-Host "❌ P12 file not found: $P12FilePath" -ForegroundColor Red
    exit 1
}

Write-Host "🔄 Converting P12 to Base64..." -ForegroundColor Yellow

# Read P12 file and convert to Base64
$p12Bytes = [System.IO.File]::ReadAllBytes($P12FilePath)
$p12Base64 = [System.Convert]::ToBase64String($p12Bytes)

# Save Base64 to file
$outputFile = "certificate_p12_base64.txt"
$p12Base64 | Out-File $outputFile -Encoding ASCII

Write-Host "✅ Created $outputFile" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Now update GitHub Secret:" -ForegroundColor Yellow
Write-Host "IOS_CERTIFICATE_BASE64 = content from $outputFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔑 Also add private key as separate secret:" -ForegroundColor Yellow

# Convert private key to Base64 too
if (Test-Path "gavra_ios_private.key") {
    $keyBytes = [System.IO.File]::ReadAllBytes("gavra_ios_private.key")
    $keyBase64 = [System.Convert]::ToBase64String($keyBytes)
    $keyBase64 | Out-File "private_key_base64.txt" -Encoding ASCII
    Write-Host "IOS_PRIVATE_KEY_BASE64 = content from private_key_base64.txt" -ForegroundColor Cyan
}
