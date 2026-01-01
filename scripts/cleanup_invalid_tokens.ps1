# GAVRA TOKEN CLEANUP - Ciscenje nevalidnih push tokena
# Testira sve tokene i brise one koji su UNREGISTERED
#
# Koriscenje:
#   .\cleanup_invalid_tokens.ps1           # Samo prikazi nevalidne
#   .\cleanup_invalid_tokens.ps1 -Delete   # Obrisi nevalidne tokene

param(
    [switch]$Delete = $false
)

Write-Host "GAVRA TOKEN CLEANUP" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

$supabaseUrl = "https://gjtabtwudbrmfeyjiicu.supabase.co"
$supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk"

$headers = @{
    "Authorization" = "Bearer $supabaseAnonKey"
    "apikey" = $supabaseAnonKey
    "Content-Type" = "application/json"
}

# 1. Dohvati sve tokene
Write-Host "`nDohvatam sve tokene iz baze..." -ForegroundColor Yellow
$tokens = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/push_tokens?select=id,token,provider,user_id" -Headers $headers -Method Get

Write-Host "   Ukupno tokena: $($tokens.Count)" -ForegroundColor Gray

# 2. Testiraj tokene slanjem tihe notifikacije
Write-Host "`nTestiram validnost tokena..." -ForegroundColor Yellow

$invalidTokens = @()
$validTokens = @()

# Posalji test notifikaciju i analiziraj rezultate
$payload = @{
    title = "Token Validation"
    body = "Silent validation check"
    broadcast = $true
    data = @{
        type = "token_validation"
        silent = $true
    }
} | ConvertTo-Json -Depth 5

try {
    $response = Invoke-RestMethod -Uri "$supabaseUrl/functions/v1/send-push-notification" -Method Post -Headers $headers -Body $payload -ErrorAction Stop
    
    foreach ($result in $response.results) {
        $tokenInfo = $tokens | Where-Object { $_.token.StartsWith($result.token.Substring(0, 20)) }
        
        if ($result.success -eq $false) {
            if ($result.error -match "UNREGISTERED|invalid|All the tokens are invalid") {
                $invalidTokens += @{
                    id = $tokenInfo.id
                    token = $result.token
                    provider = $result.provider
                    user_id = $tokenInfo.user_id
                    error = $result.error
                }
            }
        } else {
            $validTokens += @{
                token = $result.token
                provider = $result.provider
                user_id = $tokenInfo.user_id
            }
        }
    }
} catch {
    Write-Host "Greska pri testiranju: $_" -ForegroundColor Red
    exit 1
}

# 3. Prikazi rezultate
Write-Host "`nREZULTATI ANALIZE:" -ForegroundColor Cyan
Write-Host "   Validnih tokena: $($validTokens.Count)" -ForegroundColor Green
Write-Host "   Nevalidnih tokena: $($invalidTokens.Count)" -ForegroundColor Red

if ($invalidTokens.Count -gt 0) {
    Write-Host "`nNEVALIDNI TOKENI:" -ForegroundColor Red
    foreach ($inv in $invalidTokens) {
        $shortToken = if ($inv.token.Length -gt 20) { $inv.token.Substring(0, 20) + "..." } else { $inv.token }
        $user = if ($inv.user_id) { $inv.user_id } else { "anoniman" }
        Write-Host "   [$($inv.provider)] $user - $shortToken" -ForegroundColor Yellow
    }
}

# 4. Brisanje nevalidnih tokena
if ($Delete -and $invalidTokens.Count -gt 0) {
    Write-Host "`nBRISANJE NEVALIDNIH TOKENA..." -ForegroundColor Yellow
    
    $deleted = 0
    foreach ($inv in $invalidTokens) {
        if ($inv.id) {
            try {
                $deleteHeaders = @{
                    "Authorization" = "Bearer $supabaseAnonKey"
                    "apikey" = $supabaseAnonKey
                    "Prefer" = "return=minimal"
                }
                Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/push_tokens?id=eq.$($inv.id)" -Headers $deleteHeaders -Method Delete -ErrorAction Stop
                $deleted++
                $userName = if ($inv.user_id) { $inv.user_id } else { "anoniman" }
                Write-Host "   Obrisan token za $userName" -ForegroundColor Green
            } catch {
                Write-Host "   Greska pri brisanju: $_" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`nObrisano $deleted nevalidnih tokena!" -ForegroundColor Green
} elseif ($invalidTokens.Count -gt 0) {
    Write-Host "`nZa brisanje nevalidnih tokena, pokreni:" -ForegroundColor Yellow
    Write-Host "   .\cleanup_invalid_tokens.ps1 -Delete" -ForegroundColor Cyan
}

Write-Host "`nZAVRSENO!" -ForegroundColor Green
