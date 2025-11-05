-- Migration: Helper function for matching days in comma-separated strings
-- This provides a PostgreSQL function for precise day matching in radni_dani field

CREATE OR REPLACE FUNCTION contains_day(radni_dani_str TEXT, day_abbr TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if day_abbr exists in comma-separated list
  -- Handles null values and trims whitespace
  IF radni_dani_str IS NULL OR day_abbr IS NULL THEN
    RETURN FALSE;
  END IF;
  
  RETURN day_abbr = ANY(
    SELECT trim(unnest(string_to_array(radni_dani_str, ',')))
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION contains_day(TEXT, TEXT) TO authenticated;

-- Comment the function
COMMENT ON FUNCTION contains_day(TEXT, TEXT) IS 'Check if a day abbreviation exists in comma-separated radni_dani string';