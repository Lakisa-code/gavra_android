-- =====================================================
-- 🔍 ULTRA DETALJNE SQL ANALIZE SVIH 30 SUPABASE TABELA
-- 📅 Datum: Januar 29, 2026
-- Verzija: Ultra Detailed SQL Analysis v2.0
-- =====================================================

-- =====================================================
-- 1. ADMIN_AUDIT_LOGS - Detaljna analiza
-- =====================================================

-- 1.1 Osnovne informacije
SELECT
    'admin_audit_logs' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT admin_name) as unique_admins,
    COUNT(DISTINCT action_type) as unique_actions,
    MIN(created_at) as oldest_record,
    MAX(created_at) as newest_record,
    EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at)))/86400 as days_span
FROM admin_audit_logs;

-- 1.2 Analiza po adminima
SELECT
    admin_name,
    COUNT(*) as total_actions,
    COUNT(DISTINCT action_type) as unique_action_types,
    MIN(created_at) as first_action,
    MAX(created_at) as last_action,
    array_agg(DISTINCT action_type) as action_types
FROM admin_audit_logs
GROUP BY admin_name
ORDER BY total_actions DESC;

-- 1.3 Analiza po tipovima akcija
SELECT
    action_type,
    COUNT(*) as total_occurrences,
    COUNT(DISTINCT admin_name) as unique_admins,
    MIN(created_at) as first_occurrence,
    MAX(created_at) as last_occurrence,
    ROUND(AVG(EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER (ORDER BY created_at)))) / 3600, 2) as avg_hours_between_actions
FROM admin_audit_logs
GROUP BY action_type
ORDER BY total_occurrences DESC;

-- 1.4 Analiza metadata JSON polja
SELECT
    action_type,
    COUNT(*) as total_actions,
    COUNT(CASE WHEN metadata IS NOT NULL THEN 1 END) as with_metadata,
    ROUND(COUNT(CASE WHEN metadata IS NOT NULL THEN 1 END)::numeric / COUNT(*) * 100, 2) as metadata_percentage,
    jsonb_object_keys(metadata) as metadata_keys
FROM admin_audit_logs
WHERE metadata IS NOT NULL
GROUP BY action_type, jsonb_object_keys(metadata)
ORDER BY action_type, total_actions DESC;

-- 1.5 Detaljna analiza inventory_liters iz metadata
SELECT
    admin_name,
    action_type,
    created_at,
    metadata->>'inventory_liters' as inventory_liters,
    metadata->>'total_debt' as total_debt,
    metadata->>'severity' as severity
FROM admin_audit_logs
WHERE metadata IS NOT NULL
  AND (metadata ? 'inventory_liters' OR metadata ? 'total_debt' OR metadata ? 'severity')
ORDER BY created_at DESC
LIMIT 50;

-- =====================================================
-- 2. ADRESE - Detaljna analiza
-- =====================================================

-- 2.1 Osnovne informacije
SELECT
    'adrese' as table_name,
    COUNT(*) as total_addresses,
    COUNT(DISTINCT grad) as unique_cities,
    COUNT(CASE WHEN koordinate IS NOT NULL THEN 1 END) as with_coordinates,
    ROUND(COUNT(CASE WHEN koordinate IS NOT NULL THEN 1 END)::numeric / COUNT(*) * 100, 2) as coordinates_percentage
FROM adrese;

-- 2.2 Analiza po gradovima
SELECT
    grad,
    COUNT(*) as total_addresses,
    COUNT(CASE WHEN koordinate IS NOT NULL THEN 1 END) as with_coordinates,
    array_agg(DISTINCT ulica) FILTER (WHERE ulica IS NOT NULL) as streets
FROM adrese
GROUP BY grad
ORDER BY total_addresses DESC;

-- 2.3 Analiza koordinata
SELECT
    id,
    naziv,
    grad,
    ulica,
    broj,
    koordinate,
    koordinate->>'lat' as latitude,
    koordinate->>'lng' as longitude,
    CASE
        WHEN koordinate IS NOT NULL
             AND (koordinate->>'lat')::float BETWEEN -90 AND 90
             AND (koordinate->>'lng')::float BETWEEN -180 AND 180
        THEN 'VALID'
        ELSE 'INVALID'
    END as coordinate_status
FROM adrese
WHERE koordinate IS NOT NULL
ORDER BY id;

-- 2.4 Adrese bez koordinata
SELECT
    id,
    naziv,
    grad,
    ulica,
    broj,
    created_at
FROM adrese
WHERE koordinate IS NULL
ORDER BY created_at DESC;

-- =====================================================
-- 3. APP_CONFIG - Detaljna analiza
-- =====================================================

