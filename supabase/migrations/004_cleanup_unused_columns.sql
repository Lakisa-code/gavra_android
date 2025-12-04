-- ============================================
-- 🧹 ČIŠĆENJE NEPOTREBNIH KOLONA - FAZA 1
-- Sigurno brisanje duplikata i legacy kolona
-- ============================================
-- NAPOMENA: Pre pokretanja napravi BACKUP!
-- ============================================

-- ==========================================
-- TABELA: mesecni_putnici
-- ==========================================

-- 1️⃣ DUPLIKATI - iste vrednosti pod drugim imenom
-- ------------------------------------------------
-- `activan` je duplikat od `aktivan` (typo)
-- Provera pre brisanja:
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN aktivan != activan THEN 1 END) as razlike
FROM mesecni_putnici;
-- Ako ima razlike, NE BRIŠI! Ako nema, slobodno briši:

ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS activan;

-- `kreiran` je duplikat od `created_at` (uvek null)
-- `azuriran` je duplikat od `updated_at` (uvek null)
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS kreiran;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS azuriran;

-- `ukupno_voznji` je duplikat od `broj_putovanja`
-- Provera:
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN ukupno_voznji != broj_putovanja THEN 1 END) as razlike
FROM mesecni_putnici;

ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS ukupno_voznji;


-- 2️⃣ LEGACY POLASCI - zamenjeno sa polasci_po_danu JSON
-- -------------------------------------------------------
-- Ove kolone su bile za pojedinačne dane, sada je sve u JSON
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_sub_bc;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_sub_vs;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_ned_bc;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_ned_vs;


-- 3️⃣ LEGACY ADRESA/GRAD - zamenjeno sa adresa_*_id
-- --------------------------------------------------
-- Stare string kolone, sada se koriste UUID reference
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS grad;


-- 4️⃣ NIKAD KORIŠĆENE REFERENCE
-- ------------------------------
-- Ove kolone su uvek null u bazi
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS ruta_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS vozilo_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa_polaska_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa_dolaska_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS putovanja_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS user_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS tip_prevoza;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS posebne_napomene;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS firma;


-- ==========================================
-- TABELA: putovanja_istorija
-- ==========================================

-- Nikad korišćene reference
ALTER TABLE putovanja_istorija DROP COLUMN IF EXISTS ruta_id;
ALTER TABLE putovanja_istorija DROP COLUMN IF EXISTS vozilo_id;


-- ==========================================
-- 📊 IZVEŠTAJ O PROMENI
-- ==========================================
-- Pre: ~50 kolona u mesecni_putnici
-- Posle: ~30 kolona
-- Ušteda: ~40% manje kolona

-- KOLONE KOJE SU OSTALE U mesecni_putnici:
-- ✅ id, putnik_ime, tip, tip_skole
-- ✅ broj_telefona, broj_telefona_oca, broj_telefona_majke
-- ✅ polasci_po_danu, tip_prikazivanja, radni_dani
-- ✅ aktivan, status
-- ✅ datum_pocetka_meseca, datum_kraja_meseca
-- ✅ ukupna_cena_meseca, cena
-- ✅ broj_putovanja, broj_otkazivanja, poslednje_putovanje
-- ✅ vreme_placanja, placeni_mesec, placena_godina, placeno, datum_placanja
-- ✅ vozac_id, pokupljen, vreme_pokupljenja
-- ✅ statistics, obrisan
-- ✅ created_at, updated_at, updated_by
-- ✅ adresa_bela_crkva_id, adresa_vrsac_id
-- ✅ napomena
-- ✅ action_log, dodali_vozaci


-- ⚠️ NAPOMENA: Ove kolone su OSTAVLJENE jer se možda koriste:
-- - tip_skole, broj_telefona_oca, broj_telefona_majke (za đake)
-- - tip_prikazivanja (UI razlikovanje)
-- - statistics (keširanje)
-- - placeni_mesec, placena_godina (izveštaji)
-- - datum_pocetka_meseca, datum_kraja_meseca (period plaćanja)
