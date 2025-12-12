$apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"
$uri = "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/registrovani_putnici?select=putnik_ime,vreme_pokupljenja,pokupljen,status&limit=15"
$headers = @{ apikey = $apikey }
$result = Invoke-RestMethod -Uri $uri -Headers $headers
Write-Host "VREME_POKUPLJENJA u registrovani_putnici:" -ForegroundColor Yellow
$result | ForEach-Object {
    $vp = if ($_.vreme_pokupljenja) { $_.vreme_pokupljenja } else { "NULL" }
    Write-Host "  $($_.putnik_ime): vreme_pokupljenja=$vp, pokupljen=$($_.pokupljen), status=$($_.status)"
}
