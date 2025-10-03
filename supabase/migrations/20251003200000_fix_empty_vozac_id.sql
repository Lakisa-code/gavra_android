-- Fix empty string vozac_id values
-- Created: 2025-01-03

-- Update empty string vozac_id to NULL (using CAST to avoid UUID validation)
UPDATE mesecni_putnici 
SET vozac_id = NULL 
WHERE vozac_id::text = '';

-- Verify the fix
SELECT 
  id, 
  putnik_ime, 
  vozac_id
FROM mesecni_putnici 
WHERE vozac_id IS NULL
LIMIT 5;