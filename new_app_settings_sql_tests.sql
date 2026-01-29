-- =====================================================
-- NOVI SQL TESTOVI ZA app_settings TABELU
-- Kreirano od strane GitHub Copilot - Januar 2026
-- =====================================================

-- TEST 1: Osnovne informacije o tabeli
SELECT
    'app_settings' as table_name,
    COUNT(*) as total_settings,
    MAX(updated_at) as last_update,
    MIN(updated_at) as first_update,
    COUNT(CASE WHEN updated_by IS NOT NULL THEN 1 END) as settings_with_user
FROM app_settings;

-- TEST 2: Struktura tabele
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE
        WHEN column_name = 'id' THEN 'PRIMARY_KEY'
        WHEN column_name IN ('min_version', 'latest_version', 'store_url_android', 'store_url_huawei') THEN 'CRITICAL'
        WHEN column_name IN ('nav_bar_type', 'dnevni_zakazivanje_aktivno') THEN 'FEATURE_CONFIG'
        ELSE 'OPTIONAL'
    END as column_category
FROM information_schema.columns
WHERE table_name = 'app_settings'
ORDER BY ordinal_position;

-- TEST 3: Prikaz globalnih postavki
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

-- TEST 4: Validacija verzija
SELECT
    'Version Validation' as validation_type,
    min_version,
    latest_version,
    CASE
        WHEN min_version ~ '^\d+\.\d+\.\d+$' AND latest_version ~ '^\d+\.\d+\.\d+$' THEN 'VALID_FORMAT'
        ELSE 'INVALID_FORMAT'
    END as format_check,
    CASE
        WHEN string_to_array(latest_version, '.')::int[] >= string_to_array(min_version, '.')::int[] THEN 'VERSION_ORDER_OK'
        ELSE 'VERSION_ORDER_ERROR'
    END as version_order,
    CASE
        WHEN latest_version = min_version THEN 'SAME_VERSION'
        WHEN latest_version > min_version THEN 'LATEST_NEWER'
        ELSE 'MIN_NEWER'
    END as version_comparison
FROM app_settings;

-- TEST 5: Validacija store URL-ova
SELECT
    'Store URL Validation' as validation_type,
    CASE
        WHEN store_url_android LIKE 'https://play.google.com/store/apps/details?id=%' THEN 'ANDROID_URL_OK'
        ELSE 'ANDROID_URL_INVALID'
    END as android_url_status,
    CASE
        WHEN store_url_huawei LIKE 'appmarket://details?id=%' THEN 'HUAWEI_URL_OK'
        ELSE 'HUAWEI_URL_INVALID'
    END as huawei_url_status,
    LENGTH(store_url_android) as android_url_length,
    LENGTH(store_url_huawei) as huawei_url_length,
    CASE
        WHEN store_url_android LIKE '%com.gavra013.gavra_android%' AND store_url_huawei LIKE '%com.gavra013.gavra_android%' THEN 'PACKAGE_ID_CONSISTENT'
        ELSE 'PACKAGE_ID_INCONSISTENT'
    END as package_consistency
FROM app_settings;

-- TEST 6: Analiza navigation bar konfiguracije
SELECT
    'Navbar Configuration' as config_type,
    nav_bar_type,
    CASE
        WHEN nav_bar_type IN ('zimski', 'letnji', 'auto') THEN 'VALID_TYPE'
        ELSE 'INVALID_TYPE'
    END as type_validation,
    CASE
        WHEN nav_bar_type = 'zimski' THEN 'WINTER_THEME'
        WHEN nav_bar_type = 'letnji' THEN 'SUMMER_THEME'
        WHEN nav_bar_type = 'auto' THEN 'AUTOMATIC_THEME'
        ELSE 'UNKNOWN_THEME'
    END as theme_description,
    dnevni_zakazivanje_aktivno as daily_scheduling_enabled
FROM app_settings;

