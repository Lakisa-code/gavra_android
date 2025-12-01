Write-Host "=== AGC Setup Assistant ===" -ForegroundColor Green
Write-Host ""

$debugFingerprint = "9A9285455BB0B30A64BD9D6FB37DDA6C2A32756573C511C6ACBEB438931E261D"

Write-Host "Steps to complete:" -ForegroundColor Yellow
Write-Host "1. Click 'App information' in left sidebar"
Write-Host "2. Find 'Signing Certificate Fingerprint'"  
Write-Host "3. Click 'Add fingerprint'"
Write-Host "4. Paste: $debugFingerprint"
Write-Host "5. Click Save"
Write-Host ""

Set-Clipboard -Value $debugFingerprint
Write-Host "Certificate copied to clipboard!" -ForegroundColor Green
Write-Host ""
Write-Host "Now go to AGC Console and paste it!"