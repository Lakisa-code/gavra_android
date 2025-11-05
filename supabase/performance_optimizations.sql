-- 🚀 SUPABASE QUERY OPTIMIZATIONS
-- Dodaj ove indexe za poboljšanje performansi

-- 1. Index za mesecni_putnici filtriranje
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_filtering 
ON mesecni_putnici (aktivan, radni_dani, status) 
WHERE aktivan = true;

-- 2. Index za putnici brza pretraga po datumu
CREATE INDEX IF NOT EXISTS idx_putnici_datum_status 
ON putnici (datum DESC, status) 
WHERE status != 'obrisan';

-- 3. Index za real-time putovanja
CREATE INDEX IF NOT EXISTS idx_putovanja_vozac_datum 
ON putovanja (vozac_id, datum DESC, vreme_kraja DESC);

-- 4. Partial index za aktivne vozače  
CREATE INDEX IF NOT EXISTS idx_vozaci_aktivni 
ON vozaci (ime, telefon) 
WHERE aktivan = true;

-- 5. Index za adrese geocoding
CREATE INDEX IF NOT EXISTS idx_adrese_geocoding 
ON adrese (adresa_text, lat, lng) 
WHERE lat IS NOT NULL AND lng IS NOT NULL;

-- 6. Compound index za putnici filtering u aplikaciji
CREATE INDEX IF NOT EXISTS idx_putnici_app_filter 
ON putnici (datum, grad, polazak, status) 
WHERE mesecna_karta = false;

-- 7. Index za mesecni putnici vremena polaska  
CREATE INDEX IF NOT EXISTS idx_mesecni_vremena 
ON mesecni_putnici USING GIN (polasci_po_danu) 
WHERE aktivan = true AND polasci_po_danu != '{}'::jsonb;

-- 8. Index za statistike - brže računanje
CREATE INDEX IF NOT EXISTS idx_putnici_statistike 
ON putnici (vozac, datum, cena, status) 
WHERE status IN ('pokupljen', 'placen');

-- 9. Index za GPS lokacije
CREATE INDEX IF NOT EXISTS idx_gps_lokacije_datum 
ON gps_lokacije (vozac_id, timestamp DESC) 
WHERE accuracy < 50; -- Samo precizne lokacije

-- 10. Index za background services
CREATE INDEX IF NOT EXISTS idx_background_jobs 
ON background_jobs (status, scheduled_at, created_at);

-- ✅ QUERY OPTIMIZATION FUNCTIONS

-- Optimizovana funkcija za dnevne putnike
CREATE OR REPLACE FUNCTION get_daily_passengers_optimized(
  selected_date DATE,
  selected_grad TEXT DEFAULT NULL,
  selected_vreme TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  ime TEXT,
  telefon TEXT,
  adresa TEXT,
  grad TEXT,
  polazak TEXT,
  cena DECIMAL,
  status TEXT,
  datum DATE
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id, p.ime, p.telefon, p.adresa, p.grad, 
    p.polazak, p.cena, p.status, p.datum
  FROM putnici p
  WHERE p.datum = selected_date
    AND p.mesecna_karta = false
    AND p.status != 'obrisan'
    AND (selected_grad IS NULL OR p.grad = selected_grad)
    AND (selected_vreme IS NULL OR p.polazak = selected_vreme)
  ORDER BY p.grad, p.polazak, p.ime;
END;
$$;

-- Optimizovana funkcija za mesečne putnike sa JSON podrškom
CREATE OR REPLACE FUNCTION get_monthly_passengers_optimized(
  target_day TEXT,
  selected_grad TEXT DEFAULT NULL,
  selected_vreme TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  putnik_ime TEXT,
  telefon TEXT,
  adresa TEXT,
  radni_dani TEXT,
  polasci_po_danu JSONB,
  status TEXT,
  aktivan BOOLEAN
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mp.id, mp.putnik_ime, mp.telefon, mp.adresa,
    mp.radni_dani, mp.polasci_po_danu, mp.status, mp.aktivan
  FROM mesecni_putnici mp
  WHERE mp.aktivan = true
    AND mp.radni_dani LIKE '%' || target_day || '%'
    AND (selected_grad IS NULL OR 
         mp.polasci_po_danu ? target_day AND
         (mp.polasci_po_danu->target_day->>'bc' = selected_vreme OR
          mp.polasci_po_danu->target_day->>'vs' = selected_vreme))
  ORDER BY mp.putnik_ime;
END;
$$;

-- Statistike funkcija sa boljim performansama
CREATE OR REPLACE FUNCTION get_driver_stats_optimized(
  driver_name TEXT,
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  total_trips INTEGER,
  total_earnings DECIMAL,
  avg_daily_earnings DECIMAL,
  total_passengers INTEGER
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER as total_trips,
    COALESCE(SUM(p.cena), 0) as total_earnings,
    COALESCE(SUM(p.cena) / NULLIF(end_date - start_date + 1, 0), 0) as avg_daily_earnings,
    COUNT(DISTINCT p.id)::INTEGER as total_passengers
  FROM putnici p
  WHERE p.vozac = driver_name
    AND p.datum BETWEEN start_date AND end_date
    AND p.status IN ('pokupljen', 'placen');
END;
$$;