-- TEST 7: Provera NULL vrednosti i integriteta
SELECT
    'Data Integrity Check' as check_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN id IS NULL THEN 1 END) as null_ids,
    COUNT(CASE WHEN min_version IS NULL THEN 1 END) as null_min_versions,
    COUNT(CASE WHEN latest_version IS NULL THEN 1 END) as null_latest_versions,
    COUNT(CASE WHEN store_url_android IS NULL THEN 1 END) as null_android_urls,
    COUNT(CASE WHEN store_url_huawei IS NULL THEN 1 END) as null_huawei_urls,
    CASE
        WHEN COUNT(CASE WHEN id IS NULL THEN 1 END) = 0 THEN 'ID_INTEGRITY_OK'
        ELSE 'ID_INTEGRITY_ISSUES'
    END as id_integrity,
    CASE
        WHEN COUNT(CASE WHEN min_version IS NULL THEN 1 END) = 0 AND COUNT(CASE WHEN latest_version IS NULL THEN 1 END) = 0 THEN 'VERSION_INTEGRITY_OK'
        ELSE 'VERSION_INTEGRITY_ISSUES'
    END as version_integrity
FROM app_settings;

-- TEST 8: Analiza vremenskih podataka
SELECT
    'Time Analysis' as analysis_type,
    updated_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 as days_since_update,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/3600 as hours_since_update,
    CASE
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 < 1 THEN 'UPDATED_TODAY'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 < 7 THEN 'UPDATED_THIS_WEEK'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 < 30 THEN 'UPDATED_THIS_MONTH'
        ELSE 'UPDATED_LONG_AGO'
    END as update_category,
    updated_by
FROM app_settings;

-- TEST 9: Feature flag analiza
SELECT
    'Feature Flags' as analysis_type,
    dnevni_zakazivanje_aktivno as daily_scheduling_flag,
    CASE
        WHEN dnevni_zakazivanje_aktivno = true THEN 'DAILY_SCHEDULING_ENABLED'
        WHEN dnevni_zakazivanje_aktivno = false THEN 'DAILY_SCHEDULING_DISABLED'
        ELSE 'DAILY_SCHEDULING_UNKNOWN'
    END as daily_scheduling_status,
    nav_bar_type as navbar_type,
    CASE
        WHEN nav_bar_type = 'auto' THEN 'AUTOMATIC_THEME_ENABLED'
        ELSE 'MANUAL_THEME_SET'
    END as theme_mode
FROM app_settings;

-- TEST 10: Performance i statistika
SELECT
    'Performance Stats' as stats_type,
    pg_size_pretty(pg_total_relation_size('app_settings')) as table_size,
    pg_size_pretty(pg_relation_size('app_settings')) as table_size_no_indexes,
    (SELECT COUNT(*) FROM app_settings) as record_count,
    CASE
        WHEN (SELECT COUNT(*) FROM app_settings) = 1 THEN 'SINGLETON_PATTERN_OK'
        ELSE 'MULTIPLE_RECORDS_WARNING'
    END as record_pattern,
    (SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'app_settings') as index_count
FROM app_settings;

-- TEST 11: Backup i recovery informacije
SELECT
    schemaname,
    tablename,
    tableowner,
    tablespace,
    hasindexes,
    hasrules,
    hastriggers,
    rowsecurity
FROM pg_tables
WHERE tablename = 'app_settings';

-- TEST 12: Konfiguraciona konzistentnost
SELECT
    'Configuration Consistency' as check_type,
    CASE
        WHEN min_version <= latest_version THEN 'VERSION_CONSISTENCY_OK'
        ELSE 'VERSION_CONSISTENCY_ERROR'
    END as version_consistency,
    CASE
        WHEN store_url_android IS NOT NULL AND store_url_huawei IS NOT NULL THEN 'STORE_URLS_COMPLETE'
        WHEN store_url_android IS NOT NULL OR store_url_huawei IS NOT NULL THEN 'STORE_URLS_PARTIAL'
        ELSE 'STORE_URLS_MISSING'
    END as store_url_completeness,
    CASE
        WHEN nav_bar_type IN ('zimski', 'letnji', 'auto') THEN 'NAVBAR_CONFIG_VALID'
        ELSE 'NAVBAR_CONFIG_INVALID'
    END as navbar_config_validity,
    CASE
        WHEN dnevni_zakazivanje_aktivno IN (true, false) THEN 'DAILY_SCHEDULING_VALID'
        ELSE 'DAILY_SCHEDULING_INVALID'
    END as daily_scheduling_validity
