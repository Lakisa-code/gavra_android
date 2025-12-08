

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."calculate_daily_checkins_ukupno"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Auto-calculate ukupno kada se menjaju sitan_novac ili dnevni_pazari
    NEW.ukupno := COALESCE(NEW.sitan_novac, 0) + COALESCE(NEW.dnevni_pazari, 0);
    
    -- Update timestamp
    NEW.updated_at := NOW();
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_daily_checkins_ukupno"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_daily_pazar"("p_vozac_ime" "text", "p_datum" "date") RETURNS TABLE("ukupno_putovanja_istorija_cena" numeric, "ukupno_dnevni_putnici_cena" numeric, "ukupni_pazar" numeric, "broj_putovanja_istorija" integer, "broj_dnevni_putnici" integer, "ukupno_putovanja" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_vozac_id UUID;
BEGIN
  SELECT id INTO v_vozac_id
  FROM vozaci
  WHERE ime = p_vozac_ime
    AND aktivan = true
    AND obrisan = false;

  IF v_vozac_id IS NULL THEN
    RETURN QUERY SELECT 
      0.0::DECIMAL, 0.0::DECIMAL, 0.0::DECIMAL, 
      0::INTEGER, 0::INTEGER, 0::INTEGER;
    RETURN;
  END IF;

  RETURN QUERY
  WITH putovanja_stats AS (
    SELECT 
      COALESCE(SUM(cena), 0.0) as putovanja_cena,
      COUNT(*)::INTEGER as putovanja_count
    FROM putovanja_istorija
    WHERE vozac_id = v_vozac_id
      AND datum_putovanja = p_datum
      AND obrisan = false
      AND status = 'obavljeno'
  ),
  dnevni_stats AS (
    SELECT 
      COALESCE(SUM(cena), 0.0) as dnevni_cena,
      COUNT(*)::INTEGER as dnevni_count
    FROM dnevni_putnici
    WHERE vozac_id = v_vozac_id
      AND datum_putovanja = p_datum
      AND obrisan = false
      AND status IN ('pokupljen', 'završen', 'naplačen')
  )
  SELECT 
    p.putovanja_cena::DECIMAL,
    d.dnevni_cena::DECIMAL,
    (p.putovanja_cena + d.dnevni_cena)::DECIMAL,
    p.putovanja_count,
    d.dnevni_count,
    (p.putovanja_count + d.dnevni_count)::INTEGER
  FROM putovanja_stats p
  CROSS JOIN dnevni_stats d;
END;
$$;


ALTER FUNCTION "public"."calculate_daily_pazar"("p_vozac_ime" "text", "p_datum" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."contains_day"("radni_dani_str" "text", "day_abbr" "text") RETURNS boolean
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
  -- Check if day_abbr exists in comma-separated list
  -- Handles null values and trims whitespace
  IF radni_dani_str IS NULL OR day_abbr IS NULL THEN
    RETURN FALSE;
  END IF;
  
  RETURN day_abbr = ANY(
    SELECT trim(unnest(string_to_array(radni_dani_str, ',')))
  );
END;
$$;


ALTER FUNCTION "public"."contains_day"("radni_dani_str" "text", "day_abbr" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."contains_day"("radni_dani_str" "text", "day_abbr" "text") IS 'Check if a day abbreviation exists in comma-separated radni_dani string';



CREATE OR REPLACE FUNCTION "public"."get_kusur_transactions"("p_vozac_ime" "text", "p_days" integer DEFAULT 30) RETURNS TABLE("datum" "date", "sitan_novac" numeric, "dnevni_pazari" numeric, "kusur" numeric, "status" "text", "checkin_vreme" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dc.datum,
    COALESCE(dc.sitan_novac, 0.0)::DECIMAL,
    COALESCE(dc.dnevni_pazari, 0.0)::DECIMAL,
    (COALESCE(dc.sitan_novac, 0.0) - COALESCE(dc.dnevni_pazari, 0.0))::DECIMAL,
    dc.status::TEXT,
    dc.checkin_vreme
  FROM daily_checkins dc
  WHERE dc.vozac = p_vozac_ime
    AND dc.obrisan = false
    AND dc.datum >= CURRENT_DATE - (p_days || ' days')::INTERVAL
  ORDER BY dc.datum DESC, dc.checkin_vreme DESC;
END;
$$;


ALTER FUNCTION "public"."get_kusur_transactions"("p_vozac_ime" "text", "p_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_mesecni_putnici_for_day"("target_day" "text") RETURNS TABLE("id" "uuid", "putnik_ime" "text", "tip" "text", "tip_skole" "text", "radni_dani" "text", "polasci_po_danu" "jsonb", "status" "text", "aktivan" boolean, "obrisan" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "datum_pocetka_meseca" "date", "datum_kraja_meseca" "date", "ukupna_cena_meseca" numeric, "broj_telefona" "text", "broj_telefona_oca" "text", "broj_telefona_majke" "text", "adresa_bela_crkva_id" "uuid", "adresa_vrsac_id" "uuid", "cena" numeric, "broj_putovanja" integer, "broj_otkazivanja" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mp.id,
    mp.putnik_ime,
    mp.tip,
    mp.tip_skole,
    mp.radni_dani,
    mp.polasci_po_danu,
    mp.status,
    mp.aktivan,
    mp.obrisan,
    mp.created_at,
    mp.updated_at,
    mp.datum_pocetka_meseca,
    mp.datum_kraja_meseca,
    mp.ukupna_cena_meseca,
    mp.broj_telefona,
    mp.broj_telefona_oca,
    mp.broj_telefona_majke,
    mp.adresa_bela_crkva_id,
    mp.adresa_vrsac_id,
    mp.cena,
    mp.broj_putovanja,
    mp.broj_otkazivanja
  FROM mesecni_putnici mp
  WHERE mp.aktivan = true 
    AND mp.obrisan = false
    AND target_day = ANY(string_to_array(mp.radni_dani, ','))
  ORDER BY mp.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_mesecni_putnici_for_day"("target_day" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_monthly_stats"("p_vozac_ime" "text", "p_mesec" "date") RETURNS TABLE("broj_mesecnih_karata" integer, "ukupno_putovanja" integer, "ukupna_zarada" numeric, "prosecna_dnevna_zarada" numeric, "broj_radnih_dana" integer, "mesec" "date")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_vozac_id UUID;
  v_first_day DATE;
  v_last_day DATE;
BEGIN
  SELECT id INTO v_vozac_id
  FROM vozaci
  WHERE ime = p_vozac_ime
    AND aktivan = true
    AND obrisan = false;

  IF v_vozac_id IS NULL THEN
    RETURN QUERY SELECT 0, 0, 0.0::DECIMAL, 0.0::DECIMAL, 0, p_mesec;
    RETURN;
  END IF;

  v_first_day := DATE_TRUNC('month', p_mesec);
  v_last_day := DATE_TRUNC('month', p_mesec) + INTERVAL '1 month' - INTERVAL '1 day';

  RETURN QUERY
  WITH mesecni_karte AS (
    SELECT COUNT(DISTINCT id)::INTEGER as count
    FROM mesecni_putnici
    WHERE vozac_id = v_vozac_id
      AND aktivan = true
      AND obrisan = false
      AND datum_pocetka_meseca >= v_first_day
      AND datum_pocetka_meseca <= v_last_day
  ),
  putovanja_total AS (
    SELECT 
      COUNT(*)::INTEGER as count,
      COALESCE(SUM(cena), 0.0) as total_cena
    FROM putovanja_istorija
    WHERE vozac_id = v_vozac_id
      AND obrisan = false
      AND datum_putovanja >= v_first_day
      AND datum_putovanja <= v_last_day
  ),
  dnevni_total AS (
    SELECT 
      COUNT(*)::INTEGER as count,
      COALESCE(SUM(cena), 0.0) as total_cena
    FROM dnevni_putnici
    WHERE vozac_id = v_vozac_id
      AND obrisan = false
      AND datum_putovanja >= v_first_day
      AND datum_putovanja <= v_last_day
  ),
  radni_dani AS (
    SELECT COUNT(DISTINCT datum_putovanja)::INTEGER as count
    FROM (
      SELECT datum_putovanja FROM putovanja_istorija
      WHERE vozac_id = v_vozac_id
        AND datum_putovanja >= v_first_day
        AND datum_putovanja <= v_last_day
        AND obrisan = false
      UNION
      SELECT datum_putovanja FROM dnevni_putnici
      WHERE vozac_id = v_vozac_id
        AND datum_putovanja >= v_first_day
        AND datum_putovanja <= v_last_day
        AND obrisan = false
    ) all_dates
  )
  SELECT 
    mk.count,
    (pt.count + dt.count)::INTEGER,
    (pt.total_cena + dt.total_cena)::DECIMAL,
    CASE 
      WHEN rd.count > 0 THEN ((pt.total_cena + dt.total_cena) / rd.count)::DECIMAL
      ELSE 0.0::DECIMAL
    END,
    rd.count,
    v_first_day
  FROM mesecni_karte mk
  CROSS JOIN putovanja_total pt
  CROSS JOIN dnevni_total dt
  CROSS JOIN radni_dani rd;
END;
$$;


ALTER FUNCTION "public"."get_monthly_stats"("p_vozac_ime" "text", "p_mesec" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_vozac_kusur"("p_vozac_ime" "text") RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_kusur DECIMAL;
BEGIN
  SELECT COALESCE(kusur, 0.0)
  INTO v_kusur
  FROM vozaci
  WHERE ime = p_vozac_ime
    AND aktivan = true
    AND obrisan = false;
  
  RETURN COALESCE(v_kusur, 0.0);
END;
$$;


ALTER FUNCTION "public"."get_vozac_kusur"("p_vozac_ime" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."soft_delete_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Automatski postavlja deleted_at kada se obrisan = true
    IF NEW.obrisan = true AND OLD.obrisan = false THEN
        NEW.deleted_at := NOW();
    ELSIF NEW.obrisan = false THEN
        NEW.deleted_at := NULL;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."soft_delete_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_update_vozac_kusur"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_vozac_ime TEXT;
  v_calculated_kusur DECIMAL;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_vozac_ime := OLD.vozac;
  ELSE
    v_vozac_ime := NEW.vozac;
  END IF;

  SELECT COALESCE(SUM(sitan_novac - dnevni_pazari), 0.0)
  INTO v_calculated_kusur
  FROM daily_checkins
  WHERE vozac = v_vozac_ime
    AND obrisan = false
    AND datum >= CURRENT_DATE - INTERVAL '30 days';

  UPDATE vozaci
  SET 
    kusur = v_calculated_kusur,
    updated_at = NOW()
  WHERE ime = v_vozac_ime
    AND aktivan = true;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;


ALTER FUNCTION "public"."trigger_update_vozac_kusur"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_kapacitet_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_kapacitet_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_kusur_batch"("p_updates" "jsonb") RETURNS TABLE("vozac_ime" "text", "old_kusur" numeric, "new_kusur" numeric, "success" boolean, "error_message" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_update JSONB;
  v_vozac_ime TEXT;
  v_new_kusur DECIMAL;
  v_old_kusur DECIMAL;
  v_rows_affected INTEGER;
BEGIN
  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    BEGIN
      v_vozac_ime := v_update->>'vozac_ime';
      v_new_kusur := (v_update->>'new_kusur')::DECIMAL;

      SELECT kusur INTO v_old_kusur
      FROM vozaci
      WHERE ime = v_vozac_ime
        AND aktivan = true
        AND obrisan = false;

      UPDATE vozaci
      SET 
        kusur = v_new_kusur,
        updated_at = NOW()
      WHERE ime = v_vozac_ime
        AND aktivan = true
        AND obrisan = false;

      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

      IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 
          v_vozac_ime, 
          COALESCE(v_old_kusur, 0.0), 
          v_new_kusur, 
          true, 
          NULL::TEXT;
      ELSE
        RETURN QUERY SELECT 
          v_vozac_ime, 
          COALESCE(v_old_kusur, 0.0), 
          v_new_kusur, 
          false, 
          'Vozac not found or inactive'::TEXT;
      END IF;

    EXCEPTION WHEN OTHERS THEN
      RETURN QUERY SELECT 
        v_vozac_ime, 
        COALESCE(v_old_kusur, 0.0), 
        v_new_kusur, 
        false, 
        SQLERRM::TEXT;
    END;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."update_kusur_batch"("p_updates" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_vozac_kusur"("vozac_ime" "text", "novi_kusur" numeric) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Update kusur for the specified vozac
  UPDATE vozaci 
  SET 
    kusur = novi_kusur, 
    updated_at = NOW() 
  WHERE ime = vozac_ime;
  
  -- Check if update was successful
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vozač sa imenom % nije pronađen', vozac_ime;
  END IF;
END;
$$;


ALTER FUNCTION "public"."update_vozac_kusur"("vozac_ime" "text", "novi_kusur" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_vozac_kusur"("vozac_ime" "text", "novi_kusur" numeric) IS 'Updates kusur value for a specific vozac by name';



CREATE OR REPLACE FUNCTION "public"."update_vozac_lokacije_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_vozac_lokacije_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_zakazane_voznje_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_zakazane_voznje_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."mesecni_putnici" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "putnik_ime" character varying NOT NULL,
    "tip" character varying NOT NULL,
    "tip_skole" character varying,
    "broj_telefona" character varying,
    "broj_telefona_oca" character varying,
    "broj_telefona_majke" character varying,
    "polasci_po_danu" "jsonb" NOT NULL,
    "tip_prikazivanja" character varying DEFAULT 'standard'::character varying,
    "radni_dani" character varying,
    "aktivan" boolean DEFAULT true,
    "status" character varying DEFAULT 'aktivan'::character varying,
    "datum_pocetka_meseca" "date" NOT NULL,
    "datum_kraja_meseca" "date" NOT NULL,
    "ukupna_cena_meseca" numeric,
    "cena" numeric,
    "broj_putovanja" integer DEFAULT 0,
    "broj_otkazivanja" integer DEFAULT 0,
    "poslednje_putovanje" timestamp with time zone,
    "vreme_placanja" timestamp with time zone,
    "placeni_mesec" integer,
    "placena_godina" integer,
    "vozac_id" "uuid",
    "pokupljen" boolean DEFAULT false,
    "vreme_pokupljenja" timestamp with time zone,
    "statistics" "jsonb" DEFAULT '{}'::"jsonb",
    "obrisan" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "adresa_bela_crkva_id" "uuid",
    "adresa_vrsac_id" "uuid",
    "napomena" "text",
    "action_log" "jsonb" DEFAULT '[]'::"jsonb",
    "dodali_vozaci" "jsonb" DEFAULT '[]'::"jsonb",
    "placeno" boolean DEFAULT false,
    "datum_placanja" timestamp with time zone,
    "updated_by" "uuid",
    "pin" "text",
    "push_token" "text",
    "push_provider" "text",
    "cena_po_danu" numeric(10,2) DEFAULT NULL::numeric,
    CONSTRAINT "check_mesecni_status_valid" CHECK ((("status")::"text" = ANY ((ARRAY['radi'::character varying, 'bolovanje'::character varying, 'godisnji'::character varying, 'odsustvo'::character varying, 'otkazan'::character varying])::"text"[]))),
    CONSTRAINT "check_tip_values" CHECK ((("tip")::"text" = ANY ((ARRAY['radnik'::character varying, 'ucenik'::character varying])::"text"[])))
);


ALTER TABLE "public"."mesecni_putnici" OWNER TO "postgres";


COMMENT ON TABLE "public"."mesecni_putnici" IS 'Konsolidovane adrese - koristi samo UUID reference na tabelu adrese';



COMMENT ON COLUMN "public"."mesecni_putnici"."tip" IS 'Tip putnika: radnik (700 RSD/dan), ucenik (600 RSD/dan), dnevni (po dogovoru)';



COMMENT ON COLUMN "public"."mesecni_putnici"."cena_po_danu" IS 'Custom cena po danu za putnika. Ako je NULL, koristi se default (700 RSD radnik, 600 RSD učenik). Za kraće relacije može biti npr. 200 RSD.';



CREATE OR REPLACE VIEW "public"."active_mesecni_putnici" AS
 SELECT "mesecni_putnici"."id",
    "mesecni_putnici"."putnik_ime",
    "mesecni_putnici"."tip",
    "mesecni_putnici"."tip_skole",
    "mesecni_putnici"."broj_telefona",
    "mesecni_putnici"."broj_telefona_oca",
    "mesecni_putnici"."broj_telefona_majke",
    "mesecni_putnici"."polasci_po_danu",
    "mesecni_putnici"."tip_prikazivanja",
    "mesecni_putnici"."radni_dani",
    "mesecni_putnici"."aktivan",
    "mesecni_putnici"."status",
    "mesecni_putnici"."datum_pocetka_meseca",
    "mesecni_putnici"."datum_kraja_meseca",
    "mesecni_putnici"."ukupna_cena_meseca",
    "mesecni_putnici"."cena",
    "mesecni_putnici"."broj_putovanja",
    "mesecni_putnici"."broj_otkazivanja",
    "mesecni_putnici"."poslednje_putovanje",
    "mesecni_putnici"."vreme_placanja",
    "mesecni_putnici"."placeni_mesec",
    "mesecni_putnici"."placena_godina",
    "mesecni_putnici"."vozac_id",
    "mesecni_putnici"."pokupljen",
    "mesecni_putnici"."vreme_pokupljenja",
    "mesecni_putnici"."statistics",
    "mesecni_putnici"."obrisan",
    "mesecni_putnici"."created_at",
    "mesecni_putnici"."updated_at",
    "mesecni_putnici"."adresa_bela_crkva_id",
    "mesecni_putnici"."adresa_vrsac_id"
   FROM "public"."mesecni_putnici"
  WHERE ("mesecni_putnici"."obrisan" = false);


ALTER TABLE "public"."active_mesecni_putnici" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vozaci" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ime" character varying NOT NULL,
    "email" character varying,
    "telefon" character varying,
    "aktivan" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "kusur" numeric DEFAULT 0.0,
    "obrisan" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "status" character varying(50) DEFAULT 'aktivan'::character varying,
    "sifra" character varying,
    CONSTRAINT "check_vozaci_status_valid" CHECK ((("status")::"text" = ANY ((ARRAY['aktivan'::character varying, 'neaktivan'::character varying, 'pauziran'::character varying, 'blokiran'::character varying])::"text"[]))),
    CONSTRAINT "vozaci_kusur_check" CHECK (("kusur" >= (0)::numeric))
);


ALTER TABLE "public"."vozaci" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."active_vozaci" AS
 SELECT "vozaci"."id",
    "vozaci"."ime",
    "vozaci"."email",
    "vozaci"."telefon",
    "vozaci"."aktivan",
    "vozaci"."created_at",
    "vozaci"."updated_at",
    "vozaci"."kusur",
    "vozaci"."obrisan",
    "vozaci"."deleted_at",
    "vozaci"."status"
   FROM "public"."vozaci"
  WHERE (("vozaci"."obrisan" = false) AND (("vozaci"."status")::"text" = 'aktivan'::"text"));


ALTER TABLE "public"."active_vozaci" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vozila" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "registarski_broj" character varying NOT NULL,
    "marka" character varying,
    "model" character varying,
    "godina_proizvodnje" integer,
    "broj_mesta" integer,
    "aktivan" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "obrisan" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "status" character varying(50) DEFAULT 'aktivan'::character varying,
    CONSTRAINT "check_vozila_status_valid" CHECK ((("status")::"text" = ANY ((ARRAY['aktivan'::character varying, 'neaktivan'::character varying, 'u_servisu'::character varying, 'otpisan'::character varying])::"text"[])))
);


ALTER TABLE "public"."vozila" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."active_vozila" AS
 SELECT "vozila"."id",
    "vozila"."registarski_broj",
    "vozila"."marka",
    "vozila"."model",
    "vozila"."godina_proizvodnje",
    "vozila"."broj_mesta",
    "vozila"."aktivan",
    "vozila"."created_at",
    "vozila"."updated_at",
    "vozila"."obrisan",
    "vozila"."deleted_at",
    "vozila"."status"
   FROM "public"."vozila"
  WHERE (("vozila"."obrisan" = false) AND (("vozila"."status")::"text" = 'aktivan'::"text"));


ALTER TABLE "public"."active_vozila" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."adrese" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "naziv" character varying NOT NULL,
    "grad" character varying,
    "ulica" character varying,
    "broj" character varying,
    "koordinate" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."adrese" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_checkins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac" "text" NOT NULL,
    "datum" "date" NOT NULL,
    "sitan_novac" numeric(10,2) DEFAULT 0.0,
    "dnevni_pazari" numeric(10,2) DEFAULT 0.0,
    "ukupno" numeric(10,2) DEFAULT 0.0,
    "checkin_vreme" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "obrisan" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "status" character varying(50) DEFAULT 'otvoren'::character varying,
    CONSTRAINT "check_checkins_status_valid" CHECK ((("status")::"text" = ANY ((ARRAY['otvoren'::character varying, 'završen'::character varying, 'revidiran'::character varying, 'zaključan'::character varying])::"text"[]))),
    CONSTRAINT "check_ukupno_calculation" CHECK (("ukupno" = (COALESCE("sitan_novac", (0)::numeric) + COALESCE("dnevni_pazari", (0)::numeric))))
);


ALTER TABLE "public"."daily_checkins" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."daily_checkins_summary" AS
 SELECT "daily_checkins"."id",
    "daily_checkins"."vozac",
    "daily_checkins"."datum",
    "daily_checkins"."sitan_novac",
    "daily_checkins"."dnevni_pazari",
    "daily_checkins"."ukupno",
    "daily_checkins"."checkin_vreme",
    "daily_checkins"."status",
        CASE
            WHEN (("daily_checkins"."status")::"text" = 'završen'::"text") THEN 'Completed'::"text"
            WHEN (("daily_checkins"."status")::"text" = 'otvoren'::"text") THEN 'In Progress'::"text"
            ELSE 'Other'::"text"
        END AS "status_display",
    "daily_checkins"."created_at",
    "daily_checkins"."updated_at"
   FROM "public"."daily_checkins"
  WHERE ("daily_checkins"."obrisan" = false);


ALTER TABLE "public"."daily_checkins_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."gps_lokacije" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac_id" "uuid",
    "vozilo_id" "uuid",
    "latitude" numeric NOT NULL,
    "longitude" numeric NOT NULL,
    "brzina" numeric,
    "pravac" numeric,
    "tacnost" numeric,
    "vreme" timestamp with time zone DEFAULT "now"(),
    "obrisan" boolean DEFAULT false,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."gps_lokacije" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."gps_lokacije_partitioned" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac_id" "uuid",
    "vozilo_id" "uuid",
    "latitude" numeric NOT NULL,
    "longitude" numeric NOT NULL,
    "brzina" numeric,
    "pravac" numeric,
    "tacnost" numeric,
    "vreme" timestamp with time zone NOT NULL
)
PARTITION BY RANGE ("vreme");


ALTER TABLE "public"."gps_lokacije_partitioned" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."gps_lokacije_2025_10" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac_id" "uuid",
    "vozilo_id" "uuid",
    "latitude" numeric NOT NULL,
    "longitude" numeric NOT NULL,
    "brzina" numeric,
    "pravac" numeric,
    "tacnost" numeric,
    "vreme" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."gps_lokacije_2025_10" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."gps_lokacije_2025_11" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac_id" "uuid",
    "vozilo_id" "uuid",
    "latitude" numeric NOT NULL,
    "longitude" numeric NOT NULL,
    "brzina" numeric,
    "pravac" numeric,
    "tacnost" numeric,
    "vreme" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."gps_lokacije_2025_11" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."gps_lokacije_2025_12" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac_id" "uuid",
    "vozilo_id" "uuid",
    "latitude" numeric NOT NULL,
    "longitude" numeric NOT NULL,
    "brzina" numeric,
    "pravac" numeric,
    "tacnost" numeric,
    "vreme" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."gps_lokacije_2025_12" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."gps_lokacije_view" AS
 SELECT "gps_lokacije_partitioned"."id",
    "gps_lokacije_partitioned"."vozac_id",
    "gps_lokacije_partitioned"."vozilo_id",
    "gps_lokacije_partitioned"."latitude",
    "gps_lokacije_partitioned"."longitude",
    "gps_lokacije_partitioned"."brzina",
    "gps_lokacije_partitioned"."pravac",
    "gps_lokacije_partitioned"."tacnost",
    "gps_lokacije_partitioned"."vreme"
   FROM "public"."gps_lokacije_partitioned";


ALTER TABLE "public"."gps_lokacije_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kapacitet_polazaka" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "grad" "text" NOT NULL,
    "vreme" "text" NOT NULL,
    "max_mesta" integer DEFAULT 8,
    "aktivan" boolean DEFAULT true,
    "napomena" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."kapacitet_polazaka" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."promene_vremena_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "putnik_id" "text" NOT NULL,
    "datum" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."promene_vremena_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."putovanja_istorija" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "mesecni_putnik_id" "uuid",
    "datum_putovanja" "date" NOT NULL,
    "vreme_polaska" character varying,
    "status" character varying DEFAULT 'obavljeno'::character varying,
    "vozac_id" "uuid",
    "napomene" "text",
    "obrisan" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "adresa_id" "uuid",
    "cena" numeric DEFAULT 0.0,
    "tip_putnika" character varying DEFAULT 'dnevni'::character varying,
    "putnik_ime" character varying,
    "created_by" "uuid",
    "action_log" "jsonb" DEFAULT '{}'::"jsonb",
    "grad" character varying(100),
    "broj_telefona" character varying(20),
    CONSTRAINT "check_action_log_schema_putovanja" CHECK ((("action_log" ? 'actions'::"text") AND ("jsonb_typeof"(("action_log" -> 'actions'::"text")) = 'array'::"text")))
);


ALTER TABLE "public"."putovanja_istorija" OWNER TO "postgres";


COMMENT ON COLUMN "public"."putovanja_istorija"."created_by" IS 'UUID vozača koji je kreirao putovanje';



COMMENT ON COLUMN "public"."putovanja_istorija"."action_log" IS 'JSONB log svih akcija za putovanje';



CREATE TABLE IF NOT EXISTS "public"."vozac_lokacije" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac_id" "text" NOT NULL,
    "vozac_ime" "text",
    "lat" double precision NOT NULL,
    "lng" double precision NOT NULL,
    "grad" "text" DEFAULT 'Bela Crkva'::"text" NOT NULL,
    "vreme_polaska" "text",
    "aktivan" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "smer" "text",
    "putnici_eta" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."vozac_lokacije" OWNER TO "postgres";


COMMENT ON TABLE "public"."vozac_lokacije" IS 'Real-time GPS lokacije vozača za praćenje od strane mesečnih putnika';



COMMENT ON COLUMN "public"."vozac_lokacije"."putnici_eta" IS 'ETA u minutama za svakog putnika u ruti. Format: {"Ime Putnika": 3, "Drugi Putnik": 8}';



CREATE TABLE IF NOT EXISTS "public"."zahtevi_pristupa" (
    "id" integer NOT NULL,
    "ime" "text" NOT NULL,
    "email" "text" DEFAULT ''::"text" NOT NULL,
    "telefon" "text",
    "poruka" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "processed_at" timestamp with time zone,
    "processed_by" "text",
    "prezime" "text",
    "adresa" "text",
    "grad" "text",
    "tip_putnika" "text",
    "podtip" "text"
);


ALTER TABLE "public"."zahtevi_pristupa" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."zahtevi_pristupa_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."zahtevi_pristupa_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."zahtevi_pristupa_id_seq" OWNED BY "public"."zahtevi_pristupa"."id";



CREATE TABLE IF NOT EXISTS "public"."zakazane_voznje" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "putnik_id" "uuid" NOT NULL,
    "datum" "date" NOT NULL,
    "smena" "text",
    "vreme_bc" "text",
    "vreme_vs" "text",
    "status" "text" DEFAULT 'zakazano'::"text",
    "napomena" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "zakazane_voznje_smena_check" CHECK (("smena" = ANY (ARRAY['prva'::"text", 'druga'::"text", 'treca'::"text", 'slobodan'::"text", 'custom'::"text"]))),
    CONSTRAINT "zakazane_voznje_status_check" CHECK (("status" = ANY (ARRAY['zakazano'::"text", 'otkazano'::"text", 'zavrseno'::"text"])))
);


ALTER TABLE "public"."zakazane_voznje" OWNER TO "postgres";


COMMENT ON TABLE "public"."zakazane_voznje" IS 'Nedeljno zakazivanje vožnji od strane mesečnih putnika - Self Booking';



COMMENT ON COLUMN "public"."zakazane_voznje"."smena" IS 'Tip smene: prva (jutarnja), druga (popodnevna), treca (nocna), slobodan, custom';



COMMENT ON COLUMN "public"."zakazane_voznje"."vreme_bc" IS 'Vreme polaska iz Bele Crkve';



COMMENT ON COLUMN "public"."zakazane_voznje"."vreme_vs" IS 'Vreme polaska iz Vršca';



CREATE OR REPLACE VIEW "public"."zakazane_voznje_pregled" AS
 SELECT "zv"."id",
    "zv"."datum",
    "zv"."smena",
    "zv"."vreme_bc",
    "zv"."vreme_vs",
    "zv"."status",
    "zv"."napomena",
    "mp"."putnik_ime",
    "mp"."tip",
    "mp"."broj_telefona",
    "zv"."created_at",
    "zv"."updated_at"
   FROM ("public"."zakazane_voznje" "zv"
     JOIN "public"."mesecni_putnici" "mp" ON (("mp"."id" = "zv"."putnik_id")))
  WHERE ("zv"."status" = 'zakazano'::"text")
  ORDER BY "zv"."datum", "zv"."vreme_bc";


ALTER TABLE "public"."zakazane_voznje_pregled" OWNER TO "postgres";


COMMENT ON VIEW "public"."zakazane_voznje_pregled" IS 'Pregled zakazanih vožnji sa podacima o putniku';



ALTER TABLE ONLY "public"."gps_lokacije_partitioned" ATTACH PARTITION "public"."gps_lokacije_2025_10" FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');



ALTER TABLE ONLY "public"."gps_lokacije_partitioned" ATTACH PARTITION "public"."gps_lokacije_2025_11" FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');



ALTER TABLE ONLY "public"."gps_lokacije_partitioned" ATTACH PARTITION "public"."gps_lokacije_2025_12" FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');



ALTER TABLE ONLY "public"."zahtevi_pristupa" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."zahtevi_pristupa_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."adrese"
    ADD CONSTRAINT "adrese_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_vozac_datum_key" UNIQUE ("vozac", "datum");



ALTER TABLE ONLY "public"."gps_lokacije_partitioned"
    ADD CONSTRAINT "gps_lokacije_partitioned_pkey" PRIMARY KEY ("id", "vreme");



ALTER TABLE ONLY "public"."gps_lokacije_2025_10"
    ADD CONSTRAINT "gps_lokacije_2025_10_pkey" PRIMARY KEY ("id", "vreme");



ALTER TABLE ONLY "public"."gps_lokacije_2025_11"
    ADD CONSTRAINT "gps_lokacije_2025_11_pkey" PRIMARY KEY ("id", "vreme");



ALTER TABLE ONLY "public"."gps_lokacije_2025_12"
    ADD CONSTRAINT "gps_lokacije_2025_12_pkey" PRIMARY KEY ("id", "vreme");



ALTER TABLE ONLY "public"."gps_lokacije"
    ADD CONSTRAINT "gps_lokacije_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kapacitet_polazaka"
    ADD CONSTRAINT "kapacitet_polazaka_grad_vreme_key" UNIQUE ("grad", "vreme");



ALTER TABLE ONLY "public"."kapacitet_polazaka"
    ADD CONSTRAINT "kapacitet_polazaka_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."promene_vremena_log"
    ADD CONSTRAINT "promene_vremena_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."promene_vremena_log"
    ADD CONSTRAINT "promene_vremena_log_putnik_id_datum_key" UNIQUE ("putnik_id", "datum");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vozac_lokacije"
    ADD CONSTRAINT "vozac_lokacije_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vozaci"
    ADD CONSTRAINT "vozaci_ime_key" UNIQUE ("ime");



ALTER TABLE ONLY "public"."vozaci"
    ADD CONSTRAINT "vozaci_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vozila"
    ADD CONSTRAINT "vozila_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vozila"
    ADD CONSTRAINT "vozila_registarski_broj_key" UNIQUE ("registarski_broj");



ALTER TABLE ONLY "public"."zahtevi_pristupa"
    ADD CONSTRAINT "zahtevi_pristupa_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."zakazane_voznje"
    ADD CONSTRAINT "zakazane_voznje_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."zakazane_voznje"
    ADD CONSTRAINT "zakazane_voznje_putnik_id_datum_key" UNIQUE ("putnik_id", "datum");



CREATE INDEX "idx_gps_part_location" ON ONLY "public"."gps_lokacije_partitioned" USING "btree" ("latitude", "longitude");



CREATE INDEX "gps_lokacije_2025_10_latitude_longitude_idx" ON "public"."gps_lokacije_2025_10" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_gps_part_vozac" ON ONLY "public"."gps_lokacije_partitioned" USING "btree" ("vozac_id");



CREATE INDEX "gps_lokacije_2025_10_vozac_id_idx" ON "public"."gps_lokacije_2025_10" USING "btree" ("vozac_id");



CREATE INDEX "idx_gps_part_vozac_vreme" ON ONLY "public"."gps_lokacije_partitioned" USING "btree" ("vozac_id", "vreme" DESC);



CREATE INDEX "gps_lokacije_2025_10_vozac_id_vreme_idx" ON "public"."gps_lokacije_2025_10" USING "btree" ("vozac_id", "vreme" DESC);



CREATE INDEX "idx_gps_part_vreme" ON ONLY "public"."gps_lokacije_partitioned" USING "btree" ("vreme" DESC);



CREATE INDEX "gps_lokacije_2025_10_vreme_idx" ON "public"."gps_lokacije_2025_10" USING "btree" ("vreme" DESC);



CREATE INDEX "gps_lokacije_2025_11_latitude_longitude_idx" ON "public"."gps_lokacije_2025_11" USING "btree" ("latitude", "longitude");



CREATE INDEX "gps_lokacije_2025_11_vozac_id_idx" ON "public"."gps_lokacije_2025_11" USING "btree" ("vozac_id");



CREATE INDEX "gps_lokacije_2025_11_vozac_id_vreme_idx" ON "public"."gps_lokacije_2025_11" USING "btree" ("vozac_id", "vreme" DESC);



CREATE INDEX "gps_lokacije_2025_11_vreme_idx" ON "public"."gps_lokacije_2025_11" USING "btree" ("vreme" DESC);



CREATE INDEX "gps_lokacije_2025_12_latitude_longitude_idx" ON "public"."gps_lokacije_2025_12" USING "btree" ("latitude", "longitude");



CREATE INDEX "gps_lokacije_2025_12_vozac_id_idx" ON "public"."gps_lokacije_2025_12" USING "btree" ("vozac_id");



CREATE INDEX "gps_lokacije_2025_12_vozac_id_vreme_idx" ON "public"."gps_lokacije_2025_12" USING "btree" ("vozac_id", "vreme" DESC);



CREATE INDEX "gps_lokacije_2025_12_vreme_idx" ON "public"."gps_lokacije_2025_12" USING "btree" ("vreme" DESC);



CREATE INDEX "idx_adrese_grad_naziv" ON "public"."adrese" USING "btree" ("grad", "naziv");



CREATE INDEX "idx_adrese_koordinate" ON "public"."adrese" USING "gin" ("koordinate");



CREATE INDEX "idx_daily_checkins_datum" ON "public"."daily_checkins" USING "btree" ("datum");



CREATE INDEX "idx_daily_checkins_vozac" ON "public"."daily_checkins" USING "btree" ("vozac");



CREATE INDEX "idx_gps_lokacije_location" ON "public"."gps_lokacije" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_gps_lokacije_vozac_id" ON "public"."gps_lokacije" USING "btree" ("vozac_id");



CREATE INDEX "idx_gps_lokacije_vozac_vreme" ON "public"."gps_lokacije" USING "btree" ("vozac_id", "vreme" DESC);



CREATE INDEX "idx_gps_lokacije_vreme" ON "public"."gps_lokacije" USING "btree" ("vreme" DESC);



CREATE INDEX "idx_mesecni_putnici_active_status" ON "public"."mesecni_putnici" USING "btree" ("status", "aktivan") WHERE ("obrisan" = false);



CREATE INDEX "idx_mesecni_putnici_adresa_bela_crkva_id" ON "public"."mesecni_putnici" USING "btree" ("adresa_bela_crkva_id");



CREATE INDEX "idx_mesecni_putnici_adresa_vrsac_id" ON "public"."mesecni_putnici" USING "btree" ("adresa_vrsac_id");



CREATE INDEX "idx_mesecni_putnici_aktivan" ON "public"."mesecni_putnici" USING "btree" ("aktivan");



CREATE INDEX "idx_mesecni_putnici_cena_po_danu" ON "public"."mesecni_putnici" USING "btree" ("cena_po_danu") WHERE ("cena_po_danu" IS NOT NULL);



CREATE INDEX "idx_mesecni_putnici_datum_period" ON "public"."mesecni_putnici" USING "btree" ("datum_pocetka_meseca", "datum_kraja_meseca") WHERE ("aktivan" = true);



CREATE INDEX "idx_mesecni_putnici_obrisan" ON "public"."mesecni_putnici" USING "btree" ("obrisan");



CREATE INDEX "idx_mesecni_putnici_push_token" ON "public"."mesecni_putnici" USING "btree" ("push_token") WHERE ("push_token" IS NOT NULL);



CREATE INDEX "idx_mesecni_putnici_putnik_ime" ON "public"."mesecni_putnici" USING "btree" ("putnik_ime") WHERE ("obrisan" = false);



CREATE INDEX "idx_mesecni_putnici_vozac_id" ON "public"."mesecni_putnici" USING "btree" ("vozac_id");



CREATE INDEX "idx_promene_vremena_putnik_datum" ON "public"."promene_vremena_log" USING "btree" ("putnik_id", "datum");



CREATE INDEX "idx_putovanja_action_log_ops" ON "public"."putovanja_istorija" USING "gin" ("action_log" "jsonb_path_ops");



CREATE INDEX "idx_putovanja_istorija_action_log" ON "public"."putovanja_istorija" USING "gin" ("action_log");



CREATE INDEX "idx_putovanja_istorija_created_by" ON "public"."putovanja_istorija" USING "btree" ("created_by");



CREATE INDEX "idx_vozac_lokacije_aktivan" ON "public"."vozac_lokacije" USING "btree" ("aktivan");



CREATE INDEX "idx_vozac_lokacije_grad" ON "public"."vozac_lokacije" USING "btree" ("grad");



CREATE INDEX "idx_vozac_lokacije_smer" ON "public"."vozac_lokacije" USING "btree" ("smer");



CREATE INDEX "idx_vozac_lokacije_vozac" ON "public"."vozac_lokacije" USING "btree" ("vozac_id");



CREATE INDEX "idx_zakazane_voznje_datum" ON "public"."zakazane_voznje" USING "btree" ("datum");



CREATE INDEX "idx_zakazane_voznje_datum_status" ON "public"."zakazane_voznje" USING "btree" ("datum", "status");



CREATE INDEX "idx_zakazane_voznje_putnik" ON "public"."zakazane_voznje" USING "btree" ("putnik_id");



CREATE INDEX "idx_zakazane_voznje_status" ON "public"."zakazane_voznje" USING "btree" ("status");



ALTER INDEX "public"."idx_gps_part_location" ATTACH PARTITION "public"."gps_lokacije_2025_10_latitude_longitude_idx";



ALTER INDEX "public"."gps_lokacije_partitioned_pkey" ATTACH PARTITION "public"."gps_lokacije_2025_10_pkey";



ALTER INDEX "public"."idx_gps_part_vozac" ATTACH PARTITION "public"."gps_lokacije_2025_10_vozac_id_idx";



ALTER INDEX "public"."idx_gps_part_vozac_vreme" ATTACH PARTITION "public"."gps_lokacije_2025_10_vozac_id_vreme_idx";



ALTER INDEX "public"."idx_gps_part_vreme" ATTACH PARTITION "public"."gps_lokacije_2025_10_vreme_idx";



ALTER INDEX "public"."idx_gps_part_location" ATTACH PARTITION "public"."gps_lokacije_2025_11_latitude_longitude_idx";



ALTER INDEX "public"."gps_lokacije_partitioned_pkey" ATTACH PARTITION "public"."gps_lokacije_2025_11_pkey";



ALTER INDEX "public"."idx_gps_part_vozac" ATTACH PARTITION "public"."gps_lokacije_2025_11_vozac_id_idx";



ALTER INDEX "public"."idx_gps_part_vozac_vreme" ATTACH PARTITION "public"."gps_lokacije_2025_11_vozac_id_vreme_idx";



ALTER INDEX "public"."idx_gps_part_vreme" ATTACH PARTITION "public"."gps_lokacije_2025_11_vreme_idx";



ALTER INDEX "public"."idx_gps_part_location" ATTACH PARTITION "public"."gps_lokacije_2025_12_latitude_longitude_idx";



ALTER INDEX "public"."gps_lokacije_partitioned_pkey" ATTACH PARTITION "public"."gps_lokacije_2025_12_pkey";



ALTER INDEX "public"."idx_gps_part_vozac" ATTACH PARTITION "public"."gps_lokacije_2025_12_vozac_id_idx";



ALTER INDEX "public"."idx_gps_part_vozac_vreme" ATTACH PARTITION "public"."gps_lokacije_2025_12_vozac_id_vreme_idx";



ALTER INDEX "public"."idx_gps_part_vreme" ATTACH PARTITION "public"."gps_lokacije_2025_12_vreme_idx";



CREATE OR REPLACE TRIGGER "kapacitet_updated_at_trigger" BEFORE UPDATE ON "public"."kapacitet_polazaka" FOR EACH ROW EXECUTE FUNCTION "public"."update_kapacitet_updated_at"();



CREATE OR REPLACE TRIGGER "soft_delete_daily_checkins" BEFORE UPDATE OF "obrisan" ON "public"."daily_checkins" FOR EACH ROW EXECUTE FUNCTION "public"."soft_delete_trigger"();



CREATE OR REPLACE TRIGGER "soft_delete_gps_lokacije" BEFORE UPDATE OF "obrisan" ON "public"."gps_lokacije" FOR EACH ROW EXECUTE FUNCTION "public"."soft_delete_trigger"();



CREATE OR REPLACE TRIGGER "soft_delete_vozaci" BEFORE UPDATE OF "obrisan" ON "public"."vozaci" FOR EACH ROW EXECUTE FUNCTION "public"."soft_delete_trigger"();



CREATE OR REPLACE TRIGGER "soft_delete_vozila" BEFORE UPDATE OF "obrisan" ON "public"."vozila" FOR EACH ROW EXECUTE FUNCTION "public"."soft_delete_trigger"();



CREATE OR REPLACE TRIGGER "trigger_auto_update_vozac_kusur" AFTER INSERT OR DELETE OR UPDATE ON "public"."daily_checkins" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_update_vozac_kusur"();



CREATE OR REPLACE TRIGGER "trigger_calculate_ukupno" BEFORE INSERT OR UPDATE OF "sitan_novac", "dnevni_pazari" ON "public"."daily_checkins" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_daily_checkins_ukupno"();



CREATE OR REPLACE TRIGGER "trigger_zakazane_voznje_updated_at" BEFORE UPDATE ON "public"."zakazane_voznje" FOR EACH ROW EXECUTE FUNCTION "public"."update_zakazane_voznje_updated_at"();



CREATE OR REPLACE TRIGGER "vozac_lokacije_updated_at" BEFORE UPDATE ON "public"."vozac_lokacije" FOR EACH ROW EXECUTE FUNCTION "public"."update_vozac_lokacije_updated_at"();



ALTER TABLE ONLY "public"."gps_lokacije"
    ADD CONSTRAINT "gps_lokacije_vozac_id_fkey" FOREIGN KEY ("vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."gps_lokacije"
    ADD CONSTRAINT "gps_lokacije_vozilo_id_fkey" FOREIGN KEY ("vozilo_id") REFERENCES "public"."vozila"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_adresa_bela_crkva_id_fkey" FOREIGN KEY ("adresa_bela_crkva_id") REFERENCES "public"."adrese"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_adresa_vrsac_id_fkey" FOREIGN KEY ("adresa_vrsac_id") REFERENCES "public"."adrese"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_vozac_id_fkey" FOREIGN KEY ("vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_adresa_id_fkey" FOREIGN KEY ("adresa_id") REFERENCES "public"."adrese"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_mesecni_putnik_id_fkey" FOREIGN KEY ("mesecni_putnik_id") REFERENCES "public"."mesecni_putnici"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_vozac_id_fkey" FOREIGN KEY ("vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."zakazane_voznje"
    ADD CONSTRAINT "zakazane_voznje_putnik_id_fkey" FOREIGN KEY ("putnik_id") REFERENCES "public"."mesecni_putnici"("id") ON DELETE CASCADE;



CREATE POLICY "Allow all for authenticated" ON "public"."zakazane_voznje" USING (true) WITH CHECK (true);



CREATE POLICY "Anyone can insert zahtevi" ON "public"."zahtevi_pristupa" FOR INSERT WITH CHECK (true);



CREATE POLICY "Anyone can read zahtevi" ON "public"."zahtevi_pristupa" FOR SELECT USING (true);



CREATE POLICY "Anyone can update zahtevi" ON "public"."zahtevi_pristupa" FOR UPDATE USING (true);



CREATE POLICY "Autentifikovani mogu ažurirati" ON "public"."vozac_lokacije" FOR UPDATE USING (true);



CREATE POLICY "Autentifikovani mogu upisivati" ON "public"."vozac_lokacije" FOR INSERT WITH CHECK (true);



CREATE POLICY "Svi mogu čitati lokacije vozača" ON "public"."vozac_lokacije" FOR SELECT USING (true);



ALTER TABLE "public"."daily_checkins" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "daily_checkins_insert_policy" ON "public"."daily_checkins" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "daily_checkins_read_policy" ON "public"."daily_checkins" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "daily_checkins_update_policy" ON "public"."daily_checkins" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "dev_allow_all_istorija" ON "public"."putovanja_istorija" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "dev_allow_all_mesecni" ON "public"."mesecni_putnici" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "dev_allow_all_vozaci" ON "public"."vozaci" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "kapacitet_all_admin" ON "public"."kapacitet_polazaka" USING (true);



ALTER TABLE "public"."kapacitet_polazaka" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kapacitet_select_all" ON "public"."kapacitet_polazaka" FOR SELECT USING (true);



ALTER TABLE "public"."mesecni_putnici" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "promene_vremena_insert_all" ON "public"."promene_vremena_log" FOR INSERT WITH CHECK (true);



ALTER TABLE "public"."promene_vremena_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "promene_vremena_select_all" ON "public"."promene_vremena_log" FOR SELECT USING (true);



ALTER TABLE "public"."putovanja_istorija" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vozac_lokacije" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vozaci" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."zahtevi_pristupa" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."zakazane_voznje" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."adrese";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."daily_checkins";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."gps_lokacije";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."kapacitet_polazaka";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."mesecni_putnici";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."promene_vremena_log";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."putovanja_istorija";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."vozac_lokacije";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."vozaci";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."vozila";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."zahtevi_pristupa";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."zakazane_voznje";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."calculate_daily_checkins_ukupno"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_daily_checkins_ukupno"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_daily_checkins_ukupno"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_daily_pazar"("p_vozac_ime" "text", "p_datum" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_daily_pazar"("p_vozac_ime" "text", "p_datum" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_daily_pazar"("p_vozac_ime" "text", "p_datum" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."contains_day"("radni_dani_str" "text", "day_abbr" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."contains_day"("radni_dani_str" "text", "day_abbr" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."contains_day"("radni_dani_str" "text", "day_abbr" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_kusur_transactions"("p_vozac_ime" "text", "p_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_kusur_transactions"("p_vozac_ime" "text", "p_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_kusur_transactions"("p_vozac_ime" "text", "p_days" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_mesecni_putnici_for_day"("target_day" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_mesecni_putnici_for_day"("target_day" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_mesecni_putnici_for_day"("target_day" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_monthly_stats"("p_vozac_ime" "text", "p_mesec" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_monthly_stats"("p_vozac_ime" "text", "p_mesec" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_monthly_stats"("p_vozac_ime" "text", "p_mesec" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_vozac_kusur"("p_vozac_ime" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_vozac_kusur"("p_vozac_ime" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_vozac_kusur"("p_vozac_ime" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."soft_delete_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."soft_delete_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."soft_delete_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_update_vozac_kusur"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_update_vozac_kusur"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_update_vozac_kusur"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_kapacitet_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_kapacitet_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_kapacitet_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_kusur_batch"("p_updates" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_kusur_batch"("p_updates" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_kusur_batch"("p_updates" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_vozac_kusur"("vozac_ime" "text", "novi_kusur" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."update_vozac_kusur"("vozac_ime" "text", "novi_kusur" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_vozac_kusur"("vozac_ime" "text", "novi_kusur" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_vozac_lokacije_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_vozac_lokacije_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_vozac_lokacije_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_zakazane_voznje_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_zakazane_voznje_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_zakazane_voznje_updated_at"() TO "service_role";


















GRANT ALL ON TABLE "public"."mesecni_putnici" TO "anon";
GRANT ALL ON TABLE "public"."mesecni_putnici" TO "authenticated";
GRANT ALL ON TABLE "public"."mesecni_putnici" TO "service_role";



GRANT ALL ON TABLE "public"."active_mesecni_putnici" TO "anon";
GRANT ALL ON TABLE "public"."active_mesecni_putnici" TO "authenticated";
GRANT ALL ON TABLE "public"."active_mesecni_putnici" TO "service_role";



GRANT ALL ON TABLE "public"."vozaci" TO "anon";
GRANT ALL ON TABLE "public"."vozaci" TO "authenticated";
GRANT ALL ON TABLE "public"."vozaci" TO "service_role";



GRANT ALL ON TABLE "public"."active_vozaci" TO "anon";
GRANT ALL ON TABLE "public"."active_vozaci" TO "authenticated";
GRANT ALL ON TABLE "public"."active_vozaci" TO "service_role";



GRANT ALL ON TABLE "public"."vozila" TO "anon";
GRANT ALL ON TABLE "public"."vozila" TO "authenticated";
GRANT ALL ON TABLE "public"."vozila" TO "service_role";



GRANT ALL ON TABLE "public"."active_vozila" TO "anon";
GRANT ALL ON TABLE "public"."active_vozila" TO "authenticated";
GRANT ALL ON TABLE "public"."active_vozila" TO "service_role";



GRANT ALL ON TABLE "public"."adrese" TO "anon";
GRANT ALL ON TABLE "public"."adrese" TO "authenticated";
GRANT ALL ON TABLE "public"."adrese" TO "service_role";



GRANT ALL ON TABLE "public"."daily_checkins" TO "anon";
GRANT ALL ON TABLE "public"."daily_checkins" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_checkins" TO "service_role";



GRANT ALL ON TABLE "public"."daily_checkins_summary" TO "anon";
GRANT ALL ON TABLE "public"."daily_checkins_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_checkins_summary" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije_partitioned" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije_partitioned" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije_partitioned" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije_2025_10" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije_2025_10" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije_2025_10" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije_2025_11" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije_2025_11" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije_2025_11" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije_2025_12" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije_2025_12" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije_2025_12" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije_view" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije_view" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije_view" TO "service_role";



GRANT ALL ON TABLE "public"."kapacitet_polazaka" TO "anon";
GRANT ALL ON TABLE "public"."kapacitet_polazaka" TO "authenticated";
GRANT ALL ON TABLE "public"."kapacitet_polazaka" TO "service_role";



GRANT ALL ON TABLE "public"."promene_vremena_log" TO "anon";
GRANT ALL ON TABLE "public"."promene_vremena_log" TO "authenticated";
GRANT ALL ON TABLE "public"."promene_vremena_log" TO "service_role";



GRANT ALL ON TABLE "public"."putovanja_istorija" TO "anon";
GRANT ALL ON TABLE "public"."putovanja_istorija" TO "authenticated";
GRANT ALL ON TABLE "public"."putovanja_istorija" TO "service_role";



GRANT ALL ON TABLE "public"."vozac_lokacije" TO "anon";
GRANT ALL ON TABLE "public"."vozac_lokacije" TO "authenticated";
GRANT ALL ON TABLE "public"."vozac_lokacije" TO "service_role";



GRANT ALL ON TABLE "public"."zahtevi_pristupa" TO "anon";
GRANT ALL ON TABLE "public"."zahtevi_pristupa" TO "authenticated";
GRANT ALL ON TABLE "public"."zahtevi_pristupa" TO "service_role";



GRANT ALL ON SEQUENCE "public"."zahtevi_pristupa_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."zahtevi_pristupa_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."zahtevi_pristupa_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."zakazane_voznje" TO "anon";
GRANT ALL ON TABLE "public"."zakazane_voznje" TO "authenticated";
GRANT ALL ON TABLE "public"."zakazane_voznje" TO "service_role";



GRANT ALL ON TABLE "public"."zakazane_voznje_pregled" TO "anon";
GRANT ALL ON TABLE "public"."zakazane_voznje_pregled" TO "authenticated";
GRANT ALL ON TABLE "public"."zakazane_voznje_pregled" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























