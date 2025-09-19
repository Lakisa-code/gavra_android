## Column Mapping: `polazak_*` → canonical fields

Purpose: map legacy per-day columns present in SQL/CSV imports to the canonical columns used by the app and migrations, and list code locations that read/write the legacy columns.

- Canonical columns:
  - `polasci_po_danu` (jsonb): canonical schedule per day, shape: { "pon": {"bc": "06:00", "vs": "15:30"}, ... }
  - `radni_dani_arr` (text[]): canonical days-of-week array used by app queries
  - `cena_numeric` (numeric): canonical numeric price
  - `statistics` (jsonb): new aggregated stats column

- Legacy per-day columns (from imports / older dumps):
  - `polazak_bc_pon`, `polazak_bc_uto`, `polazak_bc_sre`, `polazak_bc_cet`, `polazak_bc_pet`
  - `polazak_vs_pon`, `polazak_vs_uto`, `polazak_vs_sre`, `polazak_vs_cet`, `polazak_vs_pet`

Where normalization/backfill happens:
- Migration: `migrations/001_add_polasci_po_danu.sql` — builds `polasci_po_danu` from the legacy per-day columns when present.
- Client: `lib/utils/mesecni_helpers.dart` — contains parsing/normalization helpers that accept either `polasci_po_danu` or legacy `polazak_*` fields.
- Client model: `lib/models/mesecni_putnik.dart` — factory/`toMap` normalizes `polasci_po_danu` and sets `statistics` when missing.

Code references (files that reference legacy `polazak_*` columns or include them in SQL strings):

- Services (DB queries / selects / csv imports):
  - `lib/services/putnik_service.dart` — multiple SQL select/insert strings that include `polazak_bc_*` and `polazak_vs_*` (notably near line ~1426). Also used when exporting sample rows.
  - `migrations/imports/mesecni_putnici_rows.sql` and `migrations/imports/mesecni_putnici_rows.csv` — import dumps include legacy columns in VALUES and headers.

- Notification / SMS / Local logic that mentions legacy fields in CSV/SQL lists:
  - `lib/services/sms_service.dart`
  - `lib/services/local_notification_service.dart`
  - `lib/services/putnik_service.dart` (also used for SMS/exports)

- UI / Screens:
  - `lib/screens/home_screen.dart` — includes legacy column lists in some export/CSV header strings.
  - `lib/screens/danas_screen.dart`

- Helpers & tests:
  - `lib/utils/mesecni_helpers.dart` — explicit comments and code paths handling both `polasci_po_danu` and legacy `polazak_*` fields.
  - `lib/models/mesecni_putnik.dart` — model normalization (factory + toMap).
  - Tests: `test/mesecni_helpers_test.dart`, `test/mesecni_putnik_test.dart` verify normalization behavior.

Quick safety notes and recommendations:
- Action order to safely remove legacy columns (high level):
  1. Ensure `polasci_po_danu` exists and is populated for all rows (backfill migration idempotently updates only NULLs).
  2. Update clients to stop writing legacy columns (client code now normalizes/uses canonical field). Deploy client update.
  3. Run verification queries comparing rows where legacy columns are non-empty vs `polasci_po_danu` presence. Use the supplied `migrations/run_archive_psql.ps1` to verify and optionally archive.
  4. Archive rows into `mesecni_putnici_legacy_archive` (non-destructive) and keep for a monitoring window (e.g., 2 weeks).
  5. After monitoring and verification, DROP legacy columns in a scheduled maintenance window.

- Files to change before DROP:
  - Replace any remaining SQL string literals that reference legacy columns (exports, CSV headers, raw SELECTs) with canonical field usage.
  - Confirm `putnik_service` and `sms_service` exports are updated to use `polasci_po_danu` when preparing CSVs or messages.

Next steps (suggested):
- Review this mapping and confirm which files you want updated to remove legacy column mentions (I can make those edits).  
- Optionally commit local client changes so remote includes canonical normalization.  
- When ready, run the verification script and archive step (`migrations/run_archive_psql.ps1`).

Generated: by automation (mapping based on repo grep results). Verify before destructive actions.
