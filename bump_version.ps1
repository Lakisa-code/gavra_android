# Skripta za automatsko podizanje verzije (Patch update)
# Primer: 6.0.25 -> 6.0.26

$pubspecPath = "pubspec.yaml"
$content = Get-Content $pubspecPath

# Pronadji liniju sa verzijom
$versionRegex = "^version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)"
$newContent = @()

foreach ($line in $content) {
    if ($line -match $versionRegex) {
        $major = $matches[1]
        $minor = $matches[2]
        $patch = $matches[3]
        $build = $matches[4]

        # Podigni patch verziju za 1
        $newPatch = [int]$patch + 1
        
        # Podigni build broj za 1 takodje, da bi Google Play bio srecan
        $newBuild = [int]$build + 1
        
        $newVersion = "version: $major.$minor.$newPatch+$newBuild"
        
        Write-Host "Menjam verziju: $major.$minor.$patch+$build -> $major.$minor.$newPatch+$newBuild" -ForegroundColor Green
        $newContent += $newVersion
    } else {
        $newContent += $line
    }
}

$newContent | Set-Content $pubspecPath
Write-Host "Uspesno azurirano! Sada uradi: git add . ; git commit -m 'Bump version'" -ForegroundColor Yellow
