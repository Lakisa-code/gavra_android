-- Migration: create daily_checkins table
CREATE TABLE IF NOT EXISTS public.daily_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vozac text NOT NULL,
  datum date NOT NULL,
  kusur_iznos numeric DEFAULT 0,
  dnevni_pazari numeric DEFAULT 0,
  popis jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_checkins_vozn_datum ON public.daily_checkins (vozac, datum);
