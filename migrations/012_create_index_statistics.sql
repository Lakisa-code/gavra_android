-- migrations/012_create_index_statistics.sql
-- Create GIN index on `statistics` jsonb (run as a single statement)

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_statistics_gin
ON public.mesecni_putnici USING gin (statistics jsonb_path_ops);
