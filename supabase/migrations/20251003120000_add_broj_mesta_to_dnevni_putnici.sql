-- ================================================
-- GAVRA ANDROID - ADD BROJ_MESTA COLUMN
-- Migration: 20251003120000
-- Dodaje broj_mesta kolonu u dnevni_putnici tabelu
-- ================================================

-- Dodaj broj_mesta kolonu u dnevni_putnici tabelu
ALTER TABLE public.dnevni_putnici ADD COLUMN IF NOT EXISTS broj_mesta integer DEFAULT 1;

-- Dodaj indeks za performanse
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_broj_mesta ON public.dnevni_putnici(broj_mesta);

-- Migration completed successfully