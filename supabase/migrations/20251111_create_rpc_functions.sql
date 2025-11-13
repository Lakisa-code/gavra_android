-- =====================================================
-- 🚀 MASTER REALTIME STREAM - DATABASE RPC FUNCTIONS
-- =====================================================
-- Created: 2025-11-11
-- Purpose: Server-side functions for GlobalAppState
-- =====================================================

-- =====================================================
-- 1️⃣ GET VOZAC KUSUR
-- =====================================================
-- Returns current kusur for a vozac from vozaci.kusur column
-- This is the single source of truth for kusur value
-- =====================================================

CREATE OR REPLACE FUNCTION get_vozac_kusur(p_vozac_ime TEXT)
RETURNS DECIMAL
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_kusur DECIMAL;
BEGIN
  SELECT COALESCE(kusur, 0.0)
  INTO v_kusur
  FROM vozaci
  WHERE ime = p_vozac_ime
    AND aktivan = true
    AND obrisan = false;
  
  -- Return 0 if vozac not found
  RETURN COALESCE(v_kusur, 0.0);
END;
$$;

COMMENT ON FUNCTION get_vozac_kusur(TEXT) IS 
'Returns current kusur balance for a driver. Single source of truth from vozaci.kusur column.';


-- =====================================================
-- 2️⃣ CALCULATE DAILY PAZAR
-- =====================================================
-- Calculates total pazar for a vozac on a specific date
-- Combines data from putovanja_istorija + dnevni_putnici
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_daily_pazar(
  p_vozac_ime TEXT,
  p_datum DATE
)
RETURNS TABLE (
  ukupno_putovanja_istorija_cena DECIMAL,
  ukupno_dnevni_putnici_cena DECIMAL,
  ukupni_pazar DECIMAL,
  broj_putovanja_istorija INTEGER,
  broj_dnevni_putnici INTEGER,
  ukupno_putovanja INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_vozac_id UUID;
BEGIN
  -- Get vozac_id from ime
  SELECT id INTO v_vozac_id
  FROM vozaci
  WHERE ime = p_vozac_ime
    AND aktivan = true
    AND obrisan = false;

  -- If vozac not found, return zeros
  IF v_vozac_id IS NULL THEN
    RETURN QUERY SELECT 
      0.0::DECIMAL, 0.0::DECIMAL, 0.0::DECIMAL, 
      0::INTEGER, 0::INTEGER, 0::INTEGER;
    RETURN;
  END IF;

  -- Calculate totals
  RETURN QUERY
  WITH putovanja_stats AS (
    SELECT 
      COALESCE(SUM(cena), 0.0) as putovanja_cena,
      COUNT(*)::INTEGER as putovanja_count
    FROM putovanja_istorija
    WHERE vozac_id = v_vozac_id
      AND datum_putovanja = p_datum
      AND obrisan = false
      AND status = 'obavljeno'
  ),
  dnevni_stats AS (
    SELECT 
      COALESCE(SUM(cena), 0.0) as dnevni_cena,
      COUNT(*)::INTEGER as dnevni_count
    FROM dnevni_putnici
    WHERE vozac_id = v_vozac_id
      AND datum_putovanja = p_datum
      AND obrisan = false
      AND status IN ('pokupljen', 'završen', 'naplačen')
  )
  SELECT 
    p.putovanja_cena::DECIMAL,
    d.dnevni_cena::DECIMAL,
    (p.putovanja_cena + d.dnevni_cena)::DECIMAL as ukupni_pazar,
    p.putovanja_count,
    d.dnevni_count,
    (p.putovanja_count + d.dnevni_count)::INTEGER as ukupno
  FROM putovanja_stats p
  CROSS JOIN dnevni_stats d;
END;
$$;

COMMENT ON FUNCTION calculate_daily_pazar(TEXT, DATE) IS 
'Calculates total daily earnings (pazar) for a driver combining putovanja_istorija and dnevni_putnici.';


-- =====================================================
-- 3️⃣ GET MONTHLY STATS
-- =====================================================
-- Returns monthly statistics for a vozac
-- Aggregates data across entire month
-- =====================================================

CREATE OR REPLACE FUNCTION get_monthly_stats(
  p_vozac_ime TEXT,
  p_mesec DATE  -- First day of month
)
RETURNS TABLE (
  broj_mesecnih_karata INTEGER,
  ukupno_putovanja INTEGER,
  ukupna_zarada DECIMAL,
  prosecna_dnevna_zarada DECIMAL,
  broj_radnih_dana INTEGER,
  mesec DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_vozac_id UUID;
  v_first_day DATE;
  v_last_day DATE;
BEGIN
  -- Get vozac_id
  SELECT id INTO v_vozac_id
  FROM vozaci
  WHERE ime = p_vozac_ime
    AND aktivan = true
    AND obrisan = false;

  IF v_vozac_id IS NULL THEN
    RETURN QUERY SELECT 0, 0, 0.0::DECIMAL, 0.0::DECIMAL, 0, p_mesec;
    RETURN;
  END IF;

  -- Calculate month boundaries
  v_first_day := DATE_TRUNC('month', p_mesec);
  v_last_day := DATE_TRUNC('month', p_mesec) + INTERVAL '1 month' - INTERVAL '1 day';

  RETURN QUERY
  WITH mesecni_karte AS (
    SELECT COUNT(DISTINCT id)::INTEGER as count
    FROM mesecni_putnici
    WHERE vozac_id = v_vozac_id
      AND aktivan = true
      AND obrisan = false
      AND datum_pocetka_meseca >= v_first_day
      AND datum_pocetka_meseca <= v_last_day
  ),
  putovanja_total AS (
    SELECT 
      COUNT(*)::INTEGER as count,
      COALESCE(SUM(cena), 0.0) as total_cena
    FROM putovanja_istorija
    WHERE vozac_id = v_vozac_id
      AND obrisan = false
      AND datum_putovanja >= v_first_day
      AND datum_putovanja <= v_last_day
  ),
  dnevni_total AS (
    SELECT 
      COUNT(*)::INTEGER as count,
      COALESCE(SUM(cena), 0.0) as total_cena
    FROM dnevni_putnici
    WHERE vozac_id = v_vozac_id
      AND obrisan = false
      AND datum_putovanja >= v_first_day
      AND datum_putovanja <= v_last_day
  ),
  radni_dani AS (
    SELECT COUNT(DISTINCT datum_putovanja)::INTEGER as count
    FROM (
      SELECT datum_putovanja FROM putovanja_istorija
      WHERE vozac_id = v_vozac_id
        AND datum_putovanja >= v_first_day
        AND datum_putovanja <= v_last_day
        AND obrisan = false
      UNION
      SELECT datum_putovanja FROM dnevni_putnici
      WHERE vozac_id = v_vozac_id
        AND datum_putovanja >= v_first_day
        AND datum_putovanja <= v_last_day
        AND obrisan = false
    ) all_dates
  )
  SELECT 
    mk.count as broj_mesecnih_karata,
    (pt.count + dt.count)::INTEGER as ukupno_putovanja,
    (pt.total_cena + dt.total_cena)::DECIMAL as ukupna_zarada,
    CASE 
      WHEN rd.count > 0 THEN ((pt.total_cena + dt.total_cena) / rd.count)::DECIMAL
      ELSE 0.0::DECIMAL
    END as prosecna_dnevna_zarada,
    rd.count as broj_radnih_dana,
    v_first_day as mesec
  FROM mesecni_karte mk
  CROSS JOIN putovanja_total pt
  CROSS JOIN dnevni_total dt
  CROSS JOIN radni_dani rd;
END;
$$;

COMMENT ON FUNCTION get_monthly_stats(TEXT, DATE) IS 
'Returns comprehensive monthly statistics for a driver including trips, earnings, and averages.';


-- =====================================================
-- 4️⃣ UPDATE KUSUR BATCH
-- =====================================================
-- Updates kusur for multiple vozaci in a single transaction
-- Used for end-of-day reconciliation
-- =====================================================

CREATE OR REPLACE FUNCTION update_kusur_batch(
  p_updates JSONB  -- Array of {vozac_ime: string, new_kusur: number}
)
RETURNS TABLE (
  vozac_ime TEXT,
  old_kusur DECIMAL,
  new_kusur DECIMAL,
  success BOOLEAN,
  error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_update JSONB;
  v_vozac_ime TEXT;
  v_new_kusur DECIMAL;
  v_old_kusur DECIMAL;
  v_rows_affected INTEGER;
BEGIN
  -- Loop through each update
  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    BEGIN
      v_vozac_ime := v_update->>'vozac_ime';
      v_new_kusur := (v_update->>'new_kusur')::DECIMAL;

      -- Get old kusur value
      SELECT kusur INTO v_old_kusur
      FROM vozaci
      WHERE ime = v_vozac_ime
        AND aktivan = true
        AND obrisan = false;

      -- Update kusur
      UPDATE vozaci
      SET 
        kusur = v_new_kusur,
        updated_at = NOW()
      WHERE ime = v_vozac_ime
        AND aktivan = true
        AND obrisan = false;

      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

      -- Return result
      IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 
          v_vozac_ime, 
          COALESCE(v_old_kusur, 0.0), 
          v_new_kusur, 
          true, 
          NULL::TEXT;
      ELSE
        RETURN QUERY SELECT 
          v_vozac_ime, 
          COALESCE(v_old_kusur, 0.0), 
          v_new_kusur, 
          false, 
          'Vozac not found or inactive'::TEXT;
      END IF;

    EXCEPTION WHEN OTHERS THEN
      RETURN QUERY SELECT 
        v_vozac_ime, 
        COALESCE(v_old_kusur, 0.0), 
        v_new_kusur, 
        false, 
        SQLERRM::TEXT;
    END;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION update_kusur_batch(JSONB) IS 
'Batch update kusur values for multiple drivers. Input: [{vozac_ime: "Name", new_kusur: 123.45}, ...]';


-- =====================================================
-- 5️⃣ AUTO-UPDATE TRIGGER FOR VOZACI.KUSUR
-- =====================================================
-- Automatically recalculates and updates vozaci.kusur
-- when daily_checkins table changes
-- =====================================================

CREATE OR REPLACE FUNCTION trigger_update_vozac_kusur()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_vozac_ime TEXT;
  v_calculated_kusur DECIMAL;
BEGIN
  -- Determine which vozac to update
  IF TG_OP = 'DELETE' THEN
    v_vozac_ime := OLD.vozac;
  ELSE
    v_vozac_ime := NEW.vozac;
  END IF;

  -- Calculate kusur from last 30 days of daily_checkins
  SELECT COALESCE(SUM(sitan_novac - dnevni_pazari), 0.0)
  INTO v_calculated_kusur
  FROM daily_checkins
  WHERE vozac = v_vozac_ime
    AND obrisan = false
    AND datum >= CURRENT_DATE - INTERVAL '30 days';

  -- Update vozaci.kusur
  UPDATE vozaci
  SET 
    kusur = v_calculated_kusur,
    updated_at = NOW()
  WHERE ime = v_vozac_ime
    AND aktivan = true;

  -- Log the update for debugging
  RAISE NOTICE 'Updated kusur for %: % (from % daily checkins)', 
    v_vozac_ime, 
    v_calculated_kusur,
    (SELECT COUNT(*) FROM daily_checkins 
     WHERE vozac = v_vozac_ime 
       AND obrisan = false 
       AND datum >= CURRENT_DATE - INTERVAL '30 days');

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_auto_update_vozac_kusur ON daily_checkins;

-- Create trigger
CREATE TRIGGER trigger_auto_update_vozac_kusur
  AFTER INSERT OR UPDATE OR DELETE ON daily_checkins
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_vozac_kusur();

COMMENT ON TRIGGER trigger_auto_update_vozac_kusur ON daily_checkins IS 
'Auto-updates vozaci.kusur whenever daily_checkins table changes. Ensures single source of truth.';


-- =====================================================
-- 6️⃣ GET KUSUR TRANSACTIONS
-- =====================================================
-- Returns last N daily_checkins for a vozac
-- Used to populate KusurData.transactions list
-- =====================================================

CREATE OR REPLACE FUNCTION get_kusur_transactions(
  p_vozac_ime TEXT,
  p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
  datum DATE,
  sitan_novac DECIMAL,
  dnevni_pazari DECIMAL,
  kusur DECIMAL,
  status TEXT,
  checkin_vreme TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dc.datum,
    COALESCE(dc.sitan_novac, 0.0)::DECIMAL,
    COALESCE(dc.dnevni_pazari, 0.0)::DECIMAL,
    (COALESCE(dc.sitan_novac, 0.0) - COALESCE(dc.dnevni_pazari, 0.0))::DECIMAL as kusur,
    dc.status::TEXT,
    dc.checkin_vreme
  FROM daily_checkins dc
  WHERE dc.vozac = p_vozac_ime
    AND dc.obrisan = false
    AND dc.datum >= CURRENT_DATE - (p_days || ' days')::INTERVAL
  ORDER BY dc.datum DESC, dc.checkin_vreme DESC;
END;
$$;

COMMENT ON FUNCTION get_kusur_transactions(TEXT, INTEGER) IS 
'Returns daily checkin transactions for a driver for the last N days. Default 30 days.';


-- =====================================================
-- 7️⃣ FIX NULL KUSUR VALUES
-- =====================================================
-- One-time fix for existing vozaci with NULL kusur
-- Sets kusur = 0.0 where NULL
-- =====================================================

DO $$ 
BEGIN
  UPDATE vozaci
  SET kusur = 0.0
  WHERE kusur IS NULL
    AND aktivan = true;

  RAISE NOTICE 'Fixed % vozaci with NULL kusur', 
    (SELECT COUNT(*) FROM vozaci WHERE kusur = 0.0);
END $$;


-- =====================================================
-- 8️⃣ GRANT PERMISSIONS
-- =====================================================
-- Grant execute permissions to authenticated users
-- =====================================================

GRANT EXECUTE ON FUNCTION get_vozac_kusur(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_daily_pazar(TEXT, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_monthly_stats(TEXT, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION update_kusur_batch(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_kusur_transactions(TEXT, INTEGER) TO authenticated;


-- =====================================================
-- ✅ MIGRATION COMPLETE
-- =====================================================
-- Created RPC functions:
--   1. get_vozac_kusur(vozac_ime)
--   2. calculate_daily_pazar(vozac_ime, datum)
--   3. get_monthly_stats(vozac_ime, mesec)
--   4. update_kusur_batch(updates_json)
--   5. get_kusur_transactions(vozac_ime, days)
--
-- Created trigger:
--   - trigger_auto_update_vozac_kusur on daily_checkins
--
-- Fixed data:
--   - Set kusur = 0.0 where NULL
-- =====================================================
