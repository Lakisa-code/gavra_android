$apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"
$uri = "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/pin_zahtevi?select=*"
$headers = @{ apikey = $apikey }
try {
    $result = Invoke-RestMethod -Uri $uri -Headers $headers
    Write-Host "PIN zahtevi u bazi:"
    if ($result.Count -eq 0) {
        Write-Host "  (nema zahteva)"
    } else {
        $result | ForEach-Object { 
            Write-Host "ID: $($_.id) | Putnik: $($_.putnik_id) | Status: $($_.status)"
        }
    }
    Write-Host ""
    Write-Host "Ukupno: $($result.Count) zahteva"
} catch {
    Write-Host "GRESKA: $_"
    Write-Host "Tabela pin_zahtevi mozda ne postoji!"
}
