-- Migracija: Brisanje nekorišćene tabele 'rute'
-- Datum: 2025-12-04
-- Razlog: Tabela je prazna i ne koristi se nigde u kodu

DROP TABLE IF EXISTS rute CASCADE;
