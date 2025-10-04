-- 📊 DODAJ ISTORIJU PLAĆANJA ZA MESEČNE PUTNIKE
-- ================================================
-- Datum: 2025-10-04
-- Svrha: Omogućiti čuvanje istorije svih plaćanja mesečnih putnika u putovanja_istorija tabeli

-- 1. DODAJ NEDOSTAJUĆE KOLONE U putovanja_istorija (ako nisu dodane u prethodnoj migraciji)
ALTER TABLE public.putovanja_istorija 
ADD COLUMN IF NOT EXISTS cena numeric DEFAULT 0.0;

ALTER TABLE public.putovanja_istorija 
ADD COLUMN IF NOT EXISTS tip_putnika character varying DEFAULT 'dnevni'::character varying;

ALTER TABLE public.putovanja_istorija 
ADD COLUMN IF NOT EXISTS putnik_ime character varying;

-- 2. DODAJ KOLONU ZA OZNAČAVANJE MESEČNIH PLAĆANJA
ALTER TABLE public.putovanja_istorija 
ADD COLUMN IF NOT EXISTS placeni_mesec integer;

ALTER TABLE public.putovanja_istorija 
ADD COLUMN IF NOT EXISTS placena_godina integer;

-- 3. DODAJ INDEKSE ZA BOLJE PERFORMANSE
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_tip_putnika ON public.putovanja_istorija(tip_putnika);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_putnik_ime ON public.putovanja_istorija(putnik_ime);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_cena ON public.putovanja_istorija(cena);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_mesec_godina ON public.putovanja_istorija(placeni_mesec, placena_godina);

-- 4. KOMENTAR ZA BUDUĆE REFERENCE
COMMENT ON COLUMN public.putovanja_istorija.tip_putnika IS 'Tip putnika: dnevni, mesecna_karta, regularni';
COMMENT ON COLUMN public.putovanja_istorija.cena IS 'Iznos plaćanja - za dnevne putnike cena po putovanju, za mesečne ukupna mesečna cena';
COMMENT ON COLUMN public.putovanja_istorija.placeni_mesec IS 'Mesec za koji je plaćeno (1-12) - samo za mesečne karte';
COMMENT ON COLUMN public.putovanja_istorija.placena_godina IS 'Godina za koju je plaćeno - samo za mesečne karte';