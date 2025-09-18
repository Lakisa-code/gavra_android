-- Migration: add statistics jsonb columns and GIN indexes
BEGIN;

ALTER TABLE IF EXISTS public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS statistics jsonb;

CREATE INDEX IF NOT EXISTS idx_mesecni_statistics_gin
  ON public.mesecni_putnici USING GIN (statistics);

ALTER TABLE IF EXISTS public.daily_reports
  ADD COLUMN IF NOT EXISTS statistics jsonb;

CREATE INDEX IF NOT EXISTS idx_daily_reports_statistics_gin
  ON public.daily_reports USING GIN (statistics);

COMMIT;
