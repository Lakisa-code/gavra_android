-- 🔧 GAVRA Database Optimization Script
-- Datum: 2025-11-04
-- Cilj: Uklanjanje duplikata iz MESECNI_PUTNICI tabele

-- =====================================
-- KORAK 1: BACKUP
-- =====================================

-- Kreiranje backup tabele
CREATE TABLE IF NOT EXISTS mesecni_putnici_backup_20251104 AS 
SELECT * FROM mesecni_putnici;

-- Provera da li je backup kreiran
SELECT COUNT(*) as backup_count FROM mesecni_putnici_backup_20251104;

-- =====================================
-- KORAK 2: ANALIZA PODATAKA
-- =====================================

-- Proverava da li postoje problematični zapisi (ime/prezime bez putnik_ime)
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN putnik_ime IS NOT NULL AND putnik_ime != '' THEN 1 END) as has_putnik_ime,
    COUNT(CASE WHEN ime IS NOT NULL OR prezime IS NOT NULL THEN 1 END) as has_ime_prezime,
    COUNT(CASE WHEN (ime IS NOT NULL OR prezime IS NOT NULL) AND (putnik_ime IS NULL OR putnik_ime = '') THEN 1 END) as problematic_names
FROM mesecni_putnici;

-- Proverava datume
SELECT 
    COUNT(CASE WHEN datum_pocetka_meseca IS NOT NULL THEN 1 END) as has_pocetka_meseca,
    COUNT(CASE WHEN datum_kraja_meseca IS NOT NULL THEN 1 END) as has_kraja_meseca,
    COUNT(CASE WHEN datum_pocetka IS NOT NULL THEN 1 END) as has_pocetka,
    COUNT(CASE WHEN datum_kraja IS NOT NULL THEN 1 END) as has_kraja,
    COUNT(CASE WHEN (datum_pocetka IS NOT NULL OR datum_kraja IS NOT NULL) AND (datum_pocetka_meseca IS NULL OR datum_kraja_meseca IS NULL) THEN 1 END) as problematic_dates
FROM mesecni_putnici;

-- =====================================
-- KORAK 3: MIGRACIJA PODATAKA
-- =====================================

-- Prebaci podatke iz ime/prezime u putnik_ime (ako je potrebno)
UPDATE mesecni_putnici 
SET putnik_ime = TRIM(CONCAT(COALESCE(ime, ''), ' ', COALESCE(prezime, '')))
WHERE (putnik_ime IS NULL OR putnik_ime = '') 
  AND (ime IS NOT NULL OR prezime IS NOT NULL);

-- Prebaci podatke iz datum_pocetka u datum_pocetka_meseca (ako je potrebno)
UPDATE mesecni_putnici 
SET datum_pocetka_meseca = datum_pocetka
WHERE datum_pocetka_meseca IS NULL 
  AND datum_pocetka IS NOT NULL;

-- Prebaci podatke iz datum_kraja u datum_kraja_meseca (ako je potrebno)
UPDATE mesecni_putnici 
SET datum_kraja_meseca = datum_kraja
WHERE datum_kraja_meseca IS NULL 
  AND datum_kraja IS NOT NULL;

-- =====================================
-- KORAK 4: VALIDACIJA MIGRACIJE
-- =====================================

-- Proveri da li su svi podaci migrirani
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN putnik_ime IS NOT NULL AND putnik_ime != '' THEN 1 END) as valid_putnik_ime,
    COUNT(CASE WHEN datum_pocetka_meseca IS NOT NULL THEN 1 END) as valid_pocetka_meseca,
    COUNT(CASE WHEN datum_kraja_meseca IS NOT NULL THEN 1 END) as valid_kraja_meseca
FROM mesecni_putnici;

-- =====================================
-- KORAK 5: UKLANJANJE DUPLIKATA
-- =====================================

-- PAŽNJA: Ovo je DESTRUCTIVE operacija!
-- Izvršiti tek nakon validacije da su svi podaci migrirani

-- Uklanjanje duplikat kolona
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS ime;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS prezime;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS datum_pocetka;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS datum_kraja;

-- =====================================
-- KORAK 6: OPTIMIZACIJA INDEKSA
-- =====================================

-- Dodaj indekse za bolje performanse
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_putnik_ime 
ON mesecni_putnici(putnik_ime);

CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_datum_meseca 
ON mesecni_putnici(datum_pocetka_meseca, datum_kraja_meseca);

CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_status_aktivan 
ON mesecni_putnici(status) WHERE aktivan = true;

CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_vozac_aktivan 
ON mesecni_putnici(vozac_id) WHERE aktivan = true;

-- =====================================
-- KORAK 7: CLEANUP
-- =====================================

-- Ukloni prazne stringove
UPDATE mesecni_putnici 
SET putnik_ime = NULL 
WHERE putnik_ime = '';

UPDATE mesecni_putnici 
SET telefon = NULL 
WHERE telefon = '';

UPDATE mesecni_putnici 
SET tip_skole = NULL 
WHERE tip_skole = '';

-- =====================================
-- KORAK 8: VALIDACIJA FINALNE STRUKTURE
-- =====================================

-- Prikaži finalnu strukturu tabele
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'mesecni_putnici' 
ORDER BY ordinal_position;

-- Prikaži statistike
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT putnik_ime) as unique_putnici,
    COUNT(CASE WHEN aktivan = true THEN 1 END) as active_records,
    MIN(datum_pocetka_meseca) as earliest_date,
    MAX(datum_kraja_meseca) as latest_date
FROM mesecni_putnici;

-- =====================================
-- ROLLBACK PLAN (ako je potreban)
-- =====================================

/*
-- U slučaju problema, vratiti iz backup-a:

DROP TABLE IF EXISTS mesecni_putnici;
CREATE TABLE mesecni_putnici AS 
SELECT * FROM mesecni_putnici_backup_20251104;

-- Kreirati ponovo primary key i constraints
ALTER TABLE mesecni_putnici ADD PRIMARY KEY (id);
-- Dodati ostale constraints prema potrebi
*/

-- =====================================
-- KRAJ SKRIPTE
-- =====================================

SELECT 'Database optimization completed successfully!' as status;