-- 3.1 Osnovne informacije
SELECT
    'app_config' as table_name,
    COUNT(*) as total_configs,
    COUNT(DISTINCT key) as unique_keys,
    MIN(updated_at) as oldest_update,
    MAX(updated_at) as newest_update
FROM app_config;

-- 3.2 Analiza svih konfiguracija
SELECT
    key,
    value,
    description,
    updated_at,
    LENGTH(value) as value_length,
    CASE
        WHEN value ~ '^[0-9]+$' THEN 'INTEGER'
        WHEN value ~ '^[0-9]+\.[0-9]+$' THEN 'DECIMAL'
        WHEN value ~ '^(true|false)$' THEN 'BOOLEAN'
        WHEN value ~ '^http' THEN 'URL'
        ELSE 'STRING'
    END as value_type
FROM app_config
ORDER BY updated_at DESC;

-- =====================================================
-- 4. APP_SETTINGS - Detaljna analiza
-- =====================================================

-- 4.1 Osnovne informacije
SELECT
    'app_settings' as table_name,
    COUNT(*) as total_settings,
    MIN(updated_at) as oldest_update,
    MAX(updated_at) as newest_update,
    COUNT(DISTINCT updated_by) as unique_updaters
FROM app_settings;

-- 4.2 Analiza podešavanja
SELECT
    id,
    updated_at,
    updated_by,
    nav_bar_type,
    dnevni_zakazivanje_aktivno,
    min_version,
    latest_version,
    store_url_android,
    store_url_huawei,
    EXTRACT(EPOCH FROM (updated_at - LAG(updated_at) OVER (ORDER BY updated_at))) / 3600 as hours_since_last_update
FROM app_settings
ORDER BY updated_at DESC;

-- 4.3 Istorija promena
SELECT
    updated_by,
    COUNT(*) as total_changes,
    MIN(updated_at) as first_change,
    MAX(updated_at) as last_change,
    array_agg(DISTINCT nav_bar_type) as nav_types_used,
    array_agg(DISTINCT min_version) as versions_used
FROM app_settings
GROUP BY updated_by
ORDER BY total_changes DESC;

-- =====================================================
-- 5. DAILY_REPORTS - Ultra detaljna analiza
-- =====================================================

-- 5.1 Osnovne informacije
SELECT
    'daily_reports' as table_name,
    COUNT(*) as total_reports,
    COUNT(DISTINCT vozac) as unique_drivers,
    COUNT(DISTINCT datum) as unique_dates,
    MIN(datum) as oldest_date,
    MAX(datum) as newest_date,
    SUM(ukupan_pazar) as total_revenue,
    SUM(otkazani_putnici) as total_cancellations,
    SUM(naplaceni_putnici) as total_paid,
    SUM(pokupljeni_putnici) as total_picked_up
FROM daily_reports;

-- 5.2 Analiza po vozacima
SELECT
    vozac,
    vozac_id,
    COUNT(*) as total_reports,
    MIN(datum) as first_report,
    MAX(datum) as last_report,
    SUM(ukupan_pazar) as total_revenue,
    SUM(sitan_novac) as total_cash,
    SUM(otkazani_putnici) as total_cancellations,
    SUM(naplaceni_putnici) as total_paid,
    SUM(pokupljeni_putnici) as total_picked_up,
    SUM(dugovi_putnici) as total_debtors,
    SUM(mesecne_karte) as total_monthly_cards,
    ROUND(AVG(kilometraza), 2) as avg_kilometers,
    COUNT(CASE WHEN automatski_generisan THEN 1 END) as auto_generated
FROM daily_reports
GROUP BY vozac, vozac_id
ORDER BY total_reports DESC;

-- 5.3 Analiza po datumima
SELECT
    datum,
    COUNT(*) as reports_count,
    SUM(ukupan_pazar) as daily_revenue,
    SUM(otkazani_putnici) as daily_cancellations,
    SUM(naplaceni_putnici) as daily_paid,
    SUM(pokupljeni_putnici) as daily_picked_up,
    ROUND(AVG(kilometraza), 2) as avg_daily_km,
    COUNT(DISTINCT vozac) as active_drivers
FROM daily_reports
GROUP BY datum
ORDER BY datum DESC
LIMIT 30;

-- 5.4 Analiza performansi
SELECT
    vozac,
    datum,
    ukupan_pazar,
    sitan_novac,
    otkazani_putnici,
    naplaceni_putnici,
    pokupljeni_putnici,
    CASE
        WHEN pokupljeni_putnici > 0
        THEN ROUND(naplaceni_putnici::numeric / pokupljeni_putnici * 100, 2)
        ELSE 0
    END as payment_rate_percent,
    CASE
        WHEN pokupljeni_putnici > 0
        THEN ROUND(otkazani_putnici::numeric / pokupljeni_putnici * 100, 2)
        ELSE 0
    END as cancellation_rate_percent,
    kilometraza,
    automatski_generisan
