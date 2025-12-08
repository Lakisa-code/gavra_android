-- Migracija: Dodavanje custom cene po danu za mesečne putnike
-- Datum: 2024-12-08
-- Opis: Omogućava ručno postavljanje cene po danu za određene putnike (kraće relacije itd.)

-- Dodaj kolonu cena_po_danu u mesecni_putnici tabelu
ALTER TABLE mesecni_putnici
ADD COLUMN IF NOT EXISTS cena_po_danu NUMERIC(10, 2) DEFAULT NULL;

-- Komentar za dokumentaciju
COMMENT ON COLUMN mesecni_putnici.cena_po_danu IS 'Custom cena po danu za putnika. Ako je NULL, koristi se default (700 RSD radnik, 600 RSD učenik). Za kraće relacije može biti npr. 200 RSD.';

-- Indeks za brže filtriranje putnika sa custom cenom
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_cena_po_danu 
ON mesecni_putnici(cena_po_danu) 
WHERE cena_po_danu IS NOT NULL;
