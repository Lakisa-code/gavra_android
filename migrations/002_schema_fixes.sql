-- Migration: schema fixes and cleanup
-- Adds safe columns, backfills radni_dani -> radni_dani_arr, creates indexes,
-- archives rows with status='nije_se_pojavio' from putovanja_istorija

BEGIN;

-- 1) Ensure `polasci_po_danu` exists (idempotent) on mesecni_putnici
ALTER TABLE IF EXISTS public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS polasci_po_danu jsonb;

-- 2) Add a new array column for radni_dani for safer querying (preserve legacy text)
ALTER TABLE IF EXISTS public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS radni_dani_arr text[];

-- Backfill radni_dani_arr from existing radni_dani text column when present
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'mesecni_putnici' AND column_name = 'radni_dani'
  ) THEN
    UPDATE public.mesecni_putnici
    SET radni_dani_arr = string_to_array(radni_dani, ',')
    WHERE radni_dani_arr IS NULL AND radni_dani IS NOT NULL AND radni_dani <> '';
  END IF;
END$$;

-- 3) Ensure `vozac` column exists (simple string-based solution for now)
ALTER TABLE IF EXISTS public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS vozac text;

-- 4) Ensure `cena_numeric` exists to store canonical numeric price without altering potentially unknown existing type
ALTER TABLE IF EXISTS public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS cena_numeric numeric(12,2);

DO $$
BEGIN
  -- Backfill cena_numeric from existing cena if the column exists and cena_numeric is NULL
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'mesecni_putnici' AND column_name = 'cena'
  ) THEN
    UPDATE public.mesecni_putnici
    SET cena_numeric = NULLIF(trim(cena), '')::numeric
    WHERE cena_numeric IS NULL AND cena IS NOT NULL AND trim(cena) <> '';
  END IF;
END$$;

-- 5) Create helpful indexes used by the app
CREATE INDEX IF NOT EXISTS idx_putovanja_mesecni_putnik_id ON public.putovanja_istorija (mesecni_putnik_id);
CREATE INDEX IF NOT EXISTS idx_putovanja_datum_vreme ON public.putovanja_istorija (datum, vreme_polaska);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_id ON public.mesecni_putnici (id);

-- 6) Add CHECK constraint for cena_numeric >= 0 (idempotent via pg_constraint check)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_mesecni_putnici_cena_nonnegative'
  ) THEN
    ALTER TABLE public.mesecni_putnici
      ADD CONSTRAINT chk_mesecni_putnici_cena_nonnegative CHECK (cena_numeric IS NULL OR cena_numeric >= 0);
  END IF;
END$$;

-- 7) Archive rows with status = 'nije_se_pojavio' from putovanja_istorija into an archive table, then delete from main table
-- Create archive table with same structure if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'putovanja_istorija_archive'
  ) THEN
    EXECUTE 'CREATE TABLE public.putovanja_istorija_archive (LIKE public.putovanja_istorija INCLUDING ALL)';
  END IF;

  -- Move rows to archive
  INSERT INTO public.putovanja_istorija_archive
  SELECT * FROM public.putovanja_istorija WHERE status = ''nije_se_pojavio'';

  -- Delete moved rows from main table
  DELETE FROM public.putovanja_istorija WHERE status = ''nije_se_pojavio'';
END$$;

-- 8) Ensure putovanja_istorija.mesecni_putnik_id is indexed (again, safe)
CREATE INDEX IF NOT EXISTS idx_putovanja_mesecni_putnik_id_unique ON public.putovanja_istorija (mesecni_putnik_id);

COMMIT;
