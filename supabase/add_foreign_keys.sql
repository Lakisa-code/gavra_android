-- ==========================================
-- FOREIGN KEY CONSTRAINTS - GAVRA DATABASE
-- ==========================================

-- --------------------------------------------
-- 1. VOZNJE_LOG TABLE
-- --------------------------------------------

-- Indexes
CREATE INDEX IF NOT EXISTS idx_voznje_log_putnik_id ON voznje_log(putnik_id);
CREATE INDEX IF NOT EXISTS idx_voznje_log_vozac_id ON voznje_log(vozac_id);
CREATE INDEX IF NOT EXISTS idx_voznje_log_adresa_id ON voznje_log(adresa_id);
CREATE INDEX IF NOT EXISTS idx_voznje_log_datum ON voznje_log(datum);
CREATE INDEX IF NOT EXISTS idx_voznje_log_vozac_datum ON voznje_log(vozac_id, datum);

-- Foreign Keys
ALTER TABLE voznje_log
ADD CONSTRAINT fk_voznje_log_putnik
FOREIGN KEY (putnik_id) 
REFERENCES registrovani_putnici(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE voznje_log
ADD CONSTRAINT fk_voznje_log_vozac
FOREIGN KEY (vozac_id)
REFERENCES vozaci(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE voznje_log
ADD CONSTRAINT fk_voznje_log_adresa
FOREIGN KEY (adresa_id)
REFERENCES adrese(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- --------------------------------------------
-- 2. SEAT_REQUESTS TABLE
-- --------------------------------------------

-- Indexes
CREATE INDEX IF NOT EXISTS idx_seat_requests_putnik_id ON seat_requests(putnik_id);
CREATE INDEX IF NOT EXISTS idx_seat_requests_vozac_id ON seat_requests(vozac_id);
CREATE INDEX IF NOT EXISTS idx_seat_requests_custom_adresa_id ON seat_requests(custom_adresa_id);
CREATE INDEX IF NOT EXISTS idx_seat_requests_datum ON seat_requests(datum);
CREATE INDEX IF NOT EXISTS idx_seat_requests_status ON seat_requests(status);

-- Foreign Keys
ALTER TABLE seat_requests
ADD CONSTRAINT fk_seat_requests_putnik
FOREIGN KEY (putnik_id) 
REFERENCES registrovani_putnici(id)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE seat_requests
ADD CONSTRAINT fk_seat_requests_vozac
FOREIGN KEY (vozac_id) 
REFERENCES vozaci(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE seat_requests
ADD CONSTRAINT fk_seat_requests_adresa
FOREIGN KEY (custom_adresa_id) 
REFERENCES adrese(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- --------------------------------------------
-- 3. REGISTROVANI_PUTNICI TABLE
-- --------------------------------------------

-- Indexes
CREATE INDEX IF NOT EXISTS idx_registrovani_putnici_vozac_id ON registrovani_putnici(vozac_id);
CREATE INDEX IF NOT EXISTS idx_registrovani_putnici_adresa_bc ON registrovani_putnici(adresa_bela_crkva_id);
CREATE INDEX IF NOT EXISTS idx_registrovani_putnici_adresa_vs ON registrovani_putnici(adresa_vrsac_id);
CREATE INDEX IF NOT EXISTS idx_registrovani_putnici_merged ON registrovani_putnici(merged_into_id);
CREATE INDEX IF NOT EXISTS idx_registrovani_putnici_aktivan ON registrovani_putnici(aktivan) WHERE aktivan = true;

-- Foreign Keys
ALTER TABLE registrovani_putnici
ADD CONSTRAINT fk_registrovani_putnici_vozac
FOREIGN KEY (vozac_id) 
REFERENCES vozaci(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE registrovani_putnici
ADD CONSTRAINT fk_registrovani_putnici_adresa_bc
FOREIGN KEY (adresa_bela_crkva_id) 
REFERENCES adrese(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE registrovani_putnici
ADD CONSTRAINT fk_registrovani_putnici_adresa_vs
FOREIGN KEY (adresa_vrsac_id) 
REFERENCES adrese(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE registrovani_putnici
ADD CONSTRAINT fk_registrovani_putnici_merged
FOREIGN KEY (merged_into_id) 
REFERENCES registrovani_putnici(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- --------------------------------------------
-- 4. PIN_ZAHTEVI TABLE
-- --------------------------------------------

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pin_zahtevi_putnik_id ON pin_zahtevi(putnik_id);
CREATE INDEX IF NOT EXISTS idx_pin_zahtevi_status ON pin_zahtevi(status);

-- Foreign Keys
ALTER TABLE pin_zahtevi
ADD CONSTRAINT fk_pin_zahtevi_putnik
FOREIGN KEY (putnik_id) 
REFERENCES registrovani_putnici(id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- ==========================================
-- VERIFIKACIJA
-- ==========================================

SELECT
    tc.table_name, 
    tc.constraint_name, 
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.table_name IN ('voznje_log', 'seat_requests', 'registrovani_putnici', 'pin_zahtevi')
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, tc.constraint_name;