FROM daily_reports
ORDER BY datum DESC, vozac
LIMIT 50;

-- 5.5 Analiza dugovanja
SELECT
    vozac,
    datum,
    dugovi_putnici,
    ukupan_pazar,
    CASE
        WHEN dugovi_putnici > 0 THEN 'IMA DUGOVE'
        ELSE 'NEMA DUGOVA'
    END as debt_status
FROM daily_reports
WHERE dugovi_putnici > 0
ORDER BY dugovi_putnici DESC, datum DESC;

-- =====================================================
-- 6. FINANSIJE_LICNO - Detaljna analiza
-- =====================================================

-- 6.1 Osnovne informacije
SELECT
    'finansije_licno' as table_name,
    COUNT(*) as total_entries,
    COUNT(DISTINCT tip) as unique_types,
    MIN(created_at) as oldest_entry,
    MAX(created_at) as newest_entry,
    SUM(iznos) as total_amount
FROM finansije_licno;

-- 6.2 Analiza po tipovima
SELECT
    tip,
    COUNT(*) as total_entries,
    SUM(iznos) as total_amount,
    ROUND(AVG(iznos), 2) as avg_amount,
    MIN(iznos) as min_amount,
    MAX(iznos) as max_amount,
    MIN(created_at) as first_entry,
    MAX(created_at) as last_entry
FROM finansije_licno
GROUP BY tip
ORDER BY total_amount DESC;

-- =====================================================
-- 7. FINANSIJE_TROSKOVI - Detaljna analiza
-- =====================================================

-- 7.1 Osnovne informacije
SELECT
    'finansije_troskovi' as table_name,
    COUNT(*) as total_expenses,
    COUNT(DISTINCT naziv) as unique_expenses,
    COUNT(DISTINCT tip) as unique_types,
    COUNT(DISTINCT vozac_id) as unique_drivers,
    SUM(iznos) as total_amount,
    COUNT(CASE WHEN mesecno THEN 1 END) as monthly_expenses,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_expenses
FROM finansije_troskovi;

-- 7.2 Analiza po tipovima
SELECT
    tip,
    COUNT(*) as total_expenses,
    SUM(iznos) as total_amount,
    ROUND(AVG(iznos), 2) as avg_amount,
    COUNT(CASE WHEN mesecno THEN 1 END) as monthly_count,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_count,
    COUNT(DISTINCT vozac_id) as drivers_affected
FROM finansije_troskovi
GROUP BY tip
ORDER BY total_amount DESC;

-- 7.3 Analiza po vozacima
SELECT
    vozac_id,
    COUNT(*) as total_expenses,
    SUM(iznos) as total_amount,
    SUM(CASE WHEN mesecno THEN iznos ELSE 0 END) as monthly_total,
    SUM(CASE WHEN NOT mesecno THEN iznos ELSE 0 END) as one_time_total,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_expenses
FROM finansije_troskovi
WHERE vozac_id IS NOT NULL
GROUP BY vozac_id
ORDER BY total_amount DESC;

-- =====================================================
-- 8. FUEL_LOGS - Detaljna analiza
-- =====================================================

-- 8.1 Osnovne informacije
SELECT
    'fuel_logs' as table_name,
    COUNT(*) as total_entries,
    COUNT(DISTINCT vozilo_uuid) as unique_vehicles,
    MIN(created_at) as oldest_entry,
    MAX(created_at) as newest_entry,
    SUM(liters) as total_liters,
    SUM(amount) as total_amount
FROM fuel_logs;

-- 8.2 Analiza po vozilima
SELECT
    vozilo_uuid,
    COUNT(*) as total_refuels,
    SUM(liters) as total_liters,
    SUM(amount) as total_amount,
    ROUND(AVG(price), 2) as avg_price_per_liter,
    ROUND(AVG(liters), 2) as avg_liters_per_refuel,
    MIN(created_at) as first_refuel,
    MAX(created_at) as last_refuel,
    ROUND(SUM(amount) / SUM(liters), 2) as avg_price_per_liter_calc
FROM fuel_logs
WHERE vozilo_uuid IS NOT NULL
GROUP BY vozilo_uuid
ORDER BY total_liters DESC;

-- 8.3 Analiza metadata
SELECT
    vozilo_uuid,
    created_at,
    liters,
    amount,
    price,
    metadata
FROM fuel_logs
WHERE metadata IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;

