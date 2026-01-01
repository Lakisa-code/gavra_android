# 🔔 SKRIPTA ZA TESTIRANJE NOTIFIKACIJA
# Testira lokalne i push notifikacije za Gavra aplikaciju
# 
# Korišćenje:
#   .\test_notifications.ps1 -Type local    # Testiraj lokalne notifikacije
#   .\test_notifications.ps1 -Type push     # Testiraj push notifikacije
#   .\test_notifications.ps1 -Type all      # Testiraj sve

param(
    [ValidateSet("local", "push", "all")]
    [string]$Type = "all"
)

Write-Host "🔔 GAVRA NOTIFICATION TESTER" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Učitaj Supabase credentials iz okruženja ili .env fajla
$envFile = Join-Path $PSScriptRoot "..\temp_secrets.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
}

$supabaseUrl = $env:SUPABASE_URL
$supabaseServiceKey = $env:SUPABASE_SERVICE_ROLE_KEY

if (-not $supabaseUrl -or -not $supabaseServiceKey) {
    Write-Host "❌ SUPABASE_URL ili SUPABASE_SERVICE_ROLE_KEY nisu postavljeni!" -ForegroundColor Red
    Write-Host "Postavi ih u temp_secrets.env ili kao environment varijable." -ForegroundColor Yellow
    exit 1
}

function Send-TestPushNotification {
    param(
        [string]$Title,
        [string]$Body,
        [bool]$Broadcast = $true
    )
    
    $payload = @{
        title = $Title
        body = $Body
        broadcast = $Broadcast
        data = @{
            type = "test"
            timestamp = (Get-Date).ToString("o")
        }
    } | ConvertTo-Json -Depth 5

    $headers = @{
        "Authorization" = "Bearer $supabaseServiceKey"
        "Content-Type" = "application/json"
        "apikey" = $supabaseServiceKey
    }

    $uri = "$supabaseUrl/functions/v1/send-push-notification"
    
    try {
        Write-Host "`n📤 Šaljem push notifikaciju..." -ForegroundColor Yellow
        Write-Host "   Title: $Title" -ForegroundColor Gray
        Write-Host "   Body: $Body" -ForegroundColor Gray
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $payload -ErrorAction Stop
        
        if ($response.success) {
            Write-Host "✅ Push notifikacija uspešno poslata!" -ForegroundColor Green
            Write-Host "   Sent to: $($response.sent_count) uređaja" -ForegroundColor Gray
        } else {
            Write-Host "⚠️ Odgovor servera: $($response | ConvertTo-Json)" -ForegroundColor Yellow
        }
        return $true
    }
    catch {
        Write-Host "❌ Greška pri slanju push notifikacije: $_" -ForegroundColor Red
        return $false
    }
}

function Get-RegisteredPushTokens {
    $headers = @{
        "Authorization" = "Bearer $supabaseServiceKey"
        "Content-Type" = "application/json"
        "apikey" = $supabaseServiceKey
    }

    $uri = "$supabaseUrl/rest/v1/push_tokens?select=*"
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
        return $response
    }
    catch {
        Write-Host "❌ Greška pri dohvatanju tokena: $_" -ForegroundColor Red
        return @()
    }
}

# ============================================
# GLAVNA LOGIKA
# ============================================

Write-Host "`n📊 PREGLED REGISTROVANIH TOKENA" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan

$tokens = Get-RegisteredPushTokens

if ($tokens.Count -eq 0) {
    Write-Host "⚠️ Nema registrovanih push tokena u bazi!" -ForegroundColor Yellow
    Write-Host "   Pokreni aplikaciju na uređaju da bi se token registrovao." -ForegroundColor Gray
} else {
    Write-Host "✅ Pronađeno $($tokens.Count) registrovanih tokena:" -ForegroundColor Green
    $tokens | ForEach-Object {
        $provider = if ($_.provider) { $_.provider } else { "unknown" }
        $user = if ($_.user_id) { $_.user_id } else { "anoniman" }
        $created = if ($_.created_at) { 
            ([DateTime]::Parse($_.created_at)).ToString("yyyy-MM-dd HH:mm") 
        } else { 
            "nepoznato" 
        }
        Write-Host "   • [$provider] $user (registrovan: $created)" -ForegroundColor Gray
    }
}

# Testiraj push notifikacije
if ($Type -eq "push" -or $Type -eq "all") {
    Write-Host "`n🚀 TEST PUSH NOTIFIKACIJA" -ForegroundColor Cyan
    Write-Host "-------------------------" -ForegroundColor Cyan
    
    # Test 1: Broadcast notifikacija
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    Send-TestPushNotification `
        -Title "🧪 Test notifikacija" `
        -Body "Ovo je test notifikacija poslata u $timestamp" `
        -Broadcast $true
    
    Start-Sleep -Seconds 2
    
    # Test 2: Specifična notifikacija
    Write-Host "`n📨 Šaljem drugu test notifikaciju za 2 sekunde..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    Send-TestPushNotification `
        -Title "📱 Gavra Test" `
        -Body "Push notifikacije rade ispravno! 🎉" `
        -Broadcast $true
}

# Informacija o lokalnim notifikacijama
if ($Type -eq "local" -or $Type -eq "all") {
    Write-Host "`n📱 TEST LOKALNIH NOTIFIKACIJA" -ForegroundColor Cyan
    Write-Host "-----------------------------" -ForegroundColor Cyan
    Write-Host "Lokalne notifikacije se testiraju direktno iz aplikacije." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Za testiranje u aplikaciji, dodaj sledeći kod:" -ForegroundColor Gray
    Write-Host @"

  // U bilo kom widgetu:
  await LocalNotificationService.showRealtimeNotification(
    title: 'Test Notifikacija',
    body: 'Ovo je test lokalne notifikacije!',
  );

"@ -ForegroundColor DarkGray
}

Write-Host "`n✅ TESTIRANJE ZAVRŠENO" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host ""
Write-Host "📝 NAPOMENE:" -ForegroundColor Yellow
Write-Host "   1. Proveri da li je aplikacija instalirana na uređaju" -ForegroundColor Gray
Write-Host "   2. Proveri da li su notifikacije dozvoljene u podešavanjima" -ForegroundColor Gray
Write-Host "   3. Za debugging, koristi: adb logcat | Select-String 'FCM|Huawei|Notification'" -ForegroundColor Gray
Write-Host ""
