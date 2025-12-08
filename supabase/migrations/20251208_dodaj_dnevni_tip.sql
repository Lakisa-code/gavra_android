-- Migracija: Dodavanje 'dnevni' u dozvoljene tipove putnika
-- Datum: 2025-12-08
-- Opis: Ažurira CHECK constraint za kolonu 'tip' u tabeli mesecni_putnici da uključi 'dnevni'

-- 1. Ukloni stari constraint
ALTER TABLE mesecni_putnici DROP CONSTRAINT IF EXISTS check_tip_values;

-- 2. Dodaj novi constraint sa tri dozvoljene vrednosti
ALTER TABLE mesecni_putnici ADD CONSTRAINT check_tip_values 
  CHECK (tip IN ('radnik', 'ucenik', 'dnevni'));

-- Komentar za dokumentaciju
COMMENT ON COLUMN mesecni_putnici.tip IS 'Tip putnika: radnik (700 RSD/dan), ucenik (600 RSD/dan), dnevni (po dogovoru)';
