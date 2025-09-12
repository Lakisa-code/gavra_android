-- Dodaj kolonu za dnevne pazare u daily_checkins tabelu
ALTER TABLE daily_checkins 
ADD COLUMN dnevni_pazari DECIMAL(10,2) DEFAULT 0.00;

-- Dodaj komentar za novu kolonu
COMMENT ON COLUMN daily_checkins.dnevni_pazari IS 'Iznos dnevnih pazara u RSD';
