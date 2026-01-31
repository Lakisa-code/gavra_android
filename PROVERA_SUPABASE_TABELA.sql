-- PROVERA SVIH TABELA U SUPABASE
-- Pokrenite ovaj query u Supabase SQL Editor-u

-- Lista svih tabela u public schema
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Broj tabela
SELECT
    COUNT(*) as ukupno_tabela
FROM pg_tables
WHERE schemaname = 'public';

-- Detalji o tabelama
SELECT
    t.table_name,
    t.table_type,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default
FROM information_schema.tables t
LEFT JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE t.table_schema = 'public'
AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name, c.ordinal_position;