-- =====================================================
-- 9. KAPACITET_POLAZAKA - Detaljna analiza
-- =====================================================

-- 9.1 Osnovne informacije
SELECT
    'kapacitet_polazaka' as table_name,
    COUNT(*) as total_schedules,
    COUNT(DISTINCT grad) as unique_cities,
    COUNT(DISTINCT vreme) as unique_times,
    SUM(max_mesta) as total_capacity,
    ROUND(AVG(max_mesta), 2) as avg_capacity,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_schedules
FROM kapacitet_polazaka;

-- 9.2 Analiza po gradovima
SELECT
    grad,
    COUNT(*) as total_schedules,
    SUM(max_mesta) as total_capacity,
    ROUND(AVG(max_mesta), 2) as avg_capacity,
    array_agg(vreme) as departure_times,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_schedules
FROM kapacitet_polazaka
GROUP BY grad
ORDER BY total_capacity DESC;

-- =====================================================
-- 10. ML_CONFIG - Detaljna analiza
-- =====================================================

-- 10.1 Osnovne informacije
SELECT
    'ml_config' as table_name,
    COUNT(*) as total_configs,
    MIN(updated_at) as oldest_update,
    MAX(updated_at) as newest_update
FROM ml_config;

-- 10.2 Analiza konfiguracija
SELECT
    id,
    LENGTH(data::text) as data_size,
    LENGTH(config::text) as config_size,
    updated_at
FROM ml_config
ORDER BY updated_at DESC;

-- =====================================================
-- 11. PAYMENT_REMINDERS_LOG - Detaljna analiza
-- =====================================================

-- 11.1 Osnovne informacije
SELECT
    'payment_reminders_log' as table_name,
    COUNT(*) as total_reminders,
    COUNT(DISTINCT reminder_type) as unique_types,
    MIN(created_at) as oldest_reminder,
    MAX(created_at) as newest_reminder,
    SUM(total_unpaid_passengers) as total_unpaid,
    SUM(total_notifications_sent) as total_notifications
FROM payment_reminders_log;

-- 11.2 Analiza po tipovima
SELECT
    reminder_type,
    COUNT(*) as total_reminders,
    SUM(total_unpaid_passengers) as total_unpaid,
    SUM(total_notifications_sent) as total_sent,
    ROUND(AVG(total_unpaid_passengers), 2) as avg_unpaid,
    MIN(created_at) as first_reminder,
    MAX(created_at) as last_reminder
FROM payment_reminders_log
GROUP BY reminder_type
ORDER BY total_reminders DESC;

-- =====================================================
-- 12. PENDING_RESOLUTION_QUEUE - Detaljna analiza
-- =====================================================

-- 12.1 Osnovne informacije
SELECT
    'pending_resolution_queue' as table_name,
    COUNT(*) as total_pending,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    COUNT(DISTINCT grad) as unique_cities,
    COUNT(CASE WHEN sent THEN 1 END) as sent_notifications,
    COUNT(CASE WHEN sent_at IS NOT NULL THEN 1 END) as processed_notifications
FROM pending_resolution_queue;

-- 12.2 Analiza po statusu
SELECT
    sent,
    COUNT(*) as total_count,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM pending_resolution_queue
GROUP BY sent
ORDER BY sent;

-- =====================================================
-- 13. PIN_ZAHTEVI - Detaljna analiza
-- =====================================================

-- 13.1 Osnovne informacije
SELECT
    'pin_zahtevi' as table_name,
    COUNT(*) as total_requests,
    COUNT(DISTINCT status) as unique_statuses,
    COUNT(CASE WHEN status = 'ceka' THEN 1 END) as pending_requests,
    COUNT(CASE WHEN status = 'odobren' THEN 1 END) as approved_requests,
    COUNT(CASE WHEN status = 'odbijen' THEN 1 END) as rejected_requests
FROM pin_zahtevi;

-- 13.2 Analiza po statusima
SELECT
    status,
    COUNT(*) as total_count,
    MIN(created_at) as oldest,
    MAX(created_at) as newest,
    EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 3600 as hours_span
FROM pin_zahtevi
GROUP BY status
ORDER BY total_count DESC;

-- =====================================================
-- 14. PROMENE_VREMENA_LOG - Detaljna analiza
-- =====================================================

-- 14.1 Osnovne informacije
SELECT
    'promene_vremena_log' as table_name,
    COUNT(*) as total_changes,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    MIN(created_at) as oldest_change,
    MAX(created_at) as newest_change,
    ROUND(AVG(sati_unapred), 2) as avg_hours_ahead
FROM promene_vremena_log;

-- 14.2 Analiza vremenskih razlika
SELECT
    sati_unapred,
    COUNT(*) as total_changes,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM promene_vremena_log
