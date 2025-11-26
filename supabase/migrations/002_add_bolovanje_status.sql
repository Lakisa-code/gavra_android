-- 🏥 Dodavanje bolovanja i godišnjeg kao validnih statusa za mesečne putnike
-- Datum: 2025-11-26

-- 1. Obriši stari constraint
ALTER TABLE mesecni_putnici DROP CONSTRAINT IF EXISTS check_mesecni_status_valid;

-- 2. Dodaj novi constraint koji uključuje bolovanje i godišnji
ALTER TABLE mesecni_putnici ADD CONSTRAINT check_mesecni_status_valid 
CHECK (status IN ('aktivan', 'neaktivan', 'pauziran', 'radi', 'bolovanje', 'godišnji'));

-- 3. Vrati putnike koji su greškom deaktivirani
UPDATE mesecni_putnici 
SET aktivan = true, status = 'aktivan', napomena = NULL 
WHERE aktivan = false AND napomena LIKE '%BOLOVANJE%';

UPDATE mesecni_putnici 
SET aktivan = true, status = 'aktivan', napomena = NULL 
WHERE aktivan = false AND napomena LIKE '%GODIŠNJI%';
