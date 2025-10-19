# 🧪 SUPABASE CLOUD - ТЕСТ СКРИПТ
# Користи овај script за брзо тестирање Supabase конекције

# Читам кључеве из оригиналног фајла да избегнем проблеме са копирањем
$ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk"
$SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHد1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"
$URL = "https://gjtabtwudbrmfeyjiicu.supabase.co"

Write-Host "🧪 ТЕСТИРАМ SUPABASE CLOUD КОНЕКЦИЈУ..." -ForegroundColor Yellow

# Тест 1: Возачи
Write-Host "`n1️⃣ Тест: Возачи" -ForegroundColor Cyan
$result1 = curl -H "apikey: $ANON_KEY" "$URL/rest/v1/vozaci?select=ime&limit=2" 2>$null
Write-Host $result1 -ForegroundColor Green

# Тест 2: Месечни путници  
Write-Host "`n2️⃣ Тест: Месечни путници" -ForegroundColor Cyan
$result2 = curl -H "apikey: $ANON_KEY" "$URL/rest/v1/mesecni_putnici?select=putnik_ime,aktivan&limit=2" 2>$null
Write-Host $result2 -ForegroundColor Green

# Тест 3: Број записа у табелама
Write-Host "`n3️⃣ Тест: Број записа" -ForegroundColor Cyan
$count_vozaci = curl -H "apikey: $ANON_KEY" -H "Prefer: count=exact" "$URL/rest/v1/vozaci?select=" 2>$null | Out-String
$count_putnici = curl -H "apikey: $ANON_KEY" -H "Prefer: count=exact" "$URL/rest/v1/mesecni_putnici?select=" 2>$null | Out-String

Write-Host "Возачи: $count_vozaci" -ForegroundColor Green
Write-Host "Месечни путници: $count_putnici" -ForegroundColor Green

Write-Host "`n✅ SUPABASE CLOUD КОНЕКЦИЈА УСПЕШНА!" -ForegroundColor Green
Write-Host "📋 Користи SUPABASE_CLOUD_GUIDE.md за детаљне инструкције" -ForegroundColor Blue