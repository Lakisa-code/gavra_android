-- =====================================================
-- GAVRA SAMPION TEST ML_CONFIG SQL 2026
-- Testovi za ml_config tabelu
-- Datum: 31.01.2026
-- =====================================================

-- TEST 1: Provera da li tabela postoji
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'ml_config'
) as "tabela_postoji";

-- TEST 2: Prikazi sve kolone
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'ml_config'
ORDER BY ordinal_position;

-- TEST 3: Broj redova (treba biti 0 jer je nova tabela)
SELECT COUNT(*) as "broj_redova" FROM ml_config;

-- TEST 4: Provera constraints
SELECT
    conname as "constraint_name",
    contype as "constraint_type",
    conkey as "constraint_keys",
    confkey as "foreign_keys"
FROM pg_constraint
WHERE conrelid = 'ml_config'::regclass;

-- TEST 5: Test insert validnih podataka
INSERT INTO ml_config (model_name, model_version, parameters, accuracy_threshold, is_active)
VALUES
('passenger_prediction', 'v1.0.0', '{"learning_rate": 0.01, "epochs": 100, "batch_size": 32}', 0.8500, true),
('route_optimization', 'v2.1.0', '{"algorithm": "genetic", "population_size": 50, "generations": 100}', 0.9200, true),
('demand_forecasting', 'v1.5.0', '{"seasonal": true, "trend": "additive", "period": 7}', 0.7800, false),
('driver_behavior', 'v3.0.0', '{"features": ["speed", "breaks", "time"], "threshold": 0.75}', 0.8800, true)
RETURNING id, model_name, model_version, accuracy_threshold, is_active, created_at;

-- TEST 6: Provera unetih podataka
SELECT id, model_name, model_version, accuracy_threshold, is_active, created_at, updated_at
FROM ml_config
ORDER BY created_at DESC;

-- TEST 7: Test filtriranje aktivnih modela
SELECT model_name, model_version, accuracy_threshold
FROM ml_config
WHERE is_active = true
ORDER BY accuracy_threshold DESC;

-- TEST 8: Test JSONB parameters
SELECT
    model_name,
    parameters->>'learning_rate' as "learning_rate",
    parameters->>'algorithm' as "algorithm",
    parameters->>'features' as "features"
FROM ml_config
WHERE parameters IS NOT NULL;

-- TEST 9: Test statistika po verzijama
SELECT
    SUBSTRING(model_version FROM 1 FOR 1) as "major_version",
    COUNT(*) as "broj_modela",
    AVG(accuracy_threshold) as "prosecna_tacnost",
    MAX(accuracy_threshold) as "max_tacnost",
    MIN(accuracy_threshold) as "min_tacnost"
FROM ml_config
GROUP BY SUBSTRING(model_version FROM 1 FOR 1)
ORDER BY major_version;

-- TEST 10: Provera realtime publication
SELECT
    pubname as "publication_name",
    schemaname as "schema_name",
    tablename as "table_name"
FROM pg_publication_tables
WHERE tablename = 'ml_config';

-- TEST 11: Čišćenje test podataka
DELETE FROM ml_config;

-- TEST 12: Finalni broj redova (treba biti 0)
SELECT COUNT(*) as "final_broj_redova" FROM ml_config;