GROUP BY sati_unapred
ORDER BY sati_unapred;

-- =====================================================
-- 15. PUSH_TOKENS - Detaljna analiza
-- =====================================================

-- 15.1 Osnovne informacije
SELECT
    'push_tokens' as table_name,
    COUNT(*) as total_tokens,
    COUNT(DISTINCT provider) as unique_providers,
    COUNT(DISTINCT user_type) as unique_user_types,
    COUNT(CASE WHEN putnik_id IS NOT NULL THEN 1 END) as passenger_tokens,
    COUNT(CASE WHEN vozac_id IS NOT NULL THEN 1 END) as driver_tokens
FROM push_tokens;

-- 15.2 Analiza po providerima
SELECT
    provider,
    COUNT(*) as total_tokens,
    COUNT(DISTINCT CASE WHEN putnik_id IS NOT NULL THEN putnik_id END) as passenger_tokens,
    COUNT(DISTINCT CASE WHEN vozac_id IS NOT NULL THEN vozac_id END) as driver_tokens,
    MIN(created_at) as oldest_token,
    MAX(created_at) as newest_token
FROM push_tokens
GROUP BY provider
ORDER BY total_tokens DESC;

-- =====================================================
-- 16. PUTNIK_PICKUP_LOKACIJE - Detaljna analiza
-- =====================================================

-- 16.1 Osnovne informacije
SELECT
    'putnik_pickup_lokacije' as table_name,
    COUNT(*) as total_locations,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    COUNT(DISTINCT vozac_id) as unique_drivers,
    COUNT(CASE WHEN lat IS NOT NULL AND lng IS NOT NULL THEN 1 END) as with_coordinates
FROM putnik_pickup_lokacije;

-- 16.2 Analiza koordinata
SELECT
    putnik_id,
    vozac_id,
    datum,
    vreme,
    lat,
    lng,
    CASE
        WHEN lat IS NOT NULL AND lng IS NOT NULL
             AND lat BETWEEN -90 AND 90
             AND lng BETWEEN -180 AND 180
        THEN 'VALID'
        ELSE 'INVALID'
    END as coordinate_status
FROM putnik_pickup_lokacije
ORDER BY created_at DESC
LIMIT 50;

-- =====================================================
-- 17. RACUN_SEQUENCE - Detaljna analiza
-- =====================================================

-- 17.1 Osnovne informacije
SELECT
    'racun_sequence' as table_name,
    COUNT(*) as total_sequences,
    MIN(updated_at) as oldest_update,
    MAX(updated_at) as newest_update,
    SUM(poslednji_broj) as total_invoices_generated
FROM racun_sequence;

-- 17.2 Analiza po godinama
SELECT
    godina,
    poslednji_broj,
    updated_at
FROM racun_sequence
ORDER BY godina DESC;

-- =====================================================
-- 18. REGISTROVANI_PUTNICI - Ultra detaljna analiza
-- =====================================================

-- 18.1 Osnovne informacije
SELECT
    'registrovani_putnici' as table_name,
    COUNT(*) as total_passengers,
    COUNT(DISTINCT tip) as unique_types,
    COUNT(DISTINCT tip_skole) as unique_school_types,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_passengers,
    COUNT(CASE WHEN obrisan THEN 1 END) as deleted_passengers,
    COUNT(DISTINCT vozac_id) as unique_drivers,
    SUM(cena_po_danu) as total_daily_rates,
    ROUND(AVG(cena_po_danu), 2) as avg_daily_rate
FROM registrovani_putnici;

-- 18.2 Analiza po tipovima
SELECT
    tip,
    COUNT(*) as total_count,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_count,
    SUM(cena_po_danu) as total_rates,
    ROUND(AVG(cena_po_danu), 2) as avg_rate,
    COUNT(DISTINCT vozac_id) as drivers_count
FROM registrovani_putnici
GROUP BY tip
ORDER BY total_count DESC;

-- 18.3 Analiza cena
SELECT
    cena_po_danu,
    COUNT(*) as passenger_count,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_count,
    array_agg(DISTINCT tip) as passenger_types
FROM registrovani_putnici
WHERE cena_po_danu IS NOT NULL
GROUP BY cena_po_danu
ORDER BY cena_po_danu;

-- 18.4 Analiza telefona
SELECT
    CASE
        WHEN broj_telefona LIKE '+381%' THEN 'Srbija (+381)'
        WHEN broj_telefona LIKE '+387%' THEN 'BiH (+387)'
        WHEN broj_telefona LIKE '+385%' THEN 'Hrvatska (+385)'
        ELSE 'Ostalo'
    END as country,
    COUNT(*) as total_count
