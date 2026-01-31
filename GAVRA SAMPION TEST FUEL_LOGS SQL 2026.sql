-- =====================================================
-- GAVRA SAMPION TEST FUEL_LOGS SQL 2026
-- Testovi za fuel_logs tabelu
-- Datum: 31.01.2026
-- =====================================================

-- TEST 1: Provera da li tabela postoji
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'fuel_logs'
) as "tabela_postoji";

-- TEST 2: Prikazi sve kolone
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'fuel_logs'
ORDER BY ordinal_position;

-- TEST 3: Broj redova (treba biti 0 jer je nova tabela)
SELECT COUNT(*) as "broj_redova" FROM fuel_logs;

-- TEST 4: Provera constraints
SELECT
    conname as "constraint_name",
    contype as "constraint_type",
    conkey as "constraint_keys",
    confkey as "foreign_keys"
FROM pg_constraint
WHERE conrelid = 'fuel_logs'::regclass;

-- TEST 5: Provera foreign key ka vozila
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'fuel_logs';

-- TEST 6: Test insert validnih podataka
INSERT INTO fuel_logs (type, liters, price, amount, vozilo_uuid, km, pump_meter)
VALUES ('USAGE', 45.50, 180.00, 8190.00, (SELECT id FROM vozila LIMIT 1), 125000.50, 98765.25)
RETURNING id, created_at, type, liters, price, amount;

-- TEST 7: Test insert svih tipova
INSERT INTO fuel_logs (type, liters, price, amount, vozilo_uuid, km, pump_meter) VALUES
('BILL', 50.00, 175.00, 8750.00, (SELECT id FROM vozila LIMIT 1), 125050.00, 98770.00),
('PAYMENT', NULL, NULL, 8750.00, (SELECT id FROM vozila LIMIT 1), NULL, NULL),
('CALIBRATION', NULL, NULL, NULL, (SELECT id FROM vozila LIMIT 1), 125050.00, 98770.00);

-- TEST 8: Provera unetih podataka
SELECT id, created_at, type, liters, price, amount, vozilo_uuid, km, pump_meter
FROM fuel_logs
ORDER BY created_at DESC;

-- TEST 9: Test CHECK constraint za type
-- Ovo treba da fail-uje
-- INSERT INTO fuel_logs (type) VALUES ('INVALID_TYPE');

-- TEST 10: Provera realtime publication
SELECT
    pubname as "publication_name",
    schemaname as "schema_name",
    tablename as "table_name"
FROM pg_publication_tables
WHERE tablename = 'fuel_logs';

-- TEST 11: Čišćenje test podataka
DELETE FROM fuel_logs WHERE type IN ('USAGE', 'BILL', 'PAYMENT', 'CALIBRATION');

-- TEST 12: Finalni broj redova (treba biti 0)
SELECT COUNT(*) as "final_broj_redova" FROM fuel_logs;