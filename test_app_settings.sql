-- =====================================================
-- TEST SKRIPTE ZA app_settings TABELU
-- Datum: 28.01.2026
-- =====================================================

-- TEST 1: Provera da li tabela postoji
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'app_settings'
) as "tabela_postoji";

-- TEST 2: Prikazi sve kolone
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'app_settings'
ORDER BY ordinal_position;

-- TEST 3: Broj redova
SELECT COUNT(*) as "broj_redova" FROM app_settings;

-- TEST 4: Čitaj sve podatke
SELECT * FROM app_settings;

-- TEST 5: Proverim da li je 'global' red prisutan
SELECT EXISTS (
    SELECT 1 FROM app_settings WHERE id = 'global'
) as "global_postoji";

-- TEST 6: Detaljni pregled 'global' reda
SELECT 
    id,
    nav_bar_type,
    dnevni_zakazivanje_aktivno,
    min_version,
    latest_version,
    store_url_android,
    store_url_huawei,
    updated_at,
    updated_by
FROM app_settings
WHERE id = 'global';

-- TEST 7: Provera da li su URL-ovi validni
SELECT 
    store_url_android,
    store_url_huawei,
    LENGTH(store_url_android) as "android_length",
    LENGTH(store_url_huawei) as "huawei_length",
    store_url_android LIKE 'https://%' as "android_valid",
    store_url_huawei LIKE 'appmarket://%' as "huawei_valid"
FROM app_settings;

-- TEST 8: Provera verzija (semantic versioning format)
SELECT 
    min_version,
    latest_version,
    min_version ~ '^\d+\.\d+\.\d+$' as "min_version_format_ok",
    latest_version ~ '^\d+\.\d+\.\d+$' as "latest_version_format_ok"
FROM app_settings;

-- TEST 9: Proverite updated_at timestamp
SELECT 
    updated_at,
    updated_by,
    (NOW() - updated_at) as "vreme_od_poslednje_izmene",
    AGE(NOW(), updated_at) as "starost_podataka"
FROM app_settings
WHERE id = 'global';

-- TEST 10: Analiza svih vrednosti
SELECT 
    'id' as kolona, CAST(COUNT(DISTINCT id) AS TEXT) as broj_jedinstvenih
FROM app_settings
UNION ALL
SELECT 'nav_bar_type', CAST(COUNT(DISTINCT nav_bar_type) AS TEXT) FROM app_settings
UNION ALL
SELECT 'dnevni_zakazivanje_aktivno', CAST(COUNT(DISTINCT dnevni_zakazivanje_aktivno) AS TEXT) FROM app_settings;

-- TEST 11: Provera da li se koriste svi default-ovi
SELECT 
    id,
    CASE WHEN nav_bar_type = 'auto' THEN 'DEFAULT' ELSE nav_bar_type END as nav_bar_type_status,
    CASE WHEN dnevni_zakazivanje_aktivno = false THEN 'DEFAULT' ELSE 'CUSTOM' END as dnevni_status,
    CASE WHEN min_version = '1.0.0' THEN 'DEFAULT' ELSE 'CUSTOM' END as min_version_status,
    CASE WHEN latest_version = '1.0.0' THEN 'DEFAULT' ELSE 'CUSTOM' END as latest_version_status
FROM app_settings;

-- TEST 12: Simulacija UPDATE operacije (BEZ IZVRŠAVANJA)
-- OVAJ QUERY SE NE IZVRŠAVA - SAMO DEMONSTRACIJA
/*
BEGIN;
    UPDATE app_settings
    SET nav_bar_type = 'test_mode',
        updated_at = NOW(),
        updated_by = 'test_script'
    WHERE id = 'global';
    
    SELECT * FROM app_settings WHERE id = 'global';
ROLLBACK;
*/

-- TEST 13: Provera integrnosti podataka
SELECT 
    COUNT(*) as "ukupno_redova",
    COUNT(DISTINCT id) as "jedinstveni_id",
    COUNT(CASE WHEN id IS NOT NULL THEN 1 END) as "id_popunjen",
    COUNT(CASE WHEN updated_at IS NOT NULL THEN 1 END) as "updated_at_popunjen",
    COUNT(CASE WHEN nav_bar_type IS NOT NULL THEN 1 END) as "nav_bar_type_popunjen"
FROM app_settings;

-- TEST 14: Provera da li je tabela optimizovana
SELECT 
    schemaname,
    tablename,
    CASE WHEN indexname IS NOT NULL THEN 'Indeks postoji' ELSE 'NEMA INDEKSA' END as index_status
FROM pg_indexes
WHERE tablename = 'app_settings';

-- TEST 15: Provera veličine tabele
SELECT 
    pg_size_pretty(pg_total_relation_size('app_settings')) as "ukupna_veličina_tabele",
    pg_size_pretty(pg_relation_size('app_settings')) as "veličina_podataka",
    pg_size_pretty(pg_indexes_size('app_settings')) as "veličina_indeksa";

-- TEST 16: Provera tipova podataka (detaljno)
SELECT 
    column_name,
    data_type,
    udt_name,
    is_nullable::TEXT,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'app_settings'
ORDER BY ordinal_position;

-- TEST 17: Test sa LEFT JOIN-om na app_settings
SELECT 
    a.id,
    a.nav_bar_type,
    COALESCE(a.dnevni_zakazivanje_aktivno, false) as "dnevni_zakazivanje",
    a.min_version,
    a.latest_version
FROM app_settings a
WHERE a.id = 'global';

-- TEST 18: Provera da li su sve kolone dostupne za čitanje
SELECT *
FROM app_settings
LIMIT 1
OFFSET 0;

-- TEST 19: Provera redosleda kolona
SELECT column_name, ordinal_position
FROM information_schema.columns
WHERE table_name = 'app_settings'
ORDER BY ordinal_position;

-- TEST 20: Finalna provera - sve je OK?
SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM app_settings WHERE id = 'global') THEN '✅ GLOBALNI RED POSTOJI'
        ELSE '❌ GLOBALNI RED NEDOSTAJE'
    END as test_1,
    CASE 
        WHEN (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'app_settings') = 9 THEN '✅ 9 KOLONA POSTOJI'
        ELSE '❌ BROJ KOLONA JE NETAČAN'
    END as test_2,
    CASE 
        WHEN (SELECT COUNT(*) FROM app_settings) = 1 THEN '✅ SAMO JEDAN RED (SINGLETON)'
        ELSE '❌ VIŠE REDOVA NEGO ŠTO TREBA'
    END as test_3,
    CASE 
        WHEN (SELECT store_url_android FROM app_settings WHERE id = 'global') LIKE 'https://%' THEN '✅ ANDROID URL VALIDAN'
        ELSE '❌ ANDROID URL NEVALIDAN'
    END as test_4;