FROM registrovani_putnici
WHERE broj_telefona IS NOT NULL
GROUP BY CASE
    WHEN broj_telefona LIKE '+381%' THEN 'Srbija (+381)'
    WHEN broj_telefona LIKE '+387%' THEN 'BiH (+387)'
    WHEN broj_telefona LIKE '+385%' THEN 'Hrvatska (+385)'
    ELSE 'Ostalo'
END
ORDER BY total_count DESC;

-- 18.5 Analiza adresa
SELECT
    adresa_bela_crkva_id,
    adresa_vrsac_id,
    COUNT(*) as passenger_count,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_count
FROM registrovani_putnici
WHERE adresa_bela_crkva_id IS NOT NULL OR adresa_vrsac_id IS NOT NULL
GROUP BY adresa_bela_crkva_id, adresa_vrsac_id
ORDER BY passenger_count DESC;

-- =====================================================
-- 19. SEAT_REQUEST_NOTIFICATIONS - Detaljna analiza
-- =====================================================

-- 19.1 Osnovne informacije
SELECT
    'seat_request_notifications' as table_name,
    COUNT(*) as total_notifications,
    COUNT(CASE WHEN sent THEN 1 END) as sent_notifications,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    COUNT(DISTINCT seat_request_id) as unique_requests
FROM seat_request_notifications;

-- 19.2 Analiza uspešnosti slanja
SELECT
    sent,
    COUNT(*) as total_count,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 2) as percentage,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM seat_request_notifications
GROUP BY sent;

-- =====================================================
-- 20. SEAT_REQUESTS - Ultra detaljna analiza
-- =====================================================

-- 20.1 Osnovne informacije
SELECT
    'seat_requests' as table_name,
    COUNT(*) as total_requests,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    COUNT(DISTINCT grad) as unique_cities,
    COUNT(DISTINCT status) as unique_statuses,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_requests,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_requests,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_requests
FROM seat_requests;

-- 20.2 Analiza po statusima
SELECT
    status,
    COUNT(*) as total_count,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 2) as percentage,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM seat_requests
GROUP BY status
ORDER BY total_count DESC;

-- 20.3 Analiza po gradovima
SELECT
    grad,
    COUNT(*) as total_requests,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_requests,
    ROUND(COUNT(CASE WHEN status = 'confirmed' THEN 1 END)::numeric / COUNT(*) * 100, 2) as confirmation_rate
FROM seat_requests
GROUP BY grad
ORDER BY total_requests DESC;

-- 20.4 Analiza vremena obrade
SELECT
    status,
    EXTRACT(EPOCH FROM (processed_at - created_at)) / 3600 as processing_hours,
    COUNT(*) as request_count
FROM seat_requests
WHERE processed_at IS NOT NULL
GROUP BY status, EXTRACT(EPOCH FROM (processed_at - created_at)) / 3600
ORDER BY processing_hours;

-- =====================================================
-- 21. TROSKOVI_UNOSI - Detaljna analiza
-- =====================================================

-- 21.1 Osnovne informacije
SELECT
    'troskovi_unosi' as table_name,
    COUNT(*) as total_entries,
    COUNT(DISTINCT vozilo_id) as unique_vehicles,
    COUNT(DISTINCT vozac_id) as unique_drivers,
    SUM(iznos) as total_amount,
    ROUND(AVG(iznos), 2) as avg_amount
FROM troskovi_unosi;

-- 21.2 Analiza po tipovima
SELECT
    tip,
    COUNT(*) as total_entries,
    SUM(iznos) as total_amount,
    ROUND(AVG(iznos), 2) as avg_amount,
    MIN(datum) as oldest_entry,
    MAX(datum) as newest_entry
FROM troskovi_unosi
GROUP BY tip
ORDER BY total_amount DESC;

-- =====================================================
-- 22. USER_DAILY_CHANGES - Detaljna analiza
-- =====================================================

-- 22.1 Osnovne informacije
SELECT
    'user_daily_changes' as table_name,
    COUNT(*) as total_changes,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    SUM(changes_count) as total_changes_count,
    ROUND(AVG(changes_count), 2) as avg_changes_per_entry
FROM user_daily_changes;

-- 22.2 Analiza aktivnosti
SELECT
    putnik_id,
    COUNT(*) as total_entries,
    SUM(changes_count) as total_changes,
    ROUND(AVG(changes_count), 2) as avg_changes,
    MIN(created_at) as first_change,
    MAX(created_at) as last_change
FROM user_daily_changes
GROUP BY putnik_id
ORDER BY total_changes DESC
LIMIT 20;

-- =====================================================
-- 23. VOZAC_LOKACIJE - Detaljna analiza
-- =====================================================

