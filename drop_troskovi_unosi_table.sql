-- Uklanjanje neaktivne tabele troskovi_unosi
-- Tabela je bila pripremljena ali se nikada nije koristila u aplikaciji

-- Prvo uklonimo indekse
DROP INDEX IF EXISTS idx_troskovi_datum;
DROP INDEX IF EXISTS idx_troskovi_tip;
DROP INDEX IF EXISTS idx_troskovi_vozac_id;
DROP INDEX IF EXISTS idx_troskovi_vozac_datum;

-- Zatim uklonimo tabelu
DROP TABLE IF EXISTS troskovi_unosi;

-- Verifikacija da je tabela uklonjena
SELECT 'troskovi_unosi tabela uspešno uklonjena' as status;