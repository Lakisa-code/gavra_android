-- Migration: status NOT NULL DEFAULT 'aktivan', treba_racun, broj_mesta NOT NULL DEFAULT 1
-- Tabele: v2_radnici, v2_ucenici, v2_dnevni, v2_posiljke
-- Datum: 2026-02-28

-- ─────────────────────────────────────────────
-- v2_radnici
-- ─────────────────────────────────────────────
ALTER TABLE public.v2_radnici
  ALTER COLUMN status SET DEFAULT 'aktivan',
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN broj_mesta SET DEFAULT 1,
  ALTER COLUMN broj_mesta SET NOT NULL,
  ADD COLUMN IF NOT EXISTS treba_racun boolean NOT NULL DEFAULT false;

-- Popuni NULL status vrednosti pre NOT NULL constraint-a
UPDATE public.v2_radnici SET status = 'aktivan' WHERE status IS NULL;
UPDATE public.v2_radnici SET broj_mesta = 1 WHERE broj_mesta IS NULL;

-- ─────────────────────────────────────────────
-- v2_ucenici
-- ─────────────────────────────────────────────
ALTER TABLE public.v2_ucenici
  ALTER COLUMN status SET DEFAULT 'aktivan',
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN broj_mesta SET DEFAULT 1,
  ALTER COLUMN broj_mesta SET NOT NULL,
  ADD COLUMN IF NOT EXISTS treba_racun boolean NOT NULL DEFAULT false;

UPDATE public.v2_ucenici SET status = 'aktivan' WHERE status IS NULL;
UPDATE public.v2_ucenici SET broj_mesta = 1 WHERE broj_mesta IS NULL;

-- ─────────────────────────────────────────────
-- v2_dnevni
-- ─────────────────────────────────────────────
ALTER TABLE public.v2_dnevni
  ALTER COLUMN status SET DEFAULT 'aktivan',
  ALTER COLUMN status SET NOT NULL,
  ADD COLUMN IF NOT EXISTS treba_racun boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS broj_mesta  int     NOT NULL DEFAULT 1;

UPDATE public.v2_dnevni SET status = 'aktivan' WHERE status IS NULL;

-- ─────────────────────────────────────────────
-- v2_posiljke  (nema broj_mesta — posiljke ne zauzimaju mesta)
-- ─────────────────────────────────────────────
ALTER TABLE public.v2_posiljke
  ALTER COLUMN status SET DEFAULT 'aktivan',
  ALTER COLUMN status SET NOT NULL,
  ADD COLUMN IF NOT EXISTS treba_racun boolean NOT NULL DEFAULT false;

UPDATE public.v2_posiljke SET status = 'aktivan' WHERE status IS NULL;
