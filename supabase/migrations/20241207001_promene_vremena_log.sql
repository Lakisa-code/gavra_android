-- ============================================
-- MIGRACIJA: Promene vremena log
-- Datum: 2024-12-07
-- Opis: Tabela za praćenje promena vremena (limit jednom dnevno)
-- ============================================

-- 1. Kreiranje tabele
CREATE TABLE IF NOT EXISTS promene_vremena_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  putnik_id TEXT NOT NULL,      -- ID putnika (UUID kao text)
  datum TEXT NOT NULL,          -- ISO datum (2024-12-07)
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(putnik_id, datum)      -- Jedan putnik može imati samo jednu promenu po danu
);

-- 2. RLS
ALTER TABLE promene_vremena_log ENABLE ROW LEVEL SECURITY;

-- Svi mogu čitati i pisati (za sada)
CREATE POLICY "promene_vremena_select_all"
ON promene_vremena_log FOR SELECT USING (true);

CREATE POLICY "promene_vremena_insert_all"
ON promene_vremena_log FOR INSERT WITH CHECK (true);

-- 3. Index za brže pretrage
CREATE INDEX IF NOT EXISTS idx_promene_vremena_putnik_datum 
ON promene_vremena_log(putnik_id, datum);

-- ============================================
-- KRAJ MIGRACIJE
-- ============================================
