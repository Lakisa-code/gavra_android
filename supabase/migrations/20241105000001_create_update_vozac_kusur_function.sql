-- Migration: Create update_vozac_kusur RPC function
-- This function provides reliable updating of vozac kusur values
-- handling numeric types properly for PostgreSQL

CREATE OR REPLACE FUNCTION update_vozac_kusur(vozac_ime TEXT, novi_kusur NUMERIC)
RETURNS VOID AS $$
BEGIN
  -- Update kusur for the specified vozac
  UPDATE vozaci 
  SET 
    kusur = novi_kusur, 
    updated_at = NOW() 
  WHERE ime = vozac_ime;
  
  -- Check if update was successful
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vozač sa imenom % nije pronađen', vozac_ime;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION update_vozac_kusur(TEXT, NUMERIC) TO authenticated;

-- Comment the function
COMMENT ON FUNCTION update_vozac_kusur(TEXT, NUMERIC) IS 'Updates kusur value for a specific vozac by name';