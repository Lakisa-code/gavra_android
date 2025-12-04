-- Migracija: Dodavanje kolone 'boja' u tabelu vozaci
-- Datum: 2024-12-02
-- Opis: Omogućava dinamičko učitavanje boja za vozače iz baze podataka

-- Dodaj kolonu boja (hex format, npr. #FF0000)
ALTER TABLE vozaci ADD COLUMN IF NOT EXISTS boja VARCHAR(7);

-- Postavi postojeće boje za vozače (iz VozacBoja.boje konstanti)
UPDATE vozaci SET boja = '#7C4DFF' WHERE ime = 'Bruda';      -- ljubičasta
UPDATE vozaci SET boja = '#FF9800' WHERE ime = 'Bilevski';   -- narandžasta
UPDATE vozaci SET boja = '#00E5FF' WHERE ime = 'Bojan';      -- svetla cyan plava
UPDATE vozaci SET boja = '#FF1493' WHERE ime = 'Svetlana';   -- deep pink
UPDATE vozaci SET boja = '#8B4513' WHERE ime = 'Vlajic';     -- braon

-- Komentar za buduće vozače:
-- Kada se doda novi vozač, potrebno je postaviti boju u formatu #RRGGBB
