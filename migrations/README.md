Migrations — how to run
======================

This folder contains SQL migrations for the `mesecni_putnici` schema. Recommended order to run:

1. `010_normalize_polasci.sql` — normalize `polasci_po_danu` to empty JSON array where needed.
2. `011_create_index_radni_dani.sql` — create GIN index on `radni_dani_arr` (run as single statement).
3. `012_create_index_statistics.sql` — create GIN index on `statistics` (run as single statement).
4. `013_final_verify.sql` — run final verification and copy results back to the maintainer.

Recommended execution methods:

- Manual: copy/paste contents into Supabase SQL Editor and run each file in order (recommended).
- CI: use the included GitHub Actions workflow `.github/workflows/run-migrations.yml` and set a `DB_URL` secret in GitHub repository secrets. The workflow will run all SQL files in `migrations/` in sorted order.

Notes:
- Run each `CREATE INDEX CONCURRENTLY` statement as a single, standalone statement — do not wrap in transactions.
- Verify results after `013_final_verify.sql` before performing any destructive cleanup.
