-- ============================================
-- BRISANJE REDUNDANTNIH TABELA I FUNKCIJA
-- Datum: 11. januar 2026.
-- ============================================

-- 1. Obriši redundantnu tabelu otkazi_log
-- (već postoji voznje_log sa tip='otkazivanje')
DROP TABLE IF EXISTS otkazi_log;

-- 2. Obriši redundantnu tabelu putnik_kvalitet
-- (PutnikKvalitetService računa realtime)
DROP TABLE IF EXISTS putnik_kvalitet;

-- 3. Obriši redundantnu funkciju
DROP FUNCTION IF EXISTS calculate_putnik_kvalitet(uuid);
DROP FUNCTION IF EXISTS calculate_putnik_kvalitet(text);

-- ============================================
-- VERIFIKACIJA - proveri da su obrisane:
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' AND table_name IN ('otkazi_log', 'putnik_kvalitet');
-- ============================================
