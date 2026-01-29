-- =====================================================
-- TEST SKRIPTE ZA admin_audit_logs TABELU
-- Datum: 28.01.2026
-- =====================================================

-- TEST 1: Provera da li tabela postoji
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'admin_audit_logs'
) as "tabela_postoji";

-- TEST 2: Prikazi sve kolone
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'admin_audit_logs'
ORDER BY ordinal_position;

-- TEST 3: Broj redova
SELECT COUNT(*) as "broj_redova" FROM admin_audit_logs;

-- TEST 4: Čitaj poslednje 5 akcija
SELECT * FROM admin_audit_logs 
ORDER BY created_at DESC 
LIMIT 5;

-- TEST 5: Statistika po action_type
SELECT 
    action_type,
    COUNT(*) as "broj_akcija",
    COUNT(DISTINCT admin_name) as "admin_count",
    MIN(created_at) as "prvi_log",
    MAX(created_at) as "poslednji_log"
FROM admin_audit_logs
GROUP BY action_type
ORDER BY COUNT(*) DESC;

-- TEST 6: Statistika po admin_name
SELECT 
    admin_name,
    COUNT(*) as "broj_akcija",
    COUNT(DISTINCT action_type) as "tip_akcija",
    MIN(created_at) as "prva_akcija",
    MAX(created_at) as "poslednja_akcija"
FROM admin_audit_logs
GROUP BY admin_name
ORDER BY COUNT(*) DESC;

-- TEST 7: Vremenski pregled
SELECT 
    DATE(created_at) as "datum",
    COUNT(*) as "broj_akcija",
    COUNT(DISTINCT action_type) as "tip_akcija"
FROM admin_audit_logs
GROUP BY DATE(created_at)
ORDER BY DATE(created_at) DESC;

-- TEST 8: Pretraži po action_type
SELECT 
    id,
    created_at,
    admin_name,
    action_type,
    details
FROM admin_audit_logs
WHERE action_type = 'promena_kapaciteta'
ORDER BY created_at DESC
LIMIT 10;

-- TEST 9: Pretraži po admin_name
SELECT 
    id,
    created_at,
    admin_name,
    action_type,
    details
FROM admin_audit_logs
WHERE admin_name = 'Bojan'
ORDER BY created_at DESC
LIMIT 10;

-- TEST 10: Provera NULL vrednosti
SELECT 
    COUNT(*) as "ukupno_redova",
    COUNT(CASE WHEN id IS NULL THEN 1 END) as "null_id",
    COUNT(CASE WHEN admin_name IS NULL THEN 1 END) as "null_admin_name",
    COUNT(CASE WHEN action_type IS NULL THEN 1 END) as "null_action_type",
    COUNT(CASE WHEN details IS NULL THEN 1 END) as "null_details",
    COUNT(CASE WHEN metadata IS NULL THEN 1 END) as "null_metadata"
FROM admin_audit_logs;

-- TEST 11: Provera tipova podataka
SELECT 
    column_name,
    data_type,
    udt_name,
    is_nullable::TEXT
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'admin_audit_logs'
ORDER BY ordinal_position;

-- TEST 12: JSONB metadata analiza
SELECT 
    id,
    created_at,
    admin_name,
    action_type,
    jsonb_pretty(metadata) as "metadata_formatted"
FROM admin_audit_logs
WHERE metadata IS NOT NULL
LIMIT 3;

-- TEST 13: Vremenski raspon
SELECT 
    MIN(created_at) as "prvi_log",
    MAX(created_at) as "poslednji_log",
    (MAX(created_at) - MIN(created_at)) as "raspon",
    COUNT(*) as "broj_redova_u_rasponu"
FROM admin_audit_logs;

-- TEST 14: Distribucija akcija
SELECT 
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM admin_audit_logs), 2) as "procenat",
    action_type,
    COUNT(*) as "broj_akcija"
FROM admin_audit_logs
GROUP BY action_type
ORDER BY COUNT(*) DESC;

-- TEST 15: Pretraga po detaljima
SELECT 
    id,
    created_at,
    admin_name,
    action_type,
    details
FROM admin_audit_logs
WHERE details LIKE '%kapacitet%'
ORDER BY created_at DESC
LIMIT 5;

-- TEST 16: Provera veličine tabele
SELECT 
    pg_size_pretty(pg_total_relation_size('admin_audit_logs')) as "ukupna_veličina_tabele",
    pg_size_pretty(pg_relation_size('admin_audit_logs')) as "veličina_podataka",
    pg_size_pretty(pg_indexes_size('admin_audit_logs')) as "veličina_indeksa";

-- TEST 17: Provera indexa
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as "broj_koriscenja"
FROM pg_indexes
WHERE tablename = 'admin_audit_logs'
UNION ALL
SELECT 
    'Status' as schemaname,
    'admin_audit_logs' as tablename,
    CASE WHEN COUNT(*) = 0 THEN 'Nema indeksa' ELSE 'Indeksi postoje' END as indexname,
    COUNT(*) as broj_koriscenja
FROM pg_indexes
WHERE tablename = 'admin_audit_logs'
GROUP BY tablename;

-- TEST 18: Analiza metadata strukture
SELECT 
    jsonb_object_keys(metadata) as "metadata_keys",
    COUNT(*) as "broj_koriscenja"
FROM admin_audit_logs
WHERE metadata IS NOT NULL
GROUP BY jsonb_object_keys(metadata)
ORDER BY COUNT(*) DESC;

-- TEST 19: Performance test - brzo čitanje
EXPLAIN ANALYZE
SELECT * FROM admin_audit_logs 
WHERE action_type = 'promena_kapaciteta'
ORDER BY created_at DESC
LIMIT 10;

-- TEST 20: Finalna provera - sve je OK?
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Redovi postoje'
        ELSE '❌ Nema redova'
    END as test_1,
    CASE 
        WHEN (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'admin_audit_logs') = 6 THEN '✅ 6 KOLONA POSTOJI'
        ELSE '❌ BROJ KOLONA JE NETAČAN'
    END as test_2,
    CASE 
        WHEN COUNT(CASE WHEN admin_name IS NOT NULL THEN 1 END) = COUNT(*) THEN '✅ SVI ADMINI POPUNJENI'
        ELSE '❌ NEKI ADMINI NEDOSTAJU'
    END as test_3,
    CASE 
        WHEN COUNT(CASE WHEN action_type IS NOT NULL THEN 1 END) = COUNT(*) THEN '✅ SVI TIPOVI POPUNJENI'
        ELSE '❌ NEKI TIPOVI NEDOSTAJU'
    END as test_4
FROM admin_audit_logs;
