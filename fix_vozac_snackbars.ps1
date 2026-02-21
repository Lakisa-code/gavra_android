
$file = "c:\Users\Bojan\gavra_android\lib\screens\vozac_screen.dart"
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

# Pattern: match ScaffoldMessenger.of(context).showSnackBar( ... ); blocks
# We'll do specific targeted replacements

# 1. Line ~591 - mora biti ulogovan (orange)
$content = $content -replace `
"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content: Text\('Morate biti ulogovani i ovla[^']*'\),\s*backgroundColor: Colors\.orange,\s*\),\s*\);", `
"AppSnackBar.warning(context, 'Morate biti ulogovani i ovlaš}ćeni da biste koristili optimizaciju rute.');"

Write-Host "After replacement 1: $( ([regex]::Matches($content, 'showSnackBar')).Count ) remaining"

[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
