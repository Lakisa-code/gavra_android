-- =====================================================
-- 🚀 BRZA SQL ANALIZA SVIH 30 SUPABASE TABELA
-- 📅 Januar 29, 2026
-- =====================================================

-- Brza analiza svih tabela - osnovne statistike
SELECT
    'ANALIZA SVIH TABELA - OSNOVNE STATISTIKE' as analysis_type,
    CURRENT_TIMESTAMP as vreme_analize;

-- 1. ADMIN_AUDIT_LOGS
SELECT 'admin_audit_logs' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT admin_name) as jedinstveni_admini,
       MIN(created_at) as najstariji, MAX(created_at) as najnoviji
FROM admin_audit_logs;

-- 2. ADRESE
SELECT 'adrese' as tabela, COUNT(*) as ukupno_redova,
       COUNT(CASE WHEN koordinate IS NOT NULL THEN 1 END) as sa_koord,
       COUNT(CASE WHEN koordinate IS NULL THEN 1 END) as bez_koord
FROM adrese;

-- 3. APP_CONFIG
SELECT 'app_config' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT key) as jedinstveni_key
FROM app_config;

-- 4. APP_SETTINGS
SELECT 'app_settings' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT key) as jedinstveni_key
FROM app_settings;

-- 5. DAILY_REPORTS
SELECT 'daily_reports' as tabela, COUNT(*) as ukupno_redova,
       SUM(COALESCE(pokupljeni_putnici, 0)) as ukupno_pokupljeni,
       SUM(COALESCE(naplaceni_putnici, 0)) as ukupno_naplaceni,
       SUM(COALESCE(ukupan_pazar, 0)) as ukupan_pazar
FROM daily_reports;

-- 6. FINANSIJE_LICNO
SELECT 'finansije_licno' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_id) as vozaci,
       SUM(COALESCE(iznos, 0)) as ukupan_iznos
FROM finansije_licno;

-- 7. FINANSIJE_TROSKOVI
SELECT 'finansije_troskovi' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_id) as vozaci,
       SUM(COALESCE(iznos, 0)) as ukupan_iznos
FROM finansije_troskovi;

-- 8. FUEL_LOGS
SELECT 'fuel_logs' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozilo_id) as vozila,
       SUM(COALESCE(litara, 0)) as ukupno_litara
FROM fuel_logs;

-- 9. KAPACITET_POLAZAKA
SELECT 'kapacitet_polazaka' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT ruta) as rute
FROM kapacitet_polazaka;

-- 10. ML_CONFIG
SELECT 'ml_config' as tabela, COUNT(*) as ukupno_redova,
        COUNT(DISTINCT model_name) as modeli
FROM ml_config;

-- 11. PAYMENT_REMINDERS_LOG
SELECT 'payment_reminders_log' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT putnik_id) as putnici
FROM payment_reminders_log;

-- 12. PENDING_RESOLUTION_QUEUE - TABLE REMOVED
-- SELECT 'pending_resolution_queue' as tabela, COUNT(*) as ukupno_redova,
--        COUNT(DISTINCT status) as statusi
-- FROM pending_resolution_queue;

-- 13. PIN_ZAHTEVI
SELECT 'pin_zahtevi' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT putnik_id) as putnici,
       COUNT(CASE WHEN odobren = true THEN 1 END) as odobreni
FROM pin_zahtevi;

-- 14. PROMENE_VREMENA_LOG
SELECT 'promene_vremena_log' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_id) as vozaci
FROM promene_vremena_log;

-- 15. PUSH_TOKENS
SELECT 'push_tokens' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT user_id) as korisnici
FROM push_tokens;

-- 16. PUTNIK_PICKUP_LOKACIJE
SELECT 'putnik_pickup_lokacije' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT putnik_id) as putnici
FROM putnik_pickup_lokacije;

-- 17. RACUN_SEQUENCE
SELECT 'racun_sequence' as tabela, COUNT(*) as ukupno_redova,
       MAX(COALESCE(broj_racuna, 0)) as max_broj_racuna
FROM racun_sequence;

-- 18. REGISTROVANI_PUTNICI
SELECT 'registrovani_putnici' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT email) as email_adrese,
       COUNT(DISTINCT broj_telefona) as telefoni,
       COUNT(DISTINCT tip) as tipovi
FROM registrovani_putnici;

-- 20. SEAT_REQUESTS
SELECT 'seat_requests' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT putnik_id) as putnici,
       COUNT(CASE WHEN status = 'approved' THEN 1 END) as odobreni,
       COUNT(CASE WHEN status = 'pending' THEN 1 END) as na_cekanju
