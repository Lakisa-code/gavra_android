-- Migration: Poboljšanja za filtriranje mesečnih putnika
-- Run: supabase migration new improved_mesecni_filtering

-- 🔧 SQL FUNKCIJE ZA POBOLJŠANU LOGIKU FILTRIRANJA MESEČNIH PUTNIKA

-- ✅ FUNKCIJA 1: Tačno matchovanje dana u radni_dani koloni
CREATE OR REPLACE FUNCTION matches_day(radni_dani TEXT, target_day TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Podeli string na separator ','
  -- Ukloni razmake i proveri da li postoji tačan match
  RETURN target_day = ANY(
    SELECT TRIM(LOWER(unnest(string_to_array(LOWER(radni_dani), ','))))
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ✅ FUNKCIJA 2: Validacija vremena polaska
CREATE OR REPLACE FUNCTION is_valid_polazak(polazak TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Proveri da li je vreme validno (nije null, prazan string ili '00:00')
  IF polazak IS NULL OR TRIM(polazak) = '' THEN
    RETURN FALSE;
  END IF;
  
  -- Proveri nevažeće vrednosti
  IF LOWER(TRIM(polazak)) IN ('00:00', '00:00:00', 'null', 'undefined') THEN
    RETURN FALSE;
  END IF;
  
  -- Proveri format vremena pomoću regex (HH:MM ili HH:MM:SS)
  RETURN TRIM(polazak) ~ '^\d{1,2}:\d{2}(:\d{2})?$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ✅ FUNKCIJA 3: Validacija statusa putnika
CREATE OR REPLACE FUNCTION is_valid_status(status TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Null ili prazan status je valjan
  IF status IS NULL OR TRIM(status) = '' THEN
    RETURN TRUE;
  END IF;
  
  -- Proveri nevalidne statuse
  RETURN LOWER(TRIM(status)) NOT IN (
    'bolovanje', 'godišnje', 'godisnji', 
    'obrisan', 'otkazan', 'otkazano'
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ✅ FUNKCIJA 4: Kombinovani filter za mesečne putnike
CREATE OR REPLACE FUNCTION get_filtered_mesecni_putnici(
  target_day TEXT DEFAULT NULL,
  search_term TEXT DEFAULT NULL,
  filter_type TEXT DEFAULT 'svi',
  active_only BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
  id UUID,
  putnik_ime TEXT,
  tip TEXT,
  tip_skole TEXT,
  radni_dani TEXT,
  polasci_po_danu JSONB,
  status TEXT,
  aktivan BOOLEAN,
  obrisan BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  datum_pocetka_meseca DATE,
  datum_kraja_meseca DATE,
  ukupna_cena_meseca DECIMAL,
  broj_telefona TEXT,
  broj_telefona_oca TEXT,
  broj_telefona_majke TEXT,
  adresa_bela_crkva_id UUID,
  adresa_vrsac_id UUID,
  cena DECIMAL,
  broj_putovanja INTEGER,
  broj_otkazivanja INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mp.id,
    mp.putnik_ime,
    mp.tip,
    mp.tip_skole,
    mp.radni_dani,
    mp.polasci_po_danu,
    mp.status,
    mp.aktivan,
    mp.obrisan,
    mp.created_at,
    mp.updated_at,
    mp.datum_pocetka_meseca,
    mp.datum_kraja_meseca,
    mp.ukupna_cena_meseca,
    mp.broj_telefona,
    mp.broj_telefona_oca,
    mp.broj_telefona_majke,
    mp.adresa_bela_crkva_id,
    mp.adresa_vrsac_id,
    mp.cena,
    mp.broj_putovanja,
    mp.broj_otkazivanja
  FROM mesecni_putnici mp
  WHERE 
    -- Filter aktivnosti
    (NOT active_only OR (mp.aktivan = TRUE AND mp.obrisan = FALSE))
    
    -- Filter statusa
    AND is_valid_status(mp.status)
    
    -- Filter po danu (ako je specificiran)
    AND (target_day IS NULL OR matches_day(mp.radni_dani, target_day))
    
    -- Filter po search termu
    AND (
      search_term IS NULL OR search_term = '' OR
      LOWER(mp.putnik_ime) LIKE '%' || LOWER(search_term) || '%' OR
      LOWER(mp.tip) LIKE '%' || LOWER(search_term) || '%' OR
      LOWER(COALESCE(mp.tip_skole, '')) LIKE '%' || LOWER(search_term) || '%'
    )
    
    -- Filter po tipu putnika
    AND (filter_type = 'svi' OR mp.tip = filter_type)
  
  ORDER BY mp.putnik_ime;
END;
$$ LANGUAGE plpgsql;

-- ✅ INDEKSI ZA BOLJE PERFORMANSE
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_aktivan_obrisan 
ON mesecni_putnici(aktivan, obrisan);

CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_status 
ON mesecni_putnici(status);

CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_tip 
ON mesecni_putnici(tip);

CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_putnik_ime_gin 
ON mesecni_putnici USING gin(to_tsvector('serbian', putnik_ime));

-- ✅ COMMENT na funkcije za dokumentaciju
COMMENT ON FUNCTION matches_day(TEXT, TEXT) IS 'Tačno matchovanje dana u radni_dani string-u';
COMMENT ON FUNCTION is_valid_polazak(TEXT) IS 'Validacija formata vremena polaska (HH:MM ili HH:MM:SS)';
COMMENT ON FUNCTION is_valid_status(TEXT) IS 'Proverava da li je status putnika valjan (nije bolovanje, otkazan, itd.)';
COMMENT ON FUNCTION get_filtered_mesecni_putnici(TEXT, TEXT, TEXT, BOOLEAN) IS 'Optimizovano filtriranje mesečnih putnika sa SQL funkcijama';