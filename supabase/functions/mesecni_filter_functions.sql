-- 🔧 SQL FUNKCIJE ZA POBOLJŠANU LOGIKU FILTRIRANJA MESEČNIH PUTNIKA
-- Dodajte ove funkcije u vaš Supabase projekat

-- ✅ FUNKCIJA 1: Tačno matchovanje dana u radni_dani koloni
CREATE OR REPLACE FUNCTION matches_day(radni_dani TEXT, target_day TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Podeli string na dan separatoru ','
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
  created_at TIMESTAMPTZ
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
    mp.created_at
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