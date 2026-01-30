-- SQL upiti za upoređivanje tabela seat_requests i voznje_log
-- Danas: 2026-01-29

-- 1. Zahtevi iz seat_requests za današnji dan
SELECT
    id,
    putnik_id,
    grad,
    datum,
    zeljeno_vreme,
    status,
    created_at,
    priority,
    broj_mesta
FROM seat_requests
WHERE DATE(created_at) = '2026-01-29'
ORDER BY created_at DESC;

-- 2. Zakazivanja iz voznje_log za današnji dan
SELECT
    id,
    putnik_id,
    datum,
    tip,
    detalji,
    meta->>'dan' as dan,
    meta->>'grad' as grad,
    meta->>'vreme' as vreme,
    created_at
FROM voznje_log
WHERE DATE(created_at) = '2026-01-29'
  AND tip = 'zakazivanje_putnika'
ORDER BY created_at DESC;

-- 3. Potvrde iz voznje_log za današnji dan
SELECT
    id,
    putnik_id,
    datum,
    tip,
    detalji,
    meta->>'dan' as dan,
    meta->>'grad' as grad,
    meta->>'vreme' as vreme,
    created_at
FROM voznje_log
WHERE DATE(created_at) = '2026-01-29'
  AND tip = 'potvrda_zakazivanja'
ORDER BY created_at DESC;

-- 4. Uporedna analiza - broj zahteva po tipu
SELECT
    'seat_requests' as tabela,
    COUNT(*) as broj_zahteva,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed
FROM seat_requests
WHERE DATE(created_at) = '2026-01-29'

UNION ALL

SELECT
    'voznje_log_zakazivanja' as tabela,
    COUNT(*) as broj_zahteva,
    0 as pending,
    0 as confirmed
FROM voznje_log
WHERE DATE(created_at) = '2026-01-29'
  AND tip = 'zakazivanje_putnika'

UNION ALL

SELECT
    'voznje_log_potvrde' as tabela,
    COUNT(*) as broj_zahteva,
    0 as pending,
    0 as confirmed
FROM voznje_log
WHERE DATE(created_at) = '2026-01-29'
  AND tip = 'potvrda_zakazivanja';