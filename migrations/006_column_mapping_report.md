# Column Mapping Report

Generated: 2025-09-18

Purpose: per-table mapping of columns present in CSV/SQL dumps vs columns used by the app code. For each column: "Used by code?", "Present in dumps?", and recommended action.

## Table: `mesecni_putnici`

Columns used by code (required / actively referenced):
- `id` — Used: YES | In dumps: YES | Action: KEEP
- `putnik_ime` — YES | YES | KEEP
- `tip` — YES | YES | KEEP
- `tip_skole` — YES | YES | KEEP
- `broj_telefona` — YES | YES | KEEP
- `polasci_po_danu` (jsonb canonical) — YES | Depends (001 migration backfilled) | KEEP; ensure filled for all rows.
- `adresa_bela_crkva` — YES | YES | KEEP
- `adresa_vrsac` — YES | YES | KEEP
- `tip_prikazivanja` — YES | YES | KEEP
- `radni_dani` (legacy text) — YES (code reads fallback) | YES | KEEP TEMP; convert to `radni_dani_arr` then consider DROP.
- `aktivan` — YES | YES | KEEP
- `status` — YES | YES | KEEP
- `datum_pocetka_meseca` — YES | YES | KEEP
- `datum_kraja_meseca` — YES | YES | KEEP
- `ukupnaCenaMeseca` (app field) stored as `cena` historically — YES | YES (`cena` in dumps) | KEEP; migrate to numeric column if needed.
- `cena` — YES (used as numeric) | YES | KEEP; we added `cena_numeric` in migration — ensure consistent type and update code to use `cena` or `cena_numeric` consistently.
- `broj_putovanja` — YES | YES | KEEP
- `broj_otkazivanja` — YES | YES | KEEP
- `poslednje_putovanje` — YES | YES | KEEP
- `created_at`, `updated_at` — YES | YES | KEEP
- `obrisan` — YES | YES | KEEP (used for soft-delete)
- `pokupljen` — YES | YES | KEEP
- `vreme_pokupljenja` — YES | YES | KEEP (field name with small 'e' expected)
- `vreme_placanja` — YES | YES | KEEP
- `vozac` — YES | YES | KEEP
- `placeni_mesec` — YES | YES | KEEP
- `placena_godina` — YES | YES | KEEP
- `sitan_novac` — occasionally used in reports | YES | KEEP
- `statistics` (jsonb) — YES (new) | NO in older dumps | KEEP and populate going forward

Legacy columns present in dumps but NOT used or replaced by canonical fields:
- `polazak_bc_pon`, `polazak_bc_uto`, `polazak_bc_sre`, `polazak_bc_cet`, `polazak_bc_pet` — Present in dumps | REPLACED by `polasci_po_danu` — Action: KEEP until `polasci_po_danu` is verified for all rows, then DROP.
- `polazak_vs_pon` ... `polazak_vs_pet` — same as above.

Recommendation for `mesecni_putnici`:
- Ensure `polasci_po_danu` is populated for 100% rows. Use `migrations/imports` data for verification.
- Keep `radni_dani` until `radni_dani_arr` is fully populated for all rows; then drop `radni_dani`.
- Keep `polazak_*` columns until backfill verification completes; then remove to simplify schema.
- Confirm `cena` column type; prefer a numeric typed column (we added `cena_numeric`) and update app mapping to write `cena_numeric` or coalesce.
- Keep `statistics` as `jsonb` for flexible analytics; populate incrementally.

## Table: `putovanja_istorija`

