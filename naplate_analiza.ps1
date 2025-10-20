# 💰 SUPABASE НАПЛАТЕ АНАЛИЗА
# ===============================================

Write-Host "🚀 Извлачење наплата из Supabase Cloud..." -ForegroundColor Green

$apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk"
$baseUrl = "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1"

# 1. МЕСЕЧНЕ НАПЛАТЕ (vreme_placanja)
Write-Host "`n📅 МЕСЕЧНЕ НАПЛАТЕ:" -ForegroundColor Yellow
Write-Host "=" * 60

try {
    $mesecneUrl = "$baseUrl/mesecni_putnici?select=putnik_ime,cena,vreme_placanja,placeni_mesec,placena_godina&vreme_placanja=not.is.null&order=vreme_placanja.desc&limit=100"
    $mesecneResponse = Invoke-RestMethod -Uri $mesecneUrl -Headers @{ "apikey" = $apiKey; "Authorization" = "Bearer $apiKey" }
    
    # Групирај по датумима  
    $mesecnePoDatemu = $mesecneResponse | Group-Object { 
        $datum = [DateTime]::Parse($_.vreme_placanja)
        $datum.ToString("yyyy-MM-dd")
    } | Sort-Object Name -Descending

    foreach ($grupa in $mesecnePoDatemu) {
        $datum = $grupa.Name
        $ukupno = ($grupa.Group | Measure-Object -Property cena -Sum).Sum
        $brojNaplata = $grupa.Count
        
        Write-Host "`n📊 $datum" -ForegroundColor Cyan
        Write-Host "   💰 Укупно: $ukupno RSD ($brojNaplata наплата)" -ForegroundColor White
        
        foreach ($naplata in $grupa.Group | Sort-Object vreme_placanja -Descending) {
            $vreme = [DateTime]::Parse($naplata.vreme_placanja).ToString("HH:mm")
            Write-Host "   • $($naplata.putnik_ime) - $($naplata.cena) RSD [$vreme] (Месец: $($naplata.placeni_mesec)/$($naplata.placena_godina))" -ForegroundColor Gray
        }
    }
    
    $ukupnoMesecne = ($mesecneResponse | Measure-Object -Property cena -Sum).Sum
    Write-Host "`n💵 УКУПНО МЕСЕЧНЕ НАПЛАТЕ: $ukupnoMesecne RSD" -ForegroundColor Green

}
catch {
    Write-Host "❌ Грешка при учитавању месечних наплата: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. ДНЕВНЕ НАПЛАТЕ (путовања историја са ценом)
Write-Host "`n`n🎯 ДНЕВНЕ НАПЛАТЕ (Путовања историја):" -ForegroundColor Yellow  
Write-Host "=" * 60

try {
    $dnevneUrl = "$baseUrl/putovanja_istorija?select=putnik_ime,cena,datum_putovanja,vreme_polaska,tip_putnika&cena=not.is.null&cena=neq.0&order=datum_putovanja.desc&limit=100"
    $dnevneResponse = Invoke-RestMethod -Uri $dnevneUrl -Headers @{ "apikey" = $apiKey; "Authorization" = "Bearer $apiKey" }
    
    if ($dnevneResponse.Count -gt 0) {
        # Групирај по датумима
        $dnevnePoDatemu = $dnevneResponse | Group-Object datum_putovanja | Sort-Object Name -Descending

        foreach ($grupa in $dnevnePoDatemu) {
            $datum = $grupa.Name
            $ukupno = ($grupa.Group | Measure-Object -Property cena -Sum).Sum
            $brojNaplata = $grupa.Count
            
            Write-Host "`n📊 $datum" -ForegroundColor Cyan
            Write-Host "   💰 Укупно: $ukupno RSD ($brojNaplata путовања)" -ForegroundColor White
            
            foreach ($putovanje in $grupa.Group | Sort-Object vreme_polaska) {
                $tip = if ($putovanje.tip_putnika) { "[$($putovanje.tip_putnika)]" } else { "[дневни]" }
                Write-Host "   • $($putovanje.putnik_ime) - $($putovanje.cena) RSD [$($putovanje.vreme_polaska)] $tip" -ForegroundColor Gray
            }
        }
        
        $ukupnoDnevne = ($dnevneResponse | Measure-Object -Property cena -Sum).Sum
        Write-Host "`n💵 УКУПНО ДНЕВНЕ НАПЛАТЕ: $ukupnoDnevne RSD" -ForegroundColor Green
    }
    else {
        Write-Host "   📝 Нема дневних наплата са ценом > 0" -ForegroundColor Gray
    }

}
catch {
    Write-Host "❌ Грешка при учитавању дневних наплата: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. ДНЕВНИ ПУТНИЦИ (активни са ценом)
Write-Host "`n`n🌟 ДНЕВНИ ПУТНИЦИ (Активни):" -ForegroundColor Yellow
Write-Host "=" * 60

try {
    $aktivniUrl = "$baseUrl/dnevni_putnici?select=putnik_ime,cena,datum_putovanja,vreme_polaska,status&cena=not.is.null&order=datum_putovanja.desc&limit=50"
    $aktivniResponse = Invoke-RestMethod -Uri $aktivniUrl -Headers @{ "apikey" = $apiKey; "Authorization" = "Bearer $apiKey" }
    
    if ($aktivniResponse.Count -gt 0) {
        # Групирај по датумима
        $aktivniPoDatemu = $aktivniResponse | Group-Object datum_putovanja | Sort-Object Name -Descending

        foreach ($grupa in $aktivniPoDatemu) {
            $datum = $grupa.Name
            $ukupno = ($grupa.Group | Measure-Object -Property cena -Sum).Sum
            $brojPutnika = $grupa.Count
            
            Write-Host "`n📊 $datum" -ForegroundColor Cyan
            Write-Host "   💰 Укупно: $ukupno RSD ($brojPutnika путника)" -ForegroundColor White
            
            foreach ($putnik in $grupa.Group | Sort-Object vreme_polaska) {
                $status = if ($putnik.status) { "[$($putnik.status)]" } else { "[активно]" }
                Write-Host "   • $($putnik.putnik_ime) - $($putnik.cena) RSD [$($putnik.vreme_polaska)] $status" -ForegroundColor Gray
            }
        }
        
        $ukupnoAktivni = ($aktivniResponse | Measure-Object -Property cena -Sum).Sum
        Write-Host "`n💵 УКУПНО АКТИВНИ ДНЕВНИ: $ukupnoAktivni RSD" -ForegroundColor Green
    }
    else {
        Write-Host "   📝 Нема активних дневних путника са ценом" -ForegroundColor Gray
    }

}
catch {
    Write-Host "❌ Грешка при учитавању активних дневних путника: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n`n🎉 АНАЛИЗА ЗАВРШЕНА!" -ForegroundColor Green
Write-Host "📊 Подаци приказани по датумима (најновији прво)" -ForegroundColor Yellow