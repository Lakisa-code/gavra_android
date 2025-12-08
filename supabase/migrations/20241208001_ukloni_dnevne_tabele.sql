-- Migracija: Uklanjanje tabela za dnevne putnike
-- Datum: 2024-12-08
-- Opis: Ujedinjujemo sistem - svi putnici su sada u mesecni_putnici tabeli sa tipom: radnik/ucenik/dnevni

-- ⚠️ OPREZ: Ova migracija briše tabele! Pokreni samo ako si siguran da podaci nisu potrebni.

-- 1. Obriši tabelu dnevni_putnici_registrovani
DROP TABLE IF EXISTS dnevni_putnici_registrovani CASCADE;

-- 2. Obriši tabelu dnevni_putnici (stara tabela)
DROP TABLE IF EXISTS dnevni_putnici CASCADE;

-- NAPOMENA: zahtevi_pristupa tabela se NE briše jer se koristi za vozače u auth_screen.dart

-- Komentar za dokumentaciju
COMMENT ON COLUMN mesecni_putnici.tip IS 'Tip putnika: radnik (700 RSD/dan), ucenik (600 RSD/dan), dnevni (po dogovoru)';
