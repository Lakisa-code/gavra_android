-- ============================================================================
-- DIJAGNOSTIKA: Problem sa nepotpunim plaćanjem za Sašku Notar
-- ============================================================================

-- 1. Trenutno stanje - Pogledaj kompletan JSON za Sašku
SELECT 
    id,
    putnik_ime,
    polasci_po_danu,
    updated_at,
    created_at
FROM registrovani_putnici 
WHERE putnik_ime ILIKE '%notar%';

-- 2. Ekstrahuj samo četvrtak (CET) iz JSON-a
SELECT 
    id,
    putnik_ime,
    polasci_po_danu::jsonb->'cet' as cet_data,
    polasci_po_danu::jsonb->'cet'->'bc_placeno' as bc_placeno,
    polasci_po_danu::jsonb->'cet'->'vs_placeno' as vs_placeno,
    polasci_po_danu::jsonb->'cet'->'bc_placeno_iznos' as bc_placeno_iznos,
    polasci_po_danu::jsonb->'cet'->'vs_placeno_iznos' as vs_placeno_iznos
FROM registrovani_putnici 
WHERE putnik_ime ILIKE '%notar%';

-- 3. Provjeri ako je bilo kakvo plaćanje za VS upisano u voznje_log
SELECT 
    vl.id,
    vl.putnik_id,
    rp.putnik_ime,
    vl.datum,
    vl.tip,
    vl.iznos,
    vl.created_at
FROM voznje_log vl
LEFT JOIN registrovani_putnici rp ON vl.putnik_id = rp.id
WHERE rp.putnik_ime ILIKE '%notar%' 
  AND vl.tip IN ('uplata', 'uplata_dnevna', 'uplata_mesecna')
ORDER BY vl.created_at DESC;

-- 4. Provjeri sve izmjene za ovog putnika (updated_at timeline)
SELECT 
    id,
    putnik_ime,
    created_at,
    updated_at,
    (updated_at - created_at) as koliko_je_proslao_dan
FROM registrovani_putnici 
WHERE putnik_ime ILIKE '%notar%';

-- 5. Analiza JSON strukture - šta ima i šta nedostaje
SELECT 
    putnik_ime,
    jsonb_keys(polasci_po_danu::jsonb->'cet') as dostupne_opcije_u_cetu,
    polasci_po_danu::jsonb->'cet' as kompletno_cet_stanje
FROM registrovani_putnici 
WHERE putnik_ime ILIKE '%notar%';
