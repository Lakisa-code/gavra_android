

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





SET default_tablespace = '';

SET default_table_access_method = "heap";


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


CREATE TABLE IF NOT EXISTS "public"."dnevni_putnici" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "putnik_ime" character varying NOT NULL,
    "telefon" character varying,
    "grad" character varying NOT NULL,
    "broj_mesta" integer,
    "datum_putovanja" "date" NOT NULL,
    "vreme_polaska" character varying,
    "cena" numeric,
    "status" character varying DEFAULT 'aktivno'::character varying,
    "naplatio_vozac_id" "uuid",
    "pokupio_vozac_id" "uuid",
    "dodao_vozac_id" "uuid",
    "otkazao_vozac_id" "uuid",
    "vozac_id" "uuid",
    "obrisan" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "ruta_id" "uuid",
    "vozilo_id" "uuid",
    "adresa_id" "uuid"
);


ALTER TABLE "public"."dnevni_putnici" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."gps_lokacije" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vozac_id" "uuid",
    "vozilo_id" "uuid",
    "latitude" numeric NOT NULL,
    "longitude" numeric NOT NULL,
    "brzina" numeric,
    "pravac" numeric,
    "tacnost" numeric,
    "vreme" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."gps_lokacije" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mesecni_putnici" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "putnik_ime" character varying NOT NULL,
    "tip" character varying NOT NULL,
    "tip_skole" character varying,
    "broj_telefona" character varying,
    "broj_telefona_oca" character varying,
    "broj_telefona_majke" character varying,
    "polasci_po_danu" "jsonb" NOT NULL,
    "adresa_bela_crkva" "text",
    "adresa_vrsac" "text",
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
    "ruta_id" "uuid",
    "vozilo_id" "uuid",
    "adresa_polaska_id" "uuid",
    "adresa_dolaska_id" "uuid",
    "ime" character varying,
    "prezime" character varying,
    "datum_pocetka" "date",
    "datum_kraja" "date"
);


ALTER TABLE "public"."mesecni_putnici" OWNER TO "postgres";


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
    "ruta_id" "uuid",
    "vozilo_id" "uuid",
    "adresa_id" "uuid"
);


ALTER TABLE "public"."putovanja_istorija" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rute" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "naziv" character varying NOT NULL,
    "opis" "text",
    "aktivan" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."rute" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vozaci" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ime" character varying NOT NULL,
    "email" character varying,
    "telefon" character varying,
    "aktivan" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."vozaci" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vozila" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "registarski_broj" character varying NOT NULL,
    "marka" character varying,
    "model" character varying,
    "godina_proizvodnje" integer,
    "broj_mesta" integer,
    "aktivan" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."vozila" OWNER TO "postgres";


ALTER TABLE ONLY "public"."adrese"
    ADD CONSTRAINT "adrese_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."gps_lokacije"
    ADD CONSTRAINT "gps_lokacije_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rute"
    ADD CONSTRAINT "rute_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vozaci"
    ADD CONSTRAINT "vozaci_ime_key" UNIQUE ("ime");



ALTER TABLE ONLY "public"."vozaci"
    ADD CONSTRAINT "vozaci_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vozila"
    ADD CONSTRAINT "vozila_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vozila"
    ADD CONSTRAINT "vozila_registarski_broj_key" UNIQUE ("registarski_broj");



CREATE INDEX "idx_mesecni_putnici_aktivan" ON "public"."mesecni_putnici" USING "btree" ("aktivan");



CREATE INDEX "idx_mesecni_putnici_obrisan" ON "public"."mesecni_putnici" USING "btree" ("obrisan");



