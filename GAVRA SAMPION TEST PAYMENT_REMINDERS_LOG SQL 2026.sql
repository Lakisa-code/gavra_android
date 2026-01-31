-- =====================================================
-- GAVRA SAMPION TEST PAYMENT_REMINDERS_LOG SQL 2026
-- Testovi za payment_reminders_log tabelu
-- Datum: 31.01.2026
-- =====================================================

-- TEST 1: Provera da li tabela postoji
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'payment_reminders_log'
) as "tabela_postoji";

-- TEST 2: Prikazi sve kolone
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'payment_reminders_log'
ORDER BY ordinal_position;

-- TEST 3: Broj redova (treba biti 0 jer je nova tabela)
SELECT COUNT(*) as "broj_redova" FROM payment_reminders_log;

-- TEST 4: Provera constraints
SELECT
    conname as "constraint_name",
    contype as "constraint_type",
    conkey as "constraint_keys",
    confkey as "foreign_keys"
FROM pg_constraint
WHERE conrelid = 'payment_reminders_log'::regclass;

-- TEST 5: Test insert validnih podataka
INSERT INTO payment_reminders_log (reminder_date, reminder_type, triggered_by, total_unpaid_passengers, total_notifications_sent)
VALUES
('2026-01-31', 'weekly_payment_reminder', 'system_cron', 15, 12),
('2026-01-30', 'monthly_summary', 'admin_manual', 8, 8),
('2026-01-29', 'urgent_payment_alert', 'system_automatic', 25, 20),
('2026-01-28', 'final_warning', 'admin_manual', 5, 5)
RETURNING id, reminder_date, reminder_type, triggered_by, total_unpaid_passengers, total_notifications_sent;

-- TEST 6: Provera unetih podataka
SELECT id, reminder_date, reminder_type, triggered_by, total_unpaid_passengers, total_notifications_sent, created_at
FROM payment_reminders_log
ORDER BY reminder_date DESC;

-- TEST 7: Test statistika po tipovima podsetnika
SELECT
    reminder_type,
    COUNT(*) as "broj_podsetnika",
    SUM(total_unpaid_passengers) as "ukupno_neplaceni_putnici",
    SUM(total_notifications_sent) as "ukupno_poslate_notifikacije",
    AVG(total_unpaid_passengers) as "prosecno_neplacenih_po_podsetniku",
    MIN(reminder_date) as "prvi_podsetnik",
    MAX(reminder_date) as "poslednji_podsetnik"
FROM payment_reminders_log
GROUP BY reminder_type
ORDER BY reminder_type;

-- TEST 8: Test filtriranje po trigger-u
SELECT reminder_date, reminder_type, total_unpaid_passengers, total_notifications_sent
FROM payment_reminders_log
WHERE triggered_by = 'system_automatic'
ORDER BY reminder_date DESC;

-- TEST 9: Test uspešnost slanja notifikacija
SELECT
    reminder_date,
    reminder_type,
    total_unpaid_passengers,
    total_notifications_sent,
    CASE
        WHEN total_notifications_sent >= total_unpaid_passengers THEN 'USPESNO - SVE NOTIFIKACIJE POSLATE'
        WHEN total_notifications_sent > 0 THEN 'DELO MICNO - NEKE NOTIFIKACIJE POSLATE'
        ELSE 'NEUSPESNO - NI JEDNA NOTIFIKACIJA NIJE POSLATA'
    END as "status_slanja"
FROM payment_reminders_log
ORDER BY reminder_date DESC;

-- TEST 10: Provera realtime publication
SELECT
    pubname as "publication_name",
    schemaname as "schema_name",
    tablename as "table_name"
FROM pg_publication_tables
WHERE tablename = 'payment_reminders_log';

-- TEST 11: Čišćenje test podataka
DELETE FROM payment_reminders_log;

-- TEST 12: Finalni broj redova (treba biti 0)
SELECT COUNT(*) as "final_broj_redova" FROM payment_reminders_log;