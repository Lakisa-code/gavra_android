$apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"
$uri = "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/putovanja_istorija?select=putnik_ime,datum_putovanja,status,obrisan&order=datum_putovanja.desc&limit=30"
$headers = @{ apikey = $apikey }
$result = Invoke-RestMethod -Uri $uri -Headers $headers
Write-Host "PUTOVANJA_ISTORIJA (poslednjih 30):" -ForegroundColor Yellow
$result | ForEach-Object {
    Write-Host "  $($_.datum_putovanja) | $($_.putnik_ime) | status=$($_.status) | obrisan=$($_.obrisan)"
}
Write-Host "`nUkupno: $($result.Count)"
