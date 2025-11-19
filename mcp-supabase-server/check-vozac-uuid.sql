-- Test script to check vozac with specific UUID
SELECT 
  id,
  ime,
  puno_ime
FROM vozaci 
WHERE id = '0B861b65-7f26-4125-8e5d-93ce637c8d6d'

UNION ALL

SELECT 
  id,
  ime,
  puno_ime  
FROM vozaci 
WHERE LOWER(id) = LOWER('0B861b65-7f26-4125-8e5d-93ce637c8d6d')

UNION ALL

-- Show all vozaci for reference
SELECT 
  id,
  ime,
  puno_ime
FROM vozaci
ORDER BY ime;