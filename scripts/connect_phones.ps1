# Skripta za povezivanje telefona na wireless debugging
# Koristi: .\scripts\connect_phones.ps1

Write-Host ""
Write-Host "[PHONE] POVEZIVANJE TELEFONA" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Definicija telefona (azuriraj IP adrese ako se promene)
$phones = @(
    @{ Name = "Samsung"; IP = "192.168.43.228"; Serial = "RF8M33QM9EJ" }
    @{ Name = "Huawei";  IP = "192.168.43.188"; Serial = "EPHUT20C21000772" }
    @{ Name = "Mate";    IP = "192.168.43.139"; Serial = "GBB0220B03001125" }
)

# Povezivanje svakog telefona
foreach ($phone in $phones) {
    Write-Host ""
    Write-Host "Povezujem $($phone.Name)..." -ForegroundColor Yellow
    $port = "5555"
    $address = $phone.IP + ":" + $port
    $result = adb connect $address 2>&1
    
    if ($result -match "connected|already") {
        Write-Host "  [OK] $($phone.Name) povezan ($address)" -ForegroundColor Green
    } else {
        Write-Host "  [X] $($phone.Name) NIJE povezan - $result" -ForegroundColor Red
    }
}

# Prikaz svih povezanih uredjaja
Write-Host ""
Write-Host "[LIST] POVEZANI UREDJAJI:" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan

$devices = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "device$" }

foreach ($device in $devices) {
    $ip = ($device -split "\s+")[0]
    $phoneName = "Nepoznat"
    
    foreach ($phone in $phones) {
        if ($ip -match $phone.IP -or $ip -match $phone.Serial) {
            $phoneName = $phone.Name
            break
        }
    }
    
    Write-Host "  [*] $phoneName -> $ip" -ForegroundColor White
}

Write-Host ""
Write-Host "[OK] Spreman za: flutter run -d all" -ForegroundColor Green
Write-Host ""