-- 23.1 Osnovne informacije
SELECT
    'vozac_lokacije' as table_name,
    COUNT(*) as total_locations,
    COUNT(DISTINCT vozac_id) as unique_drivers,
    COUNT(DISTINCT grad) as unique_cities,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_locations,
    ROUND(AVG(lat), 6) as avg_latitude,
    ROUND(AVG(lng), 6) as avg_longitude
FROM vozac_lokacije;

-- 23.2 Analiza po vozacima
SELECT
    vozac_id,
    COUNT(*) as total_locations,
    COUNT(CASE WHEN aktivan THEN 1 END) as active_locations,
    ROUND(AVG(lat), 6) as avg_lat,
    ROUND(AVG(lng), 6) as avg_lng,
    array_agg(DISTINCT grad) as cities,
    MIN(updated_at) as first_location,
    MAX(updated_at) as last_location
FROM vozac_lokacije
GROUP BY vozac_id
ORDER BY total_locations DESC;

-- =====================================================
-- 24. VOZACI - Detaljna analiza
-- =====================================================

-- 24.1 Osnovne informacije
SELECT
    'vozaci' as table_name,
    COUNT(*) as total_drivers,
    COUNT(CASE WHEN email IS NOT NULL THEN 1 END) as with_email,
    COUNT(CASE WHEN telefon IS NOT NULL THEN 1 END) as with_phone,
    COUNT(DISTINCT boja) as unique_colors
FROM vozaci;

-- 24.2 Analiza boja
SELECT
    boja,
    COUNT(*) as driver_count,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 2) as percentage
FROM vozaci
WHERE boja IS NOT NULL
GROUP BY boja
ORDER BY driver_count DESC;

-- =====================================================
-- 25. VOZILA - Ultra detaljna analiza
-- =====================================================

-- 25.1 Osnovne informacije
SELECT
    'vozila' as table_name,
    COUNT(*) as total_vehicles,
    COUNT(DISTINCT registarski_broj) as unique_plates,
    COUNT(DISTINCT marka) as unique_brands,
    COUNT(DISTINCT model) as unique_models,
    ROUND(AVG(godina_proizvodnje), 2) as avg_year,
    ROUND(AVG(broj_mesta), 2) as avg_seats,
    ROUND(AVG(kilometraza), 2) as avg_mileage
FROM vozila;

-- 25.2 Analiza po markama
SELECT
    marka,
    COUNT(*) as total_vehicles,
    ROUND(AVG(godina_proizvodnje), 2) as avg_year,
    ROUND(AVG(broj_mesta), 2) as avg_seats,
    ROUND(AVG(kilometraza), 2) as avg_mileage,
    array_agg(DISTINCT model) as models
FROM vozila
GROUP BY marka
ORDER BY total_vehicles DESC;

-- 25.3 Analiza kilometraze
SELECT
    registarski_broj,
    marka,
    model,
    kilometraza,
    godina_proizvodnje,
    CASE
        WHEN kilometraza > 300000 THEN 'VRLO VISOKA'
        WHEN kilometraza > 200000 THEN 'VISOKA'
        WHEN kilometraza > 100000 THEN 'SREDNJA'
        ELSE 'NISKA'
    END as mileage_category
FROM vozila
ORDER BY kilometraza DESC;

-- 25.4 Analiza servisa
SELECT
    registarski_broj,
    marka,
    model,
    mali_servis_datum,
    mali_servis_km,
    veliki_servis_datum,
    veliki_servis_km,
    CASE
        WHEN mali_servis_datum < CURRENT_DATE - INTERVAL '1 year' THEN 'SERVIS NUŽAN'
        WHEN veliki_servis_datum < CURRENT_DATE - INTERVAL '2 years' THEN 'VELIKI SERVIS NUŽAN'
        ELSE 'OK'
    END as service_status
FROM vozila
ORDER BY
    CASE
        WHEN mali_servis_datum < CURRENT_DATE - INTERVAL '1 year' THEN 1
        WHEN veliki_servis_datum < CURRENT_DATE - INTERVAL '2 years' THEN 2
        ELSE 3
    END;

-- =====================================================
-- 26. VOZILA_ISTORIJA - Detaljna analiza
-- =====================================================

-- 26.1 Osnovne informacije
SELECT
    'vozila_istorija' as table_name,
    COUNT(*) as total_entries,
    COUNT(DISTINCT vozilo_id) as unique_vehicles,
    COUNT(DISTINCT tip) as unique_types,
    SUM(cena) as total_cost,
    ROUND(AVG(cena), 2) as avg_cost
FROM vozila_istorija;

