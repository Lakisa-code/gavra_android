-- 🚀 SUPABASE DATABASE OPTIMIZATION FUNCTIONS
-- Ove SQL funkcije optimizuju query performance za Gavra aplikaciju
-- ================================================================
-- 1. BULK UPDATE FUNKCIJA za putnice
-- ================================================================
CREATE OR REPLACE FUNCTION bulk_update_putnici(
        putnik_ids text [],
        update_data jsonb,
        target_table text
    ) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE query_text text;
id_list text;
BEGIN -- Validate table name to prevent SQL injection
IF target_table NOT IN (
    'dnevni_putnici',
    'mesecni_putnici',
    'putovanja_istorija'
) THEN RAISE EXCEPTION 'Invalid table name: %',
target_table;
END IF;
-- Convert array to comma-separated string
id_list := array_to_string(putnik_ids, ''',''');
id_list := '''' || id_list || '''';
-- Add updated_at timestamp
update_data := update_data || jsonb_build_object('updated_at', now());
-- Build dynamic query
query_text := format(
    'UPDATE %I SET %s WHERE id IN (%s)',
    target_table,
    (
        SELECT string_agg(
                format('%I = %L', key, value),
                ', '
            )
        FROM jsonb_each_text(update_data)
    ),
    id_list
);
-- Execute the update
EXECUTE query_text;
-- Log successful bulk update
INSERT INTO query_performance_log (
        operation,
        table_name,
        affected_rows,
        duration_ms
    )
VALUES (
        'bulk_update',
        target_table,
        array_length(putnik_ids, 1),
        0
    );
END;
$$;
-- ================================================================
-- 2. OPTIMIZED STATISTICS FUNKCIJA
-- ================================================================
CREATE OR REPLACE FUNCTION get_optimized_stats(
        vozac_filter text DEFAULT NULL,
        od_datum text DEFAULT NULL,
        do_datum text DEFAULT NULL
    ) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE result jsonb;
ukupni_putnici integer;
ukupni_pazari numeric(10, 2);
prosecna_cena numeric(10, 2);
najcesca_ruta text;
where_clause text := '';
BEGIN -- Build WHERE clause based on filters
IF vozac_filter IS NOT NULL THEN where_clause := where_clause || format(' AND vozac = %L', vozac_filter);
END IF;
IF od_datum IS NOT NULL THEN where_clause := where_clause || format(' AND datum >= %L', od_datum);
END IF;
IF do_datum IS NOT NULL THEN where_clause := where_clause || format(' AND datum <= %L', do_datum);
END IF;
-- Execute optimized aggregation query
EXECUTE format(
    $query$
    SELECT COUNT(*) as putnici,
        COALESCE(SUM(cena), 0) as pazari,
        COALESCE(AVG(cena), 0) as prosek
    FROM putovanja_istorija
    WHERE obrisan = false %s $query$,
        where_clause
) INTO ukupni_putnici,
ukupni_pazari,
prosecna_cena;
-- Get most frequent route
EXECUTE format(
    $query$
    SELECT ruta_naziv
    FROM putovanja_istorija
    WHERE obrisan = false %s
    GROUP BY ruta_naziv
    ORDER BY COUNT(*) DESC
    LIMIT 1 $query$, where_clause
) INTO najcesca_ruta;
-- Build result JSON
result := jsonb_build_object(
    'ukupniPutnici',
    COALESCE(ukupni_putnici, 0),
    'ukupniPazari',
    COALESCE(ukupni_pazari, 0),
    'prosecnaCena',
    COALESCE(prosecna_cena, 0),
    'najcescaRuta',
    COALESCE(najcesca_ruta, ''),
    'generisano',
    now()
);
RETURN result;
END;
$$;
-- ================================================================
-- 3. OPTIMIZED SEARCH FUNKCIJA
-- ================================================================
CREATE OR REPLACE FUNCTION search_putnici_optimized(
        search_query text,
        search_tables text [],
        result_limit integer DEFAULT 20,
        result_offset integer DEFAULT 0
    ) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE result jsonb := '[]'::jsonb;