Columns used by code (required / actively referenced):
- `id` — YES | YES | KEEP
- `mesecni_putnik_id` — YES | YES | KEEP (used to link to mesecni_putnici)
- `tip_putnika` — YES | YES | KEEP
- `datum` — YES | YES | KEEP
- `vreme_polaska` — YES | YES | KEEP (ordering and time-based logic)
- `adresa_polaska` — YES | YES | KEEP
- `putnik_ime` — YES | YES | KEEP (fallback mapping)
- `broj_telefona` — YES | YES | KEEP
- `created_at`, `updated_at` — YES | YES | KEEP
- `status` — YES | YES | KEEP (values: `zakupljeno`, `pokupljen`, `nije_se_pojavio`)
- `pokupljen` — YES | YES | KEEP (boolean used in logic)
- `vreme_pokupljenja` — YES | YES | KEEP
- `vreme_placanja` — referenced in some migration | YES | KEEP
- `vozac` — YES | YES | KEEP
- `dan`, `grad` — YES | YES | KEEP (used for heuristics)
- `obrisan` — YES | YES | KEEP
- `cena` — YES | YES | KEEP (ensure numeric consistency)
- `pokupljanje_vozac`, `naplata_vozac`, `otkazao_vozac`, `dodao_vozac` — present in dumps | KEEP (used for audit and historical tracing)

Notes & recommendations for `putovanja_istorija`:
- Many rows in dumps have `status='nije_se_pojavio'` and `cena=0.0`. We previously drafted an archive step to move noisy rows to `putovanja_istorija_archive`. That remains optional but recommended for performance.
- Add indexes on `(datum, vreme_polaska)`, `(mesecni_putnik_id)`, and `lower(status)` (we added expression index). Keep `vreme_*` as timestamptz if you want time-of-day comparisons; currently many fields are stored as text (HH:MM:SS). Consider adding `vreme_polaska_ts` if you need full timestamp arithmetic.

## Table: `gps_lokacije`

Columns in dumps:
- `id`, `name`, `lat`, `lng`, `timestamp`, `color`, `vehicle_type` — Present in CSV

Usage in code:
- `gps_lokacije` is not heavily used by mesecni_putnici service; likely used in maps/driver tracking features. Mark as KEEP. Add appropriate indexes on (`name`, `timestamp`) if queries filter by driver and time.

## Table: `daily_reports`

Columns in dumps:
- `id`, `vozac`, `datum`, `ukupan_pazar`, `sitan_novac`, `dnevni_pazari`, `dodati_putnici`, `otkazani_putnici`, `naplaceni_putnici`, `pokupljeni_putnici`, `dugovi_putnici`, `mesecne_karte`, `kilometraza`, `automatski_generisan`, `created_at`, `updated_at`

Usage in code:
- `daily_reports` is used by reporting services and UI (statistics). Keep all columns; consider adding `statistics` JSONB if you want flexible extra metrics.

## Cross-table notes
- Ensure `cena` column type is consistent across tables (`numeric` recommended). We created `cena_numeric` to start a migration path — unify naming and update app mapping.
- Index suggestions (already added in migrations):
  - GIN on `polasci_po_danu` (jsonb)
  - GIN on `statistics` (jsonb)
  - GIN on `radni_dani_arr` (text[])
  - Index on `putovanja_istorija(datum, vreme_polaska)` and `putovanja_istorija(mesecni_putnik_id)`

## Action plan (recommended immediate steps)
1. Run `migrations/002`..`005` on staging to ensure no runtime errors.
2. Verify `polasci_po_danu` populated count: `SELECT count(*) FROM mesecni_putnici WHERE polasci_po_danu IS NULL OR polasci_po_danu = '{}';` — aim for 0 before dropping legacy.
3. Verify `radni_dani_arr` similarly.
4. Once verified, plan a small migration to DROP `polazak_*` and optionally `radni_dani`.
5. Update client code to consistently write `cena` as numeric (or `cena_numeric`) and populate `statistics` gradually when events occur.

---
If you want, I can now:
- run a deeper scan of `lib/services` to produce a CSV checklist per column with exact file/line usages; or
- prepare PowerShell commands to apply migrations immediately (no backup) — you said you don't want backups, I can prepare the commands but I will warn about risk.