-- 26.2 Analiza po tipovima
SELECT
    tip,
    COUNT(*) as total_entries,
    SUM(cena) as total_cost,
    ROUND(AVG(cena), 2) as avg_cost,
    MIN(datum) as oldest_entry,
    MAX(datum) as newest_entry
FROM vozila_istorija
GROUP BY tip
ORDER BY total_cost DESC;

-- =====================================================
-- 27. VOZNJE_LOG - Ultra detaljna analiza
-- =====================================================

-- 27.1 Osnovne informacije
SELECT
    'voznje_log' as table_name,
    COUNT(*) as total_entries,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    COUNT(DISTINCT vozac_id) as unique_drivers,
    COUNT(DISTINCT tip) as unique_types,
    SUM(iznos) as total_amount,
    ROUND(AVG(iznos), 2) as avg_amount,
    COUNT(CASE WHEN iznos > 0 THEN 1 END) as paid_entries,
    COUNT(CASE WHEN iznos = 0 THEN 1 END) as free_entries
FROM voznje_log;

-- 27.2 Analiza po tipovima
SELECT
    tip,
    COUNT(*) as total_count,
    SUM(iznos) as total_amount,
    ROUND(AVG(iznos), 2) as avg_amount,
    COUNT(DISTINCT putnik_id) as unique_passengers,
    MIN(created_at) as oldest_entry,
    MAX(created_at) as newest_entry
FROM voznje_log
GROUP BY tip
ORDER BY total_count DESC;

-- 27.3 Analiza iznosa
SELECT
    CASE
        WHEN iznos = 0 THEN 'BESPLATNO'
        WHEN iznos < 100 THEN 'NISKA CENA'
        WHEN iznos < 500 THEN 'SREDNJA CENA'
        ELSE 'VISOKA CENA'
    END as price_category,
    COUNT(*) as entry_count,
    SUM(iznos) as total_amount,
    ROUND(AVG(iznos), 2) as avg_amount
FROM voznje_log
GROUP BY CASE
    WHEN iznos = 0 THEN 'BESPLATNO'
    WHEN iznos < 100 THEN 'NISKA CENA'
    WHEN iznos < 500 THEN 'SREDNJA CENA'
    ELSE 'VISOKA CENA'
END
ORDER BY total_amount DESC;

-- 27.4 Analiza metadata
SELECT
    tip,
    COUNT(*) as total_entries,
    COUNT(CASE WHEN meta IS NOT NULL THEN 1 END) as with_metadata,
    jsonb_object_keys(meta) as metadata_keys
FROM voznje_log
WHERE meta IS NOT NULL
GROUP BY tip, jsonb_object_keys(meta)
ORDER BY tip;

-- =====================================================
-- 28. VOZNJE_LOG_WITH_NAMES - Detaljna analiza (VIEW)
-- =====================================================

-- 28.1 Osnovne informacije
SELECT
    'voznje_log_with_names' as table_name,
    COUNT(*) as total_entries,
    COUNT(DISTINCT putnik_ime) as unique_passenger_names
FROM voznje_log_with_names;

-- =====================================================
-- 29. VREME_VOZAC - Detaljna analiza
-- =====================================================

-- 29.1 Osnovne informacije
SELECT
    'vreme_vozac' as table_name,
    COUNT(*) as total_entries,
    COUNT(DISTINCT grad) as unique_cities,
    COUNT(DISTINCT dan) as unique_days,
    COUNT(DISTINCT vozac_ime) as unique_drivers
FROM vreme_vozac;

-- 29.2 Analiza po gradovima
SELECT
    grad,
    COUNT(*) as total_entries,
    COUNT(DISTINCT dan) as unique_days,
    COUNT(DISTINCT vozac_ime) as unique_drivers,
    array_agg(DISTINCT vreme) as times
FROM vreme_vozac
GROUP BY grad
ORDER BY total_entries DESC;

-- =====================================================
-- 30. WEATHER_ALERTS_LOG - Detaljna analiza
-- =====================================================

-- 30.1 Osnovne informacije
SELECT
    'weather_alerts_log' as table_name,
    COUNT(*) as total_alerts,
    COUNT(DISTINCT alert_date) as unique_dates,
    MIN(created_at) as oldest_alert,
    MAX(created_at) as newest_alert
FROM weather_alerts_log;

-- 30.2 Analiza tipova uzbuna
SELECT
    alert_types,
    COUNT(*) as total_alerts,
    MIN(alert_date) as first_alert,
    MAX(alert_date) as last_alert
FROM weather_alerts_log
GROUP BY alert_types
ORDER BY total_alerts DESC;

-- =====================================================
-- KRAJ ULTRA DETALJNE ANALIZE
-- =====================================================