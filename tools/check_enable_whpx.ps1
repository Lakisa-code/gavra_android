<#
check_enable_whpx.ps1

Skripta na srpskom koja proverava Windows virtualizacione feature-e
i po izboru omogućava Windows Hypervisor Platform (WHPX) ili
VirtualMachinePlatform. Pokrenuti u PowerShell-u kao Administrator.

Usage: pokreni iz PowerShell (Run as Administrator). Skripta će automatski
ponovno pokrenuti samu sebe uz elevaciju ako nije pokrenuta kao admin.
#>

function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Elevate-IfNeeded {
    if (-not (Test-IsAdmin)) {
        Write-Host "Skripta nije pokrenuta kao Administrator. Pokušavam da pokrenem sa elevacijom..." -ForegroundColor Yellow
        Start-Process -FilePath pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

function Show-WindowsInfo {
    Write-Host "\n=== Informacije o Windows-u ===" -ForegroundColor Cyan
    try {
        Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber | Format-List
    } catch {
        Write-Host "Ne mogu da dohvatim Windows informacije: $_" -ForegroundColor Red
    }
}

function Show-FeatureList {
    Write-Host "\n=== Dostupne opcije (pretražujem 'Hyper' i 'Virtual') ===" -ForegroundColor Cyan
    try {
        $out = dism /online /get-features 2>&1 | Out-String
        $lines = $out -split "`n" | Where-Object { $_ -match 'Hyper|Virtual' }
        if ($lines) { $lines | ForEach-Object { Write-Host $_ } } else { Write-Host "Nema vidljivih feature-a koji sadrže 'Hyper' ili 'Virtual'." }
    } catch {
        Write-Host "DISM nije mogao da izvrši listu feature-a: $_" -ForegroundColor Red
    }
}

function Show-HyperVRequirements {
    Write-Host "\n=== Hyper-V zahtevi (virtualizacija u firmware-u) ===" -ForegroundColor Cyan
    try {
        systeminfo | findstr /i "Hyper-V Requirements" | ForEach-Object { Write-Host $_ }
    } catch {
        Write-Host "Ne mogu da dobijem systeminfo: $_" -ForegroundColor Red
    }
}

function Get-FeatureState($name) {
    try {
        $dism = dism /online /get-features | Out-String
        $pattern = [regex]::Escape($name)
        $match = $dism -split "`n" | Where-Object { $_ -match $pattern }
        if ($match) { return ($match -join "`n").Trim() } else { return "Feature '$name' nije pronađen u DISM izlazu." }
    } catch {
        return "Greška pri provere feature-a ${name}: $($_)"
    }
}

function Enable-Feature($name) {
    Write-Host "Pokušavam da omogućim feature: $name" -ForegroundColor Yellow
    try {
        $res = & dism /online /enable-feature /featurename:$name /all /norestart 2>&1
        Write-Host $res
        Write-Host "Završeno. Ako je potrebno, restartujte računar da bi promena stupila na snagu." -ForegroundColor Green
    } catch {
        Write-Host "Greška pri omogućavanju ${name}: $($_)" -ForegroundColor Red
    }
}

Elevate-IfNeeded
Write-Host "\nProveravam sistem..." -ForegroundColor Green
Show-WindowsInfo
Show-FeatureList
Show-HyperVRequirements

Write-Host "\n=== Trenutno stanje važnih feature-a ===" -ForegroundColor Cyan
$candidates = @('VirtualMachinePlatform','HypervisorPlatform','Microsoft-Hyper-V-All')
foreach ($f in $candidates) {
    Write-Host "---- $f ----" -ForegroundColor Magenta
    Write-Host (Get-FeatureState $f)
}

Write-Host "\nAko želiš da omogućimo koji od ovih feature-a, izaberi broj i pritisni Enter:" -ForegroundColor Cyan
Write-Host "1) VirtualMachinePlatform (preporučeno za WHPX)"
Write-Host "2) HypervisorPlatform"
Write-Host "3) Microsoft-Hyper-V-All (omogući kompletan Hyper-V; ne preporučuje se ako želiš HAXM)"
Write-Host "4) Ništa (izlaz)"

$choice = Read-Host "Izbor (1-4)"
switch ($choice) {
    '1' { Enable-Feature 'VirtualMachinePlatform' }
    '2' { Enable-Feature 'HypervisorPlatform' }
    '3' { Enable-Feature 'Microsoft-Hyper-V-All' }
    default { Write-Host "Nema promena. Izlazim." -ForegroundColor Yellow }
}

Write-Host "\nKraj. Napomena: nakon omogućavanja feature-a često je potreban restart." -ForegroundColor Cyan
Write-Host "Možeš restartovati odmah sa: Restart-Computer" -ForegroundColor Yellow

exit