FROM app_settings;

-- TEST 13: Version comparison detalji
SELECT
    'Version Details' as details_type,
    min_version,
    latest_version,
    SPLIT_PART(min_version, '.', 1) as min_major,
    SPLIT_PART(min_version, '.', 2) as min_minor,
    SPLIT_PART(min_version, '.', 3) as min_patch,
    SPLIT_PART(latest_version, '.', 1) as latest_major,
    SPLIT_PART(latest_version, '.', 2) as latest_minor,
    SPLIT_PART(latest_version, '.', 3) as latest_patch,
    CASE
        WHEN latest_version > min_version THEN 'UPGRADE_AVAILABLE'
        WHEN latest_version = min_version THEN 'UP_TO_DATE'
        ELSE 'VERSION_ERROR'
    END as upgrade_status
FROM app_settings;

-- TEST 14: Store URL detaljna analiza
SELECT
    'Store URL Analysis' as analysis_type,
    SUBSTRING(store_url_android FROM 'id=([^&]+)') as android_package_id,
    SUBSTRING(store_url_huawei FROM 'id=([^&]+)') as huawei_package_id,
    CASE
        WHEN SUBSTRING(store_url_android FROM 'id=([^&]+)') = SUBSTRING(store_url_huawei FROM 'id=([^&]+)') THEN 'PACKAGE_IDS_MATCH'
        ELSE 'PACKAGE_IDS_DIFFER'
    END as package_id_consistency,
    CASE
        WHEN store_url_android LIKE '%play.google.com%' THEN 'GOOGLE_PLAY_URL'
        ELSE 'NON_GOOGLE_PLAY_URL'
    END as android_store_type,
    CASE
        WHEN store_url_huawei LIKE '%appmarket%' THEN 'HUAWEI_APPGALLERY_URL'
        ELSE 'NON_HUAWEI_URL'
    END as huawei_store_type
FROM app_settings;

-- TEST 15: Konfiguraciona preporuke
SELECT
    'Configuration Recommendations' as recommendation_type,
    CASE
        WHEN nav_bar_type = 'auto' THEN 'AUTO_THEME_RECOMMENDED'
        ELSE 'CONSIDER_AUTO_THEME'
    END as theme_recommendation,
    CASE
        WHEN dnevni_zakazivanje_aktivno = false THEN 'DAILY_SCHEDULING_CAN_BE_ENABLED'
        ELSE 'DAILY_SCHEDULING_ACTIVE'
    END as scheduling_recommendation,
    CASE
        WHEN latest_version > min_version THEN 'VERSION_UPGRADE_AVAILABLE'
        ELSE 'VERSIONS_IN_SYNC'
    END as version_recommendation,
    CASE
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 > 30 THEN 'SETTINGS_NEED_REVIEW'
        ELSE 'SETTINGS_RECENTLY_UPDATED'
    END as maintenance_recommendation
FROM app_settings;

-- TEST 16: Singleton pattern provera
SELECT
    'Singleton Pattern Check' as check_type,
    (SELECT COUNT(*) FROM app_settings) as total_records,
    CASE
        WHEN (SELECT COUNT(*) FROM app_settings) = 1 THEN 'SINGLETON_OK'
        WHEN (SELECT COUNT(*) FROM app_settings) > 1 THEN 'MULTIPLE_RECORDS_ERROR'
        ELSE 'NO_RECORDS_ERROR'
    END as singleton_status,
    CASE
        WHEN (SELECT COUNT(*) FROM app_settings WHERE id = 'global') = 1 THEN 'GLOBAL_RECORD_EXISTS'
        ELSE 'GLOBAL_RECORD_MISSING'
    END as global_record_status
FROM app_settings;

