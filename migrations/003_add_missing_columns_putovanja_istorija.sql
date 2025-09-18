-- Migration: add missing columns and constraints to putovanja_istorija
BEGIN;

-- Add timestamp columns for canonical storage of times
ALTER TABLE IF EXISTS public.putovanja_istorija
  ADD COLUMN IF NOT EXISTS vreme_pokupljenja_ts timestamptz,
  ADD COLUMN IF NOT EXISTS vreme_placanja_ts timestamptz,
  ADD COLUMN IF NOT EXISTS cena_numeric numeric(12,2);

-- Backfill from existing textual time/price columns if present
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='putovanja_istorija' AND column_name='vreme_pokupljenja'
  ) THEN
    UPDATE public.putovanja_istorija
    SET vreme_pokupljenja_ts = NULLIF(trim(vreme_pokupljenja),'')::timestamptz
    WHERE vreme_pokupljenja_ts IS NULL AND vreme_pokupljenja IS NOT NULL AND trim(vreme_pokupljenja) <> '';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='putovanja_istorija' AND column_name='vreme_placanja'
  ) THEN
    UPDATE public.putovanja_istorija
    SET vreme_placanja_ts = NULLIF(trim(vreme_placanja),'')::timestamptz
    WHERE vreme_placanja_ts IS NULL AND vreme_placanja IS NOT NULL AND trim(vreme_placanja) <> '';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='putovanja_istorija' AND column_name='cena'
  ) THEN
    UPDATE public.putovanja_istorija
    SET cena_numeric = NULLIF(trim(cena),'')::numeric
    WHERE cena_numeric IS NULL AND cena IS NOT NULL AND trim(cena) <> '';
  END IF;
END$$;

-- Indexes commonly used by the app
CREATE INDEX IF NOT EXISTS idx_putovanja_mesecni_putnik_id ON public.putovanja_istorija (mesecni_putnik_id);
CREATE INDEX IF NOT EXISTS idx_putovanja_datum ON public.putovanja_istorija (datum);

-- Enforce non-negative prices (safe check)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_putovanja_cena_nonnegative') THEN
    ALTER TABLE public.putovanja_istorija
      ADD CONSTRAINT chk_putovanja_cena_nonnegative CHECK (cena_numeric IS NULL OR cena_numeric >= 0);
  END IF;
END$$;

COMMIT;
