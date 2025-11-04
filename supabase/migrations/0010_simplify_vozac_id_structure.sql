-- 🚀 Simplifikacija vozac_id strukture - umesto 5 kolona → 3 kolone
-- Kreiran: 4. novembar 2025
-- Cilj: Uklanja redundantne vozac_id kolone i koristi action_log JSONB

-- 1️⃣ DODAJ NOVE KOLONE
ALTER TABLE dnevni_putnici 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES vozaci(id),
ADD COLUMN IF NOT EXISTS action_log JSONB DEFAULT '{}';

ALTER TABLE putovanja_istorija 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES vozaci(id),
ADD COLUMN IF NOT EXISTS action_log JSONB DEFAULT '{}';

-- 2️⃣ MIGRIRAJ POSTOJEĆE PODATKE u action_log
-- Za dnevni_putnici
UPDATE dnevni_putnici SET 
  created_by = dodao_vozac_id,
  action_log = jsonb_build_object(
    'created_by', dodao_vozac_id,
    'paid_by', naplatio_vozac_id,
    'picked_by', pokupio_vozac_id,
    'cancelled_by', otkazao_vozac_id,
    'created_at', COALESCE(created_at, NOW()),
    'actions', '[]'::jsonb
  )
WHERE action_log = '{}' OR action_log IS NULL;

-- Za putovanja_istorija 
UPDATE putovanja_istorija SET
  created_by = vozac_id, -- Koristimo vozac_id kao created_by fallback
  action_log = jsonb_build_object(
    'created_by', vozac_id,
    'primary_driver', vozac_id,
    'created_at', COALESCE(created_at, NOW()),
    'actions', '[]'::jsonb
  )
WHERE action_log = '{}' OR action_log IS NULL;

-- 3️⃣ BACKUP STARE PODATKE (za sigurnost)
CREATE TABLE IF NOT EXISTS vozac_id_backup AS 
SELECT 
  id,
  dodao_vozac_id,
  pokupio_vozac_id, 
  naplatio_vozac_id,
  otkazao_vozac_id,
  vozac_id,
  'dnevni_putnici' as source_table,
  NOW() as backup_created
FROM dnevni_putnici 
WHERE dodao_vozac_id IS NOT NULL 
   OR pokupio_vozac_id IS NOT NULL 
   OR naplatio_vozac_id IS NOT NULL 
   OR otkazao_vozac_id IS NOT NULL;

-- 4️⃣ UKLONI REDUNDANTNE KOLONE (komentarisano za sigurnost)
-- ALTER TABLE dnevni_putnici DROP COLUMN IF EXISTS dodao_vozac_id;
-- ALTER TABLE dnevni_putnici DROP COLUMN IF EXISTS pokupio_vozac_id;
-- ALTER TABLE dnevni_putnici DROP COLUMN IF EXISTS naplatio_vozac_id;
-- ALTER TABLE dnevni_putnici DROP COLUMN IF EXISTS otkazao_vozac_id;

-- 5️⃣ DODAJ KOMENTARE
COMMENT ON COLUMN dnevni_putnici.created_by IS 'UUID vozača koji je kreirao putnika';
COMMENT ON COLUMN dnevni_putnici.action_log IS 'JSONB log svih akcija: created_by, paid_by, picked_by, cancelled_by';
COMMENT ON COLUMN dnevni_putnici.vozac_id IS 'Glavni/trenutni vozač za putnika';

COMMENT ON COLUMN putovanja_istorija.created_by IS 'UUID vozača koji je kreirao putovanje';
COMMENT ON COLUMN putovanja_istorija.action_log IS 'JSONB log svih akcija za putovanje';

-- 6️⃣ DODAJ INDEKSE za performanse
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_created_by ON dnevni_putnici(created_by);
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_action_log ON dnevni_putnici USING GIN(action_log);

CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_created_by ON putovanja_istorija(created_by);  
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_action_log ON putovanja_istorija USING GIN(action_log);

-- 7️⃣ VALIDACIJA
DO $$
BEGIN
    RAISE NOTICE 'Migracija završena. Proveri rezultate:';
    RAISE NOTICE 'dnevni_putnici backup redova: %', (SELECT COUNT(*) FROM vozac_id_backup);
    RAISE NOTICE 'dnevni_putnici sa action_log: %', (SELECT COUNT(*) FROM dnevni_putnici WHERE action_log != '{}');
    RAISE NOTICE 'putovanja_istorija sa action_log: %', (SELECT COUNT(*) FROM putovanja_istorija WHERE action_log != '{}');
END $$;