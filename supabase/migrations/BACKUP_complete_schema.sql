-- ================================================
-- GAVRA ANDROID - DATABASE MIGRATION
-- Complete schema for all tables with new fields
-- Generated: 2025-10-03
-- ================================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS public.putovanje_istorija CASCADE;
DROP TABLE IF EXISTS public.gps_lokacije CASCADE;
DROP TABLE IF EXISTS public.dnevni_putnici CASCADE;
DROP TABLE IF EXISTS public.mesecni_putnici CASCADE;
DROP TABLE IF EXISTS public.adrese CASCADE;
DROP TABLE IF EXISTS public.rute CASCADE;
DROP TABLE IF EXISTS public.vozila CASCADE;
DROP TABLE IF EXISTS public.vozaci CASCADE;

-- ================================================
-- 1. VOZACI TABLE
-- ================================================
CREATE TABLE public.vozaci (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    ime character varying NOT NULL,
    broj_telefona character varying,
    email character varying,
    aktivan boolean DEFAULT true,
    boja character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- ================================================
-- 2. VOZILA TABLE
-- ================================================
CREATE TABLE public.vozila (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    registarski_broj character varying NOT NULL,
    marka character varying,
    model character varying,
    broj_sedista integer,
    aktivan boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- ================================================
-- 3. RUTE TABLE
-- ================================================
CREATE TABLE public.rute (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    naziv character varying NOT NULL,
    polazak character varying NOT NULL,
    dolazak character varying NOT NULL,
    udaljenost_km numeric,
    prosecno_vreme_min integer,
    aktivan boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- ================================================
-- 4. ADRESE TABLE
-- ================================================
CREATE TABLE public.adrese (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    ulica character varying NOT NULL,
    broj character varying,
    grad character varying NOT NULL,
    postanski_broj character varying,
    koordinate point,
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- ================================================
-- 5. MESECNI_PUTNICI TABLE (with all new fields)
-- ================================================
CREATE TABLE public.mesecni_putnici (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    putnik_ime character varying NOT NULL,
    tip character varying NOT NULL,
    tip_skole character varying,
    broj_telefona character varying,
    polasci_po_danu jsonb NOT NULL,
    tip_prikazivanja character varying DEFAULT 'standard'::character varying,
    radni_dani character varying,
    aktivan boolean DEFAULT true,
    status character varying DEFAULT 'aktivan'::character varying,
    datum_pocetka_meseca date NOT NULL,
    datum_kraja_meseca date NOT NULL,
    ukupna_cena_meseca numeric,
    cena numeric,
    broj_putovanja integer DEFAULT 0,
    broj_otkazivanja integer DEFAULT 0,
    poslednji_putovanje timestamp with time zone,
    
    -- NEW PAYMENT FIELDS
    vreme_placanja timestamp with time zone,
    placeni_mesec integer,
    placena_godina integer,
    
    -- NEW DRIVER TRACKING FIELDS
    vozac_id uuid,
    pokupljen boolean DEFAULT false,
    vreme_pokupljenja timestamp with time zone,
    statistics jsonb DEFAULT '{}'::jsonb,
    
    -- NEW FOREIGN KEY FIELDS
    ruta_id uuid,
    vozilo_id uuid,
    adresa_polaska_id uuid,
    adresa_dolaska_id uuid,
    
    -- SYSTEM FIELDS
    obrisan boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- NEW ADDITIONAL CONTACT FIELDS
    broj_telefona_oca character varying,
    broj_telefona_majke character varying,
    
    -- NEW ADDRESS FIELDS (legacy support)
    adresa_bela_crkva text,
    adresa_vrsac text,
    
    -- NEW NAME FIELDS
    ime character varying,
    
    PRIMARY KEY (id)
);

-- ================================================
-- 6. DNEVNI_PUTNICI TABLE (with new foreign keys)
-- ================================================
CREATE TABLE public.dnevni_putnici (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    ime character varying NOT NULL,
    polazak character varying NOT NULL,
    pokupljen boolean DEFAULT false,
    vreme_dodavanja timestamp with time zone DEFAULT now(),
    mesecna_karta boolean DEFAULT false,
    dan character varying NOT NULL,
    status character varying,
    vreme_pokupljenja timestamp with time zone,
    vreme_placanja timestamp with time zone,
    placeno boolean DEFAULT false,
    iznos_placanja numeric,
    
    -- DRIVER TRACKING FIELDS
    naplatio_vozac_id uuid,
    pokupio_vozac_id uuid,
    dodao_vozac_id uuid,
    vozac_id uuid,
    otkazao_vozac_id uuid,
    vreme_otkazivanja timestamp with time zone,
    
    -- ADDRESS AND ROUTE FIELDS
    adresa text,
    grad character varying NOT NULL,
    broj_telefona character varying,
    datum date NOT NULL,
    
    -- SYSTEM FIELDS
    obrisan boolean DEFAULT false,
    priority integer,
    
    -- NEW FOREIGN KEY FIELDS
    ruta_id uuid,
    vozilo_id uuid,
    adresa_id uuid,
    
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    PRIMARY KEY (id)
);

-- ================================================
-- 7. PUTOVANJA_ISTORIJA TABLE
-- ================================================
CREATE TABLE public.putovanja_istorija (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    mesecni_putnik_id uuid,
    tip_putnika character varying NOT NULL,
    datum date NOT NULL,
    vreme_polaska time without time zone NOT NULL,
    vreme_akcije timestamp with time zone,
    status character varying DEFAULT 'nije_se_pojavio'::character varying NOT NULL,
    putnik_ime character varying NOT NULL,
    broj_telefona character varying,
    cena numeric DEFAULT 0.0,
    dan character varying,
    grad character varying,
    obrisan boolean DEFAULT false,
    pokupljen boolean DEFAULT false,
    vozac_id uuid,
    vreme_placanja timestamp with time zone,
    vreme_pokupljenja timestamp with time zone,
    
    -- NEW FOREIGN KEY FIELDS
    ruta_id uuid,
    vozilo_id uuid,
    adresa_id uuid,
    
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    PRIMARY KEY (id)
);

-- ================================================
-- 8. GPS_LOKACIJE TABLE
-- ================================================
CREATE TABLE public.gps_lokacije (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    vozac_id uuid,
    vozilo_id uuid,
    latitude numeric NOT NULL,
    longitude numeric NOT NULL,
    brzina numeric,
    pravac numeric,
    tacnost numeric,
    vreme timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- ================================================
-- FOREIGN KEY CONSTRAINTS
-- ================================================

-- Mesecni_putnici foreign keys
ALTER TABLE public.mesecni_putnici 
    ADD CONSTRAINT fk_mesecni_putnici_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.mesecni_putnici 
    ADD CONSTRAINT fk_mesecni_putnici_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);

ALTER TABLE public.mesecni_putnici 
    ADD CONSTRAINT fk_mesecni_putnici_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);

ALTER TABLE public.mesecni_putnici 
    ADD CONSTRAINT fk_mesecni_putnici_adresa_polaska 
    FOREIGN KEY (adresa_polaska_id) REFERENCES public.adrese(id);

ALTER TABLE public.mesecni_putnici 
    ADD CONSTRAINT fk_mesecni_putnici_adresa_dolaska 
    FOREIGN KEY (adresa_dolaska_id) REFERENCES public.adrese(id);

-- Dnevni_putnici foreign keys
ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_naplatio_vozac 
    FOREIGN KEY (naplatio_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_pokupio_vozac 
    FOREIGN KEY (pokupio_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_dodao_vozac 
    FOREIGN KEY (dodao_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_otkazao_vozac 
    FOREIGN KEY (otkazao_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT fk_dnevni_putnici_adresa 
    FOREIGN KEY (adresa_id) REFERENCES public.adrese(id);

-- Putovanja_istorija foreign keys
ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT fk_putovanja_istorija_mesecni_putnik 
    FOREIGN KEY (mesecni_putnik_id) REFERENCES public.mesecni_putnici(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT fk_putovanja_istorija_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT fk_putovanja_istorija_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT fk_putovanja_istorija_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT fk_putovanja_istorija_adresa 
    FOREIGN KEY (adresa_id) REFERENCES public.adrese(id);

-- GPS_lokacije foreign keys
ALTER TABLE public.gps_lokacije 
    ADD CONSTRAINT fk_gps_lokacije_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.gps_lokacije 
    ADD CONSTRAINT fk_gps_lokacije_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);

-- ================================================
-- INDEXES for better performance
-- ================================================

-- Indexes for mesecni_putnici
CREATE INDEX idx_mesecni_putnici_vozac_id ON public.mesecni_putnici(vozac_id);
CREATE INDEX idx_mesecni_putnici_ruta_id ON public.mesecni_putnici(ruta_id);
CREATE INDEX idx_mesecni_putnici_vozilo_id ON public.mesecni_putnici(vozilo_id);
CREATE INDEX idx_mesecni_putnici_aktivan ON public.mesecni_putnici(aktivan);
CREATE INDEX idx_mesecni_putnici_datum_pocetka ON public.mesecni_putnici(datum_pocetka_meseca);
CREATE INDEX idx_mesecni_putnici_vreme_placanja ON public.mesecni_putnici(vreme_placanja);

-- Indexes for dnevni_putnici
CREATE INDEX idx_dnevni_putnici_datum ON public.dnevni_putnici(datum);
CREATE INDEX idx_dnevni_putnici_vozac_id ON public.dnevni_putnici(vozac_id);
CREATE INDEX idx_dnevni_putnici_ruta_id ON public.dnevni_putnici(ruta_id);
CREATE INDEX idx_dnevni_putnici_adresa_id ON public.dnevni_putnici(adresa_id);
CREATE INDEX idx_dnevni_putnici_status ON public.dnevni_putnici(status);

-- Indexes for GPS tracking
CREATE INDEX idx_gps_lokacije_vozac_id ON public.gps_lokacije(vozac_id);
CREATE INDEX idx_gps_lokacije_vreme ON public.gps_lokacije(vreme);

-- Indexes for putovanja_istorija
CREATE INDEX idx_putovanja_istorija_datum ON public.putovanja_istorija(datum);
CREATE INDEX idx_putovanja_istorija_mesecni_putnik_id ON public.putovanja_istorija(mesecni_putnik_id);

-- ================================================
-- RLS (Row Level Security) POLICIES
-- ================================================

-- Enable RLS on all tables
ALTER TABLE public.adrese ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnevni_putnici ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gps_lokacije ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesecni_putnici ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.putovanja_istorija ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rute ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vozaci ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vozila ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (allow authenticated users to access all data)
CREATE POLICY "Enable all operations for authenticated users" ON public.adrese FOR ALL TO authenticated USING (true);
CREATE POLICY "Enable all operations for authenticated users" ON public.dnevni_putnici FOR ALL TO authenticated USING (true);
CREATE POLICY "Enable all operations for authenticated users" ON public.mesecni_putnici FOR ALL TO authenticated USING (true);
CREATE POLICY "Enable all operations for authenticated users" ON public.putovanja_istorija FOR ALL TO authenticated USING (true);
CREATE POLICY "Enable all operations for authenticated users" ON public.rute FOR ALL TO authenticated USING (true);
CREATE POLICY "Enable all operations for authenticated users" ON public.vozila FOR ALL TO authenticated USING (true);

-- Special policies for GPS and vozaci (allow anonymous access for tracking)
CREATE POLICY "Allow anon insert" ON public.gps_lokacije FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon insert" ON public.vozaci FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon select" ON public.vozaci FOR SELECT TO anon USING (true);

-- Additional policies for mesecni_putnici (allow anon read for mobile apps)
CREATE POLICY "Allow anon read mesecni_putnici" ON public.mesecni_putnici FOR SELECT TO anon USING (true);
CREATE POLICY "Allow authenticated insert on mesecni_putnici" ON public.mesecni_putnici FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow authenticated read on mesecni_putnici" ON public.mesecni_putnici FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated update on mesecni_putnici" ON public.mesecni_putnici FOR UPDATE TO authenticated USING (true);

-- Additional policies for putovanja_istorija
CREATE POLICY "Allow authenticated read on putovanja_istorija" ON public.putovanja_istorija FOR SELECT TO authenticated USING (true);

-- ================================================
-- COMPLETE MIGRATION FINISHED
-- ================================================