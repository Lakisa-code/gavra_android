$headers = @{
    'apikey' = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppY3UiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTcyODU2NDMyNiwiZXhwIjoyMDQ0MTQwMzI2fQ.i2tgk-Xc0WQ0aHsR0MH0xGvAw_k6RQSF_8vj1vbWzKg'
    'Authorization' = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppY3UiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTcyODU2NDMyNiwiZXhwIjoyMDQ0MTQwMzI2fQ.i2tgk-Xc0WQ0aHsR0MH0xGvAw_k6RQSF_8vj1vbWzKg'
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/mesecni_putnici?select=*&je_placen=eq.true&vreme_placanja=gte.2025-10-20T00:00:00&vreme_placanja=lt.2025-10-21T00:00:00" -Method GET -Headers $headers
    
    Write-Host "�� MESEČNE KARTE NAPLAĆENE DANAS (20.10.2025):" -ForegroundColor Green
    Write-Host "Ukupno mesečnih karata: $($response.Count)" -ForegroundColor Yellow
    
    if ($response.Count -gt 0) {
        $response | ForEach-Object {
            Write-Host "- Putnik: $($_.putnik_ime), Vozač UUID: $($_.vozac), Iznos: $($_.iznos_placanja), Vreme: $($_.vreme_placanja)" -ForegroundColor White
        }
    } else {
        Write-Host "Nema mesečnih karata naplaćenih danas." -ForegroundColor Red
    }
} catch {
    Write-Host "Greška: $($_.Exception.Message)" -ForegroundColor Red
}
