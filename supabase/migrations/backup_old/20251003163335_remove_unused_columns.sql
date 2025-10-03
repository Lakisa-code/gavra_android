-- ================================================
-- GAVRA ANDROID - REMOVE UNUSED COLUMNS
-- Migration: 20251003163335
-- Uklanja kolone koje se ne koriste u aplikaciji
-- ================================================

-- UKLANJANJE NEKORIŠĆENIH KOLONA IZ mesecni_putnici TABELE

-- Ukloni cena_mesecne_karte kolonu (nije se koristila nigde u kodu)
ALTER TABLE public.mesecni_putnici DROP COLUMN IF EXISTS cena_mesecne_karte;

-- Ukloni prezime kolonu (nije se koristila nigde u kodu)
ALTER TABLE public.mesecni_putnici DROP COLUMN IF EXISTS prezime;

-- Ukloni datum_pocetka kolonu (koristila se samo datum_pocetka_meseca)
ALTER TABLE public.mesecni_putnici DROP COLUMN IF EXISTS datum_pocetka;

-- Ukloni datum_kraja kolonu (koristila se samo datum_kraja_meseca)
ALTER TABLE public.mesecni_putnici DROP COLUMN IF EXISTS datum_kraja;

-- UKLANJANJE NEKORIŠĆENIH KOLONA IZ dnevni_putnici TABELE

-- Ukloni status_vreme kolonu (nije se koristila nigde u kodu)
ALTER TABLE public.dnevni_putnici DROP COLUMN IF EXISTS status_vreme;

-- Migration completed successfully
-- Uklonjeno: 5 nepotrebnih kolona
-- Optimizovano: smanjena veličina baze i pojednostavljeni modeli</content>
<parameter name="filePath">c:\Users\Bojan\gavra_android\supabase\migrations\20251003163335_remove_unused_columns.sql