FROM seat_requests;

-- 21. TROSKOVI_UNOSI
SELECT 'troskovi_unosi' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_id) as vozaci,
       SUM(COALESCE(iznos, 0)) as ukupan_iznos
FROM troskovi_unosi;

-- 22. USER_DAILY_CHANGES
SELECT 'user_daily_changes' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT user_id) as korisnici
FROM user_daily_changes;

-- 23. VOZAC_LOKACIJE
SELECT 'vozac_lokacije' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_id) as vozaci
FROM vozac_lokacije;

-- 24. VOZACI
SELECT 'vozaci' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT ime) as imena,
       COUNT(CASE WHEN aktivan = true THEN 1 END) as aktivni
FROM vozaci;

-- 25. VOZILA
SELECT 'vozila' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT registracija) as registracije,
       COUNT(CASE WHEN aktivno = true THEN 1 END) as aktivna
FROM vozila;

-- 26. VOZILA_ISTORIJA
SELECT 'vozila_istorija' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozilo_id) as vozila
FROM vozila_istorija;

-- 27. VOZNJE_LOG
SELECT 'voznje_log' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_id) as vozaci,
       COUNT(DISTINCT putnik_id) as putnici,
       SUM(COALESCE(iznos, 0)) as ukupan_iznos
FROM voznje_log;

-- 28. VOZNJE_LOG_WITH_NAMES
SELECT 'voznje_log_with_names' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_ime) as vozaci,
       COUNT(DISTINCT putnik_ime) as putnici
FROM voznje_log_with_names;

-- 29. VREME_VOZAC
SELECT 'vreme_vozac' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT vozac_id) as vozaci
FROM vreme_vozac;

-- 30. WEATHER_ALERTS_LOG
SELECT 'weather_alerts_log' as tabela, COUNT(*) as ukupno_redova,
       COUNT(DISTINCT alert_type) as tipovi_alerta
FROM weather_alerts_log;

-- SUMARNI IZVEŠTAJ
SELECT
    'UKUPNA STATISTIKA BAZE' as analiza,
    CURRENT_TIMESTAMP as vreme,
    (SELECT COUNT(*) FROM admin_audit_logs) +
    (SELECT COUNT(*) FROM adrese) +
    (SELECT COUNT(*) FROM app_config) +
    (SELECT COUNT(*) FROM app_settings) +
    (SELECT COUNT(*) FROM daily_reports) +
    (SELECT COUNT(*) FROM finansije_licno) +
    (SELECT COUNT(*) FROM finansije_troskovi) +
    (SELECT COUNT(*) FROM fuel_logs) +
    (SELECT COUNT(*) FROM kapacitet_polazaka) +
    (SELECT COUNT(*) FROM ml_config) +
    (SELECT COUNT(*) FROM payment_reminders_log) +
    -- (SELECT COUNT(*) FROM pending_resolution_queue) +  -- TABLE REMOVED
    (SELECT COUNT(*) FROM pin_zahtevi) +
    (SELECT COUNT(*) FROM promene_vremena_log) +
    (SELECT COUNT(*) FROM push_tokens) +
    (SELECT COUNT(*) FROM putnik_pickup_lokacije) +
    (SELECT COUNT(*) FROM racun_sequence) +
    (SELECT COUNT(*) FROM registrovani_putnici) +
    (SELECT COUNT(*) FROM seat_requests) +
    (SELECT COUNT(*) FROM troskovi_unosi) +
    (SELECT COUNT(*) FROM user_daily_changes) +
    (SELECT COUNT(*) FROM vozac_lokacije) +
    (SELECT COUNT(*) FROM vozaci) +
    (SELECT COUNT(*) FROM vozila) +
    (SELECT COUNT(*) FROM vozila_istorija) +
    (SELECT COUNT(*) FROM voznje_log) +
    (SELECT COUNT(*) FROM voznje_log_with_names) +
    (SELECT COUNT(*) FROM vreme_vozac) +
    (SELECT COUNT(*) FROM weather_alerts_log) as ukupno_redova_u_bazi;

-- ZAVRŠETAK ANALIZE
SELECT
    'ANALIZA ZAVRŠENA' as status,
    CURRENT_TIMESTAMP as vreme_zavrsetka,
    'Pokrenite ultra_detailed_sql_analyzer.sql za kompletnu analizu' as preporuka;</content>
<parameter name="filePath">c:\Users\Bojan\gavra_android\quick_database_analysis.sql