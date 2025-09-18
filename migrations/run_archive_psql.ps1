# PowerShell helper to verify & archive legacy polazak_* columns
# Usage:
#  - Set env var PG_CONN or enter connection string when prompted
#  - Run the script: .\migrations\run_archive_psql.ps1
#  - The script runs verification queries and asks for confirmation before archiving.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-PsqlInPath {
    $psql = Get-Command psql -ErrorAction SilentlyContinue
    if (-not $psql) {
        Write-Error "`nCould not find 'psql' in PATH. Install Postgres client or add 'psql' to PATH and retry.`n"
        exit 2
    }
}

Ensure-PsqlInPath

if (-not $env:PG_CONN -or $env:PG_CONN.Trim() -eq '') {
    $env:PG_CONN = Read-Host -Prompt "Enter Postgres connection string (e.g. postgres://user:pass@host:5432/dbname?sslmode=require)"
}

if (-not $env:PG_CONN -or $env:PG_CONN.Trim() -eq '') {
    Write-Error "No PG_CONN provided. Exiting."
    exit 3
}

function Exec-Sql($sql, $silent = $false) {
    if ($silent) {
        $sql | psql $env:PG_CONN -v ON_ERROR_STOP=1 -q
    } else {
        $sql | psql $env:PG_CONN -v ON_ERROR_STOP=1 -q -t
    }
}

Write-Host "\nRunning verification queries against: $($env:PG_CONN)\n" -ForegroundColor Cyan

$verifySql = @'
-- Count rows with any legacy per-day columns populated
SELECT 'rows_with_legacy_polasci' AS metric, count(*)::text FROM public.mesecni_putnici
WHERE
  coalesce(polazak_bc_pon,'')<>'' OR coalesce(polazak_bc_uto,'')<>'' OR coalesce(polazak_bc_sre,'')<>'' OR coalesce(polazak_bc_cet,'')<>'' OR coalesce(polazak_bc_pet,'')<>'' OR
  coalesce(polazak_vs_pon,'')<>'' OR coalesce(polazak_vs_uto,'')<>'' OR coalesce(polazak_vs_sre,'')<>'' OR coalesce(polazak_vs_cet,'')<>'' OR coalesce(polazak_vs_pet,'')<>'';

-- Count rows missing canonical jsonb polasci_po_danu
SELECT 'missing_polasci_po_danu' AS metric, count(*)::text FROM public.mesecni_putnici
WHERE polasci_po_danu IS NULL OR polasci_po_danu = '{}'::jsonb;

-- Sample rows that still have legacy values
SELECT 'sample_row' AS metric, id::text || ' | ' || coalesce(putnik_ime,'') || ' | bc_pon=' || coalesce(polazak_bc_pon,'') || ' | vs_pon=' || coalesce(polazak_vs_pon,'')
FROM public.mesecni_putnici
WHERE coalesce(polazak_bc_pon,'')<>'' OR coalesce(polazak_vs_pon,'')<>''
LIMIT 10;
'@

try {
    $verifyOutput = Exec-Sql $verifySql
    Write-Host "Verification results:" -ForegroundColor Green
    Write-Host $verifyOutput
} catch {
    Write-Error "Verification queries failed: $_"
    exit 4
}

$confirm = Read-Host -Prompt "Run archive (create table and copy legacy polazak_* rows)? Type 'yes' to proceed"
if ($confirm.Trim().ToLower() -ne 'yes') {
    Write-Host "Archive aborted by user. No changes made." -ForegroundColor Yellow
    exit 0
}

Write-Host "Proceeding with archive..." -ForegroundColor Cyan

$archiveSql = @'
BEGIN;

CREATE TABLE IF NOT EXISTS public.mesecni_putnici_legacy_archive (
  id uuid PRIMARY KEY,
  source_table text NOT NULL,
  original_row jsonb,
  polazak_bc_pon text,
  polazak_bc_uto text,
  polazak_bc_sre text,
  polazak_bc_cet text,
  polazak_bc_pet text,
  polazak_vs_pon text,
  polazak_vs_uto text,
  polazak_vs_sre text,
  polazak_vs_cet text,
  polazak_vs_pet text,
  archived_at timestamptz DEFAULT now()
);

INSERT INTO public.mesecni_putnici_legacy_archive (
  id, source_table, original_row,
  polazak_bc_pon, polazak_bc_uto, polazak_bc_sre, polazak_bc_cet, polazak_bc_pet,
  polazak_vs_pon, polazak_vs_uto, polazak_vs_sre, polazak_vs_cet, polazak_vs_pet,
  archived_at
)
SELECT
  m.id,
  'mesecni_putnici'::text,
  to_jsonb(m.*),
  m.polazak_bc_pon, m.polazak_bc_uto, m.polazak_bc_sre, m.polazak_bc_cet, m.polazak_bc_pet,
  m.polazak_vs_pon, m.polazak_vs_uto, m.polazak_vs_sre, m.polazak_vs_cet, m.polazak_vs_pet,
  now()
FROM public.mesecni_putnici m
WHERE (
  coalesce(m.polazak_bc_pon,'')<>'' OR coalesce(m.polazak_bc_uto,'')<>'' OR coalesce(m.polazak_bc_sre,'')<>'' OR coalesce(m.polazak_bc_cet,'')<>'' OR coalesce(m.polazak_bc_pet,'')<>'' OR
  coalesce(m.polazak_vs_pon,'')<>'' OR coalesce(m.polazak_vs_uto,'')<>'' OR coalesce(m.polazak_vs_sre,'')<>'' OR coalesce(m.polazak_vs_cet,'')<>'' OR coalesce(m.polazak_vs_pet,'')<>''
)
AND m.id NOT IN (SELECT id FROM public.mesecni_putnici_legacy_archive);

COMMIT;
'@

try {
    Exec-Sql $archiveSql $true | Out-Null
    Write-Host "Archive completed. Running post-archive verification..." -ForegroundColor Green
    $postSql = @'
SELECT 'remaining_with_legacy' AS metric, count(*)::text FROM public.mesecni_putnici WHERE (
  coalesce(polazak_bc_pon,'')<>'' OR coalesce(polazak_bc_uto,'')<>'' OR coalesce(polazak_bc_sre,'')<>'' OR coalesce(polazak_bc_cet,'')<>'' OR coalesce(polazak_bc_pet,'')<>'' OR
  coalesce(polazak_vs_pon,'')<>'' OR coalesce(polazak_vs_uto,'')<>'' OR coalesce(polazak_vs_sre,'')<>'' OR coalesce(polazak_vs_cet,'')<>'' OR coalesce(polazak_vs_pet,'')<>''
);

SELECT 'archived_count' AS metric, count(*)::text FROM public.mesecni_putnici_legacy_archive;
'@
    $postOutput = Exec-Sql $postSql
    Write-Host $postOutput
    Write-Host "Done. Archive table: public.mesecni_putnici_legacy_archive" -ForegroundColor Green
} catch {
    Write-Error "Archive failed: $_"
    exit 5
}
