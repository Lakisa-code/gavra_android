$apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"
$uri = "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/registrovani_putnici?broj_telefona=eq.0641162560&select=id,putnik_ime,broj_telefona,email"
$headers = @{ apikey = $apikey }
$result = Invoke-RestMethod -Uri $uri -Headers $headers
Write-Host "Putnici sa brojem 0641162560:"
$result | ForEach-Object { 
    Write-Host "ID: $($_.id) | Ime: $($_.putnik_ime) | Email: $($_.email)"
}
Write-Host ""
Write-Host "Ukupno: $($result.Count) putnika"
