$apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"
$baseUrl = "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1"
$headers = @{ apikey = $apikey }
$danas = (Get-Date).ToString("yyyy-MM-dd")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ANALIZA STANJA PUTNIKA U BAZI" -ForegroundColor Cyan
Write-Host "Datum: $danas" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. registrovani_putnici
Write-Host "`n1. REGISTROVANI_PUTNICI (mesecni)" -ForegroundColor Yellow
$uri = "$baseUrl/registrovani_putnici?select=id,putnik_ime,status,aktivan,pokupljen,cena,vreme_pokupljenja,vozac_id&limit=10"
$result = Invoke-RestMethod -Uri $uri -Headers $headers
$result | ForEach-Object { 
    Write-Host "  $($_.putnik_ime): status=$($_.status), aktivan=$($_.aktivan), pokupljen=$($_.pokupljen), cena=$($_.cena), vozac=$($_.vozac_id)"
}

# 2. putovanja_istorija (danas)
Write-Host "`n2. PUTOVANJA_ISTORIJA (danas: $danas)" -ForegroundColor Yellow
$uri = "$baseUrl/putovanja_istorija?datum_putovanja=eq.$danas&select=id,putnik_ime,tip_putnika,status,cena,vozac_id,obrisan&limit=20"
$result = Invoke-RestMethod -Uri $uri -Headers $headers
if ($result.Count -eq 0) {
    Write-Host "  (nema zapisa za danas)"
} else {
    $result | ForEach-Object { 
        Write-Host "  $($_.putnik_ime) [$($_.tip_putnika)]: status=$($_.status), cena=$($_.cena), obrisan=$($_.obrisan)"
    }
}

# 3. daily_checkins (danas)
Write-Host "`n3. DAILY_CHECKINS (danas: $danas)" -ForegroundColor Yellow
$uri = "$baseUrl/daily_checkins?checkin_date=eq.$danas&select=id,putnik_ime,status,pokupljen,placeno,cena&limit=20"
try {
    $result = Invoke-RestMethod -Uri $uri -Headers $headers
    if ($result.Count -eq 0) {
        Write-Host "  (nema zapisa za danas)"
    } else {
        $result | ForEach-Object { 
            Write-Host "  $($_.putnik_ime): status=$($_.status), pokupljen=$($_.pokupljen), placeno=$($_.placeno), cena=$($_.cena)"
        }
    }
} catch {
    Write-Host "  (tabela ne postoji ili greska)"
}

# 4. putnik tabela
Write-Host "`n4. PUTNIK tabela (dnevni putnici)" -ForegroundColor Yellow
$uri = "$baseUrl/putnik?select=id,ime,status,pokupljen,cena&limit=10"
try {
    $result = Invoke-RestMethod -Uri $uri -Headers $headers
    if ($result.Count -eq 0) {
        Write-Host "  (nema zapisa)"
    } else {
        $result | ForEach-Object { 
            Write-Host "  $($_.ime): status=$($_.status), pokupljen=$($_.pokupljen), cena=$($_.cena)"
        }
    }
} catch {
    Write-Host "  (tabela ne postoji ili greska)"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "KRAJ ANALIZE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