CREATE INDEX "idx_mesecni_putnici_vozac_id" ON "public"."mesecni_putnici" USING "btree" ("vozac_id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_adresa_id_fkey" FOREIGN KEY ("adresa_id") REFERENCES "public"."adrese"("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_dodao_vozac_id_fkey" FOREIGN KEY ("dodao_vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_naplatio_vozac_id_fkey" FOREIGN KEY ("naplatio_vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_otkazao_vozac_id_fkey" FOREIGN KEY ("otkazao_vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_pokupio_vozac_id_fkey" FOREIGN KEY ("pokupio_vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_ruta_id_fkey" FOREIGN KEY ("ruta_id") REFERENCES "public"."rute"("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_vozac_id_fkey" FOREIGN KEY ("vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."dnevni_putnici"
    ADD CONSTRAINT "dnevni_putnici_vozilo_id_fkey" FOREIGN KEY ("vozilo_id") REFERENCES "public"."vozila"("id");



ALTER TABLE ONLY "public"."gps_lokacije"
    ADD CONSTRAINT "gps_lokacije_vozac_id_fkey" FOREIGN KEY ("vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."gps_lokacije"
    ADD CONSTRAINT "gps_lokacije_vozilo_id_fkey" FOREIGN KEY ("vozilo_id") REFERENCES "public"."vozila"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_adresa_dolaska_id_fkey" FOREIGN KEY ("adresa_dolaska_id") REFERENCES "public"."adrese"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_adresa_polaska_id_fkey" FOREIGN KEY ("adresa_polaska_id") REFERENCES "public"."adrese"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_ruta_id_fkey" FOREIGN KEY ("ruta_id") REFERENCES "public"."rute"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_vozac_id_fkey" FOREIGN KEY ("vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."mesecni_putnici"
    ADD CONSTRAINT "mesecni_putnici_vozilo_id_fkey" FOREIGN KEY ("vozilo_id") REFERENCES "public"."vozila"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_adresa_id_fkey" FOREIGN KEY ("adresa_id") REFERENCES "public"."adrese"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_mesecni_putnik_id_fkey" FOREIGN KEY ("mesecni_putnik_id") REFERENCES "public"."mesecni_putnici"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_ruta_id_fkey" FOREIGN KEY ("ruta_id") REFERENCES "public"."rute"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_vozac_id_fkey" FOREIGN KEY ("vozac_id") REFERENCES "public"."vozaci"("id");



ALTER TABLE ONLY "public"."putovanja_istorija"
    ADD CONSTRAINT "putovanja_istorija_vozilo_id_fkey" FOREIGN KEY ("vozilo_id") REFERENCES "public"."vozila"("id");



CREATE POLICY "dev_allow_all_dnevni" ON "public"."dnevni_putnici" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "dev_allow_all_istorija" ON "public"."putovanja_istorija" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "dev_allow_all_mesecni" ON "public"."mesecni_putnici" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "dev_allow_all_vozaci" ON "public"."vozaci" TO "authenticated", "anon" USING (true) WITH CHECK (true);



ALTER TABLE "public"."dnevni_putnici" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mesecni_putnici" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."putovanja_istorija" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vozaci" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."adrese";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."dnevni_putnici";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."mesecni_putnici";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."putovanja_istorija";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."rute";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."vozaci";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."vozila";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";


























































































































































































GRANT ALL ON TABLE "public"."adrese" TO "anon";
GRANT ALL ON TABLE "public"."adrese" TO "authenticated";
GRANT ALL ON TABLE "public"."adrese" TO "service_role";



GRANT ALL ON TABLE "public"."dnevni_putnici" TO "anon";
GRANT ALL ON TABLE "public"."dnevni_putnici" TO "authenticated";
GRANT ALL ON TABLE "public"."dnevni_putnici" TO "service_role";



GRANT ALL ON TABLE "public"."gps_lokacije" TO "anon";
GRANT ALL ON TABLE "public"."gps_lokacije" TO "authenticated";
GRANT ALL ON TABLE "public"."gps_lokacije" TO "service_role";



GRANT ALL ON TABLE "public"."mesecni_putnici" TO "anon";
GRANT ALL ON TABLE "public"."mesecni_putnici" TO "authenticated";
GRANT ALL ON TABLE "public"."mesecni_putnici" TO "service_role";



GRANT ALL ON TABLE "public"."putovanja_istorija" TO "anon";
GRANT ALL ON TABLE "public"."putovanja_istorija" TO "authenticated";
GRANT ALL ON TABLE "public"."putovanja_istorija" TO "service_role";



GRANT ALL ON TABLE "public"."rute" TO "anon";
GRANT ALL ON TABLE "public"."rute" TO "authenticated";
GRANT ALL ON TABLE "public"."rute" TO "service_role";



GRANT ALL ON TABLE "public"."vozaci" TO "anon";
GRANT ALL ON TABLE "public"."vozaci" TO "authenticated";
GRANT ALL ON TABLE "public"."vozaci" TO "service_role";



GRANT ALL ON TABLE "public"."vozila" TO "anon";
GRANT ALL ON TABLE "public"."vozila" TO "authenticated";
GRANT ALL ON TABLE "public"."vozila" TO "service_role";









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






























RESET ALL;
