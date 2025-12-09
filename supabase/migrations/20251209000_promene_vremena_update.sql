-- ============================================
-- MIGRACIJA: Ažuriranje promene_vremena_log tabele
-- Datum: 2025-12-09
-- Opis: Dodavanje ciljni_dan kolone za praćenje promena po danima
-- ============================================

-- 1. Dodaj kolonu ciljni_dan
ALTER TABLE promene_vremena_log ADD COLUMN IF NOT EXISTS ciljni_dan TEXT;

-- 2. Ukloni stari UNIQUE constraint (dozvoljavamo više promena po danu)
ALTER TABLE promene_vremena_log DROP CONSTRAINT IF EXISTS promene_vremena_log_putnik_id_datum_key;

-- 3. Dodaj novi index za pretragu
CREATE INDEX IF NOT EXISTS idx_promene_vremena_ciljni 
ON promene_vremena_log(putnik_id, datum, ciljni_dan);

-- ============================================
-- KRAJ MIGRACIJE
-- ============================================