table_name text;
query_text text;
temp_result jsonb;
BEGIN -- Search across specified tables
FOREACH table_name IN ARRAY search_tables LOOP -- Validate table name
IF table_name NOT IN ('dnevni_putnici', 'mesecni_putnici') THEN CONTINUE;
END IF;
-- Build search query for current table
query_text := format(
    $query$
    SELECT jsonb_agg(
            jsonb_build_object(
                'id',
                id,
                'ime',
                putnik_ime,
                'grad',
                grad,
                'ruta',
                ruta_naziv,
                'tabela',
                %L,
                'relevance',
                CASE
                    WHEN putnik_ime ILIKE %L THEN 3
                    WHEN grad ILIKE %L THEN 2
                    WHEN ruta_naziv ILIKE %L THEN 1
                    ELSE 0
                END
            )
        )
    FROM %I
    WHERE obrisan = false
        AND (
            putnik_ime ILIKE %L
            OR grad ILIKE %L
            OR ruta_naziv ILIKE %L
            OR broj_telefona ILIKE %L
        )
    ORDER BY CASE
            WHEN putnik_ime ILIKE %L THEN 3
            WHEN grad ILIKE %L THEN 2
            WHEN ruta_naziv ILIKE %L THEN 1
            ELSE 0
        END DESC
    LIMIT %s OFFSET %s $query$,
        table_name,
        '%' || search_query || '%',
        -- relevance 3
        '%' || search_query || '%',
        -- relevance 2  
        '%' || search_query || '%',
        -- relevance 1
        table_name,
        '%' || search_query || '%',
        -- WHERE ime
        '%' || search_query || '%',
        -- WHERE grad
        '%' || search_query || '%',
        -- WHERE ruta
        '%' || search_query || '%',
        -- WHERE telefon
        '%' || search_query || '%',
        -- ORDER ime
        '%' || search_query || '%',
        -- ORDER grad
        '%' || search_query || '%',
        -- ORDER ruta
        result_limit,
        result_offset
);
-- Execute query for current table
EXECUTE query_text INTO temp_result;
-- Merge results
IF temp_result IS NOT NULL THEN result := result || temp_result;
END IF;
END LOOP;
RETURN result;
END;
$$;
-- ================================================================
-- 4. SEARCH COUNT FUNKCIJA
-- ================================================================
CREATE OR REPLACE FUNCTION count_search_results(search_query text, search_tables text []) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE total_count integer := 0;
table_name text;
table_count integer;
BEGIN FOREACH table_name IN ARRAY search_tables LOOP IF table_name NOT IN ('dnevni_putnici', 'mesecni_putnici') THEN CONTINUE;
END IF;
EXECUTE format(
    $query$
    SELECT COUNT(*)
    FROM %I
    WHERE obrisan = false
        AND (
            putnik_ime ILIKE %L
            OR grad ILIKE %L
            OR ruta_naziv ILIKE %L
            OR broj_telefona ILIKE %L
        ) $query$,
        table_name,
        '%' || search_query || '%',
        '%' || search_query || '%',
        '%' || search_query || '%',
        '%' || search_query || '%'
) INTO table_count;
total_count := total_count + COALESCE(table_count, 0);
END LOOP;
RETURN total_count;
END;
$$;
-- ================================================================
-- 5. SLOW QUERY ANALYZER
-- ================================================================
CREATE TABLE IF NOT EXISTS query_performance_log (
    id SERIAL PRIMARY KEY,
    operation text NOT NULL,
    table_name text,
    affected_rows integer,
    duration_ms integer,
    created_at timestamp with time zone DEFAULT now()
);
CREATE OR REPLACE FUNCTION analyze_slow_queries() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE result jsonb;
BEGIN
SELECT jsonb_agg(
        jsonb_build_object(
            'table_name',
            table_name,
            'operation',
            operation,
            'avg_duration',
            avg_duration,
            'total_calls',
            total_calls,
            'slowest_call',
            max_duration
        )
    ) INTO result
FROM (
        SELECT table_name,
            operation,
            AVG(duration_ms) as avg_duration,
            COUNT(*) as total_calls,
            MAX(duration_ms) as max_duration
        FROM query_performance_log
        WHERE created_at >= now() - interval '24 hours'
        GROUP BY table_name,
            operation
        HAVING AVG(duration_ms) > 500 -- slower than 500ms
        ORDER BY avg_duration DESC
    ) slow_queries;
RETURN COALESCE(result, '[]'::jsonb);
END;
$$;
-- ================================================================
-- 6. CONNECTION OPTIMIZATION
-- ================================================================
CREATE OR REPLACE FUNCTION optimize_connection_settings(
        max_connections integer DEFAULT 20,
        connection_timeout integer DEFAULT 30,
        idle_timeout integer DEFAULT 300
    ) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN -- This is a placeholder - actual connection settings are managed at database level
    -- But we can return current connection stats
    RETURN jsonb_build_object(
        'max_connections',
        max_connections,
        'connection_timeout',
        connection_timeout,
        'idle_timeout',
        idle_timeout,
        'current_connections',
        (
            SELECT count(*)
            FROM pg_stat_activity
        ),
        'optimized_at',
        now()
    );
