-- migrations/009_create_indexes.sql
-- Run each statement below *separately* in Supabase SQL Editor (CONCURRENTLY cannot run inside a transaction).

-- 1) JSONB index for polasci_po_danu
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_polasci_gin ON mesecni_putnici USING gin (polasci_po_danu jsonb_path_ops);

-- 2) GIN index for radni_dani_arr (text[])
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_radni_dani_gin ON mesecni_putnici USING gin (radni_dani_arr);

-- 3) JSONB index for statistics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_statistics_gin ON mesecni_putnici USING gin (statistics jsonb_path_ops);
