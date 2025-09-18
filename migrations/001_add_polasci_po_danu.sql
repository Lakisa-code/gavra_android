-- Migration: add polasci_po_danu jsonb column and backfill from legacy columns
BEGIN;

ALTER TABLE IF EXISTS mesecni_putnici
    ADD COLUMN IF NOT EXISTS polasci_po_danu jsonb;

-- Backfill from legacy flat columns if present
UPDATE mesecni_putnici
SET polasci_po_danu = jsonb_build_object(
  'pon', jsonb_build_object('bc', NULLIF(polazak_bc_pon, ''), 'vs', NULLIF(polazak_vs_pon, '')),
  'uto', jsonb_build_object('bc', NULLIF(polazak_bc_uto, ''), 'vs', NULLIF(polazak_vs_uto, '')),
  'sre', jsonb_build_object('bc', NULLIF(polazak_bc_sre, ''), 'vs', NULLIF(polazak_vs_sre, '')),
  'cet', jsonb_build_object('bc', NULLIF(polazak_bc_cet, ''), 'vs', NULLIF(polazak_vs_cet, '')),
  'pet', jsonb_build_object('bc', NULLIF(polazak_bc_pet, ''), 'vs', NULLIF(polazak_vs_pet, ''))
)
WHERE polasci_po_danu IS NULL;

COMMIT;