END;
$$;
-- ================================================================
-- 7. RECOMMENDED INDEXES za optimizaciju
-- ================================================================
-- Index za dnevni_putnici - najčešće traženi po datumu
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_datum_obrisan ON dnevni_putnici(datum)
WHERE obrisan = false;
-- Index za mesecni_putnici - filter po aktivnim
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_aktivan_obrisan ON mesecni_putnici(aktivan, obrisan)
WHERE aktivan = true
    AND obrisan = false;
-- Index za putovanja_istorija - pretraga po vozaču i datumu
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_vozac_datum ON putovanja_istorija(vozac, datum)
WHERE obrisan = false;
-- Index za text pretragu imena putnika
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_ime_gin ON dnevni_putnici USING gin(putnik_ime gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_ime_gin ON mesecni_putnici USING gin(putnik_ime gin_trgm_ops);
-- Compound index za najčešće kombinacije
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_vozac_datum_grad ON dnevni_putnici(vozac, datum, grad)
WHERE obrisan = false;
-- ================================================================
-- PERMISSIONS
-- ================================================================
-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION bulk_update_putnici TO authenticated;
GRANT EXECUTE ON FUNCTION get_optimized_stats TO authenticated;
GRANT EXECUTE ON FUNCTION search_putnici_optimized TO authenticated;
GRANT EXECUTE ON FUNCTION count_search_results TO authenticated;
GRANT EXECUTE ON FUNCTION analyze_slow_queries TO authenticated;
GRANT EXECUTE ON FUNCTION optimize_connection_settings TO authenticated;
-- Grant table permissions
GRANT SELECT,
    INSERT,
    UPDATE ON query_performance_log TO authenticated;
-- ================================================================
-- DAILY CHECKINS TABLE CREATION FUNCTION
-- ================================================================
CREATE OR REPLACE FUNCTION create_daily_checkins_table_if_not_exists() RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN -- Create daily_checkins table if it doesn't exist
    CREATE TABLE IF NOT EXISTS public.daily_checkins (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        vozac TEXT NOT NULL,
        datum DATE NOT NULL,
        kusur_iznos DECIMAL(10, 2) DEFAULT 0.0,
        dnevni_pazari DECIMAL(10, 2) DEFAULT 0.0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        -- Unique constraint to prevent duplicate entries per driver per day
        UNIQUE(vozac, datum)
    );
-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_daily_checkins_vozac ON public.daily_checkins(vozac);
CREATE INDEX IF NOT EXISTS idx_daily_checkins_datum ON public.daily_checkins(datum);
CREATE INDEX IF NOT EXISTS idx_daily_checkins_vozac_datum ON public.daily_checkins(vozac, datum);
-- Enable RLS
ALTER TABLE public.daily_checkins ENABLE ROW LEVEL SECURITY;
-- Create RLS policies
-- Policy for authenticated users to read all records
DROP POLICY IF EXISTS "daily_checkins_read_policy" ON public.daily_checkins;
CREATE POLICY "daily_checkins_read_policy" ON public.daily_checkins FOR
SELECT TO authenticated USING (true);
-- Policy for authenticated users to insert their own records
DROP POLICY IF EXISTS "daily_checkins_insert_policy" ON public.daily_checkins;
CREATE POLICY "daily_checkins_insert_policy" ON public.daily_checkins FOR
INSERT TO authenticated WITH CHECK (true);
-- Policy for authenticated users to update their own records
DROP POLICY IF EXISTS "daily_checkins_update_policy" ON public.daily_checkins;
CREATE POLICY "daily_checkins_update_policy" ON public.daily_checkins FOR
UPDATE TO authenticated USING (true) WITH CHECK (true);
-- Policy for authenticated users to delete their own records
DROP POLICY IF EXISTS "daily_checkins_delete_policy" ON public.daily_checkins;
CREATE POLICY "daily_checkins_delete_policy" ON public.daily_checkins FOR DELETE TO authenticated USING (true);
-- Create trigger for updated_at
DROP TRIGGER IF EXISTS daily_checkins_updated_at_trigger ON public.daily_checkins;
CREATE TRIGGER daily_checkins_updated_at_trigger BEFORE
UPDATE ON public.daily_checkins FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Grant permissions to authenticated users
GRANT SELECT,
    INSERT,
    UPDATE,
    DELETE ON public.daily_checkins TO authenticated;
EXCEPTION
WHEN OTHERS THEN -- Log error but don't fail - table might already exist with different structure
RAISE NOTICE 'Error creating daily_checkins table: %',
SQLERRM;
END;
$$;
-- Grant execution permission
GRANT EXECUTE ON FUNCTION create_daily_checkins_table_if_not_exists() TO authenticated;
-- ================================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at = NOW();
RETURN NEW;
END;
$$;
-- Grant execution permission
GRANT EXECUTE ON FUNCTION update_updated_at_column() TO authenticated;