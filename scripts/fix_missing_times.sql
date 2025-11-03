-- 🚨 HITNO: SQL skript za dodavanje nedostajućih kolona za vremena polazaka
-- Datum: 2025-11-03
-- Problem: 56 mesečnih putnika nema vremena u polasci_po_danu koloni

-- FAZA 1: Dodaj kolone za vremena polazaka po danima
-- Bela Crkva vremena (bc)
ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_bc_pon TIME DEFAULT '06:00:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_bc_uto TIME DEFAULT '06:00:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_bc_sre TIME DEFAULT '06:00:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_bc_cet TIME DEFAULT '06:00:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_bc_pet TIME DEFAULT '06:00:00';

-- Vršac vremena (vs)
ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_vs_pon TIME DEFAULT '15:30:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_vs_uto TIME DEFAULT '15:30:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_vs_sre TIME DEFAULT '15:30:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_vs_cet TIME DEFAULT '15:30:00';

ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS polazak_vs_pet TIME DEFAULT '15:30:00';

-- FAZA 2: Ažuriraj postojeće putnike sa default vremenima
-- Postavi vremena za putnice koji imaju adresu u Beloj Crkvi
UPDATE mesecni_putnici 
SET polasci_po_danu = jsonb_build_object(
    'pon', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
    'uto', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
    'sre', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
    'cet', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
    'pet', jsonb_build_object('bc', '06:00', 'vs', '15:30')
)
WHERE aktivan = true 
AND obrisan = false 
AND polasci_po_danu = '{}'::jsonb
AND (adresa_bela_crkva IS NOT NULL OR adresa_vrsac IS NOT NULL);

-- FAZA 3: Ažuriraj putnice koji nemaju adrese (dodeli default Bela Crkva)
UPDATE mesecni_putnici 
SET adresa_bela_crkva = 'Centar',
    polasci_po_danu = jsonb_build_object(
        'pon', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
        'uto', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
        'sre', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
        'cet', jsonb_build_object('bc', '06:00', 'vs', '15:30'),
        'pet', jsonb_build_object('bc', '06:00', 'vs', '15:30')
    )
WHERE aktivan = true 
AND obrisan = false 
AND polasci_po_danu = '{}'::jsonb
AND adresa_bela_crkva IS NULL 
AND adresa_vrsac IS NULL;

-- VERIFIKACIJA: Proveri koliko putnika još uvek nema vremena
SELECT 
    COUNT(*) as ukupno_putnika,
    COUNT(CASE WHEN polasci_po_danu = '{}'::jsonb THEN 1 END) as bez_vremena,
    COUNT(CASE WHEN adresa_bela_crkva IS NULL AND adresa_vrsac IS NULL THEN 1 END) as bez_adrese
FROM mesecni_putnici 
WHERE aktivan = true AND obrisan = false;