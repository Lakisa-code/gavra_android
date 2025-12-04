-- 🧹 KOPIRAJ OVO U SUPABASE SQL EDITOR
-- https://supabase.com/dashboard/project/gjtabtwudbrmfeyjiicu/sql

-- MESECNI_PUTNICI - brisanje nepotrebnih kolona
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS activan;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS kreiran;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS azuriran;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS ukupno_voznji;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_sub_bc;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_sub_vs;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_ned_bc;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_ned_vs;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS grad;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS ruta_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS vozilo_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa_polaska_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa_dolaska_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS putovanja_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS user_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS tip_prevoza;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS posebne_napomene;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS firma;

-- PUTOVANJA_ISTORIJA - brisanje nepotrebnih kolona
ALTER TABLE putovanja_istorija DROP COLUMN IF EXISTS ruta_id;
ALTER TABLE putovanja_istorija DROP COLUMN IF EXISTS vozilo_id;

-- PROVERA: Ispisi broj kolona posle
SELECT 'mesecni_putnici' as tabela, count(*) as kolona_count 
FROM information_schema.columns 
WHERE table_name = 'mesecni_putnici'
UNION ALL
SELECT 'putovanja_istorija', count(*) 
FROM information_schema.columns 
WHERE table_name = 'putovanja_istorija';
