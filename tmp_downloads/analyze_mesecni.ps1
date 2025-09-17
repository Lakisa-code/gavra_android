$csvPath = "tmp_downloads\mesecni_putnici_rows.csv"
$days = @('pon','uto','sre','cet','pet')
function NormalizeTime($t) {
    if (-not $t) { return '' }
    $s = $t -split ' ' | Select-Object -First 1
    $s = $s.Trim()
    if ($s -eq '') { return '' }
    $parts = $s -split ':'
    if ($parts.Length -ge 2) {
        $hh = [int]$parts[0]
        $mm = $parts[1]
        return "{0}:{1}" -f $hh, $mm
    }
    return $s
}

# initialize
$per_day = @{}
foreach ($d in $days) {
    $per_day[$d] = [pscustomobject]@{
        rows = 0
        bc = 0
        vs = 0
        bc_times = @{}
        vs_times = @{}
    }
}

if (-not (Test-Path $csvPath)) {
    Write-Host "File not found: $csvPath"
    exit 1
}

Import-Csv -Path $csvPath -Encoding UTF8 | ForEach-Object {
    $row = $_
    $radni = if ($null -ne $row.radni_dani) { $row.radni_dani } else { '' }
    foreach ($d in $days) {
        if ($radni -like "*$d*") {
            $pd = $per_day[$d]
            $pd.rows += 1
            $bc_col = "polazak_bc_$d"
            $vs_col = "polazak_vs_$d"
            $bc_val = $row.$bc_col
            $vs_val = $row.$vs_col
            $legacy_bc = $row.polazak_bela_crkva
            $legacy_vs = $row.polazak_vrsac
            $bc_time = if ($bc_val -and $bc_val.Trim() -ne '') { NormalizeTime $bc_val } else { NormalizeTime $legacy_bc }
            $vs_time = if ($vs_val -and $vs_val.Trim() -ne '') { NormalizeTime $vs_val } else { NormalizeTime $legacy_vs }
            if ($bc_time -and $bc_time -ne '') {
                $pd.bc += 1
                if ($pd.bc_times.ContainsKey($bc_time)) { $pd.bc_times[$bc_time] += 1 } else { $pd.bc_times[$bc_time] = 1 }
            }
            if ($vs_time -and $vs_time -ne '') {
                $pd.vs += 1
                if ($pd.vs_times.ContainsKey($vs_time)) { $pd.vs_times[$vs_time] += 1 } else { $pd.vs_times[$vs_time] = 1 }
            }
        }
    }
}

foreach ($d in $days) {
    $pd = $per_day[$d]
    Write-Host "Day: $d"
    Write-Host "  Matching rows (radni_dani contains): $($pd.rows)"
    Write-Host "  BC departures: $($pd.bc)"
    Write-Host "  VS departures: $($pd.vs)"
    Write-Host "  BC times (most common):"
    $sortedBC = $pd.bc_times.GetEnumerator() | Sort-Object -Property Value -Descending
    if ($sortedBC -and $sortedBC.Count -gt 0) {
        $max = [math]::Min(9,$sortedBC.Count-1)
        foreach ($kv in $sortedBC[0..$max]) {
            Write-Host "    $($kv.Key): $($kv.Value)"
        }
    } else {
        Write-Host "    (none)"
    }
    Write-Host "  VS times (most common):"
    $sortedVS = $pd.vs_times.GetEnumerator() | Sort-Object -Property Value -Descending
    if ($sortedVS -and $sortedVS.Count -gt 0) {
        $max = [math]::Min(9,$sortedVS.Count-1)
        foreach ($kv in $sortedVS[0..$max]) {
            Write-Host "    $($kv.Key): $($kv.Value)"
        }
    } else {
        Write-Host "    (none)"
    }
    Write-Host ""
}
