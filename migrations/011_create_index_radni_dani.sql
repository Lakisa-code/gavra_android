-- migrations/011_create_index_radni_dani.sql
-- Create GIN index on `radni_dani_arr` (run as a single statement)

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_radni_dani_gin
ON public.mesecni_putnici USING gin (radni_dani_arr);