-- TEST 17: Data type validation
SELECT
    'Data Type Validation' as validation_type,
    pg_typeof(id) as id_type,
    pg_typeof(updated_at) as updated_at_type,
    pg_typeof(updated_by) as updated_by_type,
    pg_typeof(nav_bar_type) as nav_bar_type_type,
    pg_typeof(dnevni_zakazivanje_aktivno) as daily_scheduling_type,
    pg_typeof(min_version) as min_version_type,
    pg_typeof(latest_version) as latest_version_type,
    pg_typeof(store_url_android) as android_url_type,
    pg_typeof(store_url_huawei) as huawei_url_type
FROM app_settings;

-- TEST 18: Konfiguraciona bezbednost
SELECT
    'Security Check' as check_type,
    CASE
        WHEN store_url_android NOT LIKE '%javascript:%' AND store_url_android NOT LIKE '%data:%' THEN 'ANDROID_URL_SAFE'
        ELSE 'ANDROID_URL_SUSPICIOUS'
    END as android_url_security,
    CASE
        WHEN store_url_huawei NOT LIKE '%javascript:%' AND store_url_huawei NOT LIKE '%data:%' THEN 'HUAWEI_URL_SAFE'
        ELSE 'HUAWEI_URL_SUSPICIOUS'
    END as huawei_url_security,
    CASE
        WHEN min_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$' AND latest_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$' THEN 'VERSION_FORMAT_SAFE'
        ELSE 'VERSION_FORMAT_SUSPICIOUS'
    END as version_format_security
FROM app_settings;

-- TEST 19: Kompletan sistemski pregled
SELECT
    'SYSTEM OVERVIEW' as overview_type,
    (SELECT COUNT(*) FROM app_settings) as total_settings,
    (SELECT COUNT(*) FROM app_settings WHERE id = 'global') as global_settings,
    (SELECT COUNT(*) FROM app_settings WHERE min_version IS NOT NULL AND latest_version IS NOT NULL) as version_configured,
    (SELECT COUNT(*) FROM app_settings WHERE store_url_android IS NOT NULL AND store_url_huawei IS NOT NULL) as store_urls_configured,
    (SELECT EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(updated_at)))/86400 FROM app_settings) as days_since_last_update,
    CASE
        WHEN (SELECT COUNT(*) FROM app_settings WHERE id = 'global' AND min_version IS NOT NULL AND latest_version IS NOT NULL AND store_url_android IS NOT NULL AND store_url_huawei IS NOT NULL) = 1 THEN 'SYSTEM_FULLY_CONFIGURED'
        ELSE 'SYSTEM_NEEDS_CONFIGURATION'
    END as system_status
FROM app_settings;

-- TEST 20: Završni status provera
SELECT
    CASE WHEN (SELECT COUNT(*) FROM app_settings) > 0 THEN '✅ TABLE EXISTS' ELSE '❌ TABLE MISSING' END as table_status,
    CASE WHEN (SELECT COUNT(*) FROM app_settings WHERE id = 'global') = 1 THEN '✅ GLOBAL SETTINGS OK' ELSE '❌ GLOBAL SETTINGS ERROR' END as global_settings_status,
    CASE WHEN (SELECT COUNT(*) FROM app_settings WHERE min_version ~ '^\d+\.\d+\.\d+$' AND latest_version ~ '^\d+\.\d+\.\d+$') = 1 THEN '✅ VERSIONS VALID' ELSE '❌ VERSIONS INVALID' END as version_validation,
    CASE WHEN (SELECT COUNT(*) FROM app_settings WHERE store_url_android LIKE 'https://play.google.com%' AND store_url_huawei LIKE 'appmarket://%') = 1 THEN '✅ STORE URLS VALID' ELSE '❌ STORE URLS INVALID' END as store_url_validation,
    CASE WHEN (SELECT COUNT(*) FROM app_settings WHERE nav_bar_type IN ('zimski', 'letnji', 'auto')) = 1 THEN '✅ NAVBAR CONFIG OK' ELSE '❌ NAVBAR CONFIG ERROR' END as navbar_config_status,
    CASE WHEN (SELECT COUNT(*) FROM app_settings WHERE dnevni_zakazivanje_aktivno IN (true, false)) = 1 THEN '✅ DAILY SCHEDULING OK' ELSE '❌ DAILY SCHEDULING ERROR' END as daily_scheduling_status
FROM app_settings;