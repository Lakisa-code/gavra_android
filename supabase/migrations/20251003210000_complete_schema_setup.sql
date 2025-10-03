-- ================================================
-- GAVRA ANDROID - COMPLETE SCHEMA SETUP
-- Migration: 20251003210000
-- Creates all tables and populates with vozaci data
-- ================================================

-- 1. CREATE VOZACI TABLE FIRST
CREATE TABLE IF NOT EXISTS public.vozaci (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    ime character varying NOT NULL UNIQUE,
    email character varying,
    telefon character varying,
    aktivan boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- 2. INSERT VOZACI DATA WITH EXACT UUIDs FROM VozacMappingService
INSERT INTO public.vozaci (id, ime, aktivan) VALUES 
    ('8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f', 'Bilevski', true),
    ('7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f', 'Bruda', true),
    ('6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e', 'Bojan', true),
    ('5b379394-084e-1c7d-76bf-fc193a5b6c7d', 'Svetlana', true)
ON CONFLICT (id) DO NOTHING;

-- 3. CREATE RUTE TABLE
CREATE TABLE IF NOT EXISTS public.rute (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    naziv character varying NOT NULL,
    opis text,
    aktivan boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- 4. CREATE VOZILA TABLE
CREATE TABLE IF NOT EXISTS public.vozila (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    registarski_broj character varying NOT NULL UNIQUE,
    marka character varying,
    model character varying,
    godina_proizvodnje integer,
    broj_mesta integer,
    aktivan boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- 5. CREATE ADRESE TABLE
CREATE TABLE IF NOT EXISTS public.adrese (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    naziv character varying NOT NULL,
    grad character varying,
    ulica character varying,
    broj character varying,
    koordinate jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- 6. CREATE MESECNI_PUTNICI TABLE
CREATE TABLE IF NOT EXISTS public.mesecni_putnici (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    putnik_ime character varying NOT NULL,
    tip character varying NOT NULL,
    tip_skole character varying,
    broj_telefona character varying,
    broj_telefona_oca character varying,
    broj_telefona_majke character varying,
    polasci_po_danu jsonb NOT NULL,
    adresa_bela_crkva text,
    adresa_vrsac text,
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
    poslednje_putovanje timestamp with time zone,
    
    -- PAYMENT FIELDS
    vreme_placanja timestamp with time zone,
    placeni_mesec integer,
    placena_godina integer,
    
    -- DRIVER TRACKING FIELDS
    vozac_id uuid,
    pokupljen boolean DEFAULT false,
    vreme_pokupljenja timestamp with time zone,
    statistics jsonb DEFAULT '{}'::jsonb,
    
    -- SYSTEM FIELDS
    obrisan boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- LEGACY SUPPORT FIELDS
    ruta_id uuid,
    vozilo_id uuid,
    adresa_polaska_id uuid,
    adresa_dolaska_id uuid,
    ime character varying, -- legacy support
    prezime character varying, -- legacy support
    datum_pocetka date, -- legacy support
    datum_kraja date, -- legacy support
    
    PRIMARY KEY (id)
);

-- 7. CREATE DNEVNI_PUTNICI TABLE
CREATE TABLE IF NOT EXISTS public.dnevni_putnici (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    putnik_ime character varying NOT NULL,
    telefon character varying,
    grad character varying NOT NULL,
    broj_mesta integer,
    datum_putovanja date NOT NULL,
    vreme_polaska character varying,
    cena numeric,
    status character varying DEFAULT 'aktivno'::character varying,
    naplatio_vozac_id uuid,
    pokupio_vozac_id uuid,
    dodao_vozac_id uuid,
    otkazao_vozac_id uuid,
    vozac_id uuid,
    obrisan boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    ruta_id uuid,
    vozilo_id uuid,
    adresa_id uuid,
    PRIMARY KEY (id)
);

-- 8. CREATE PUTOVANJA_ISTORIJA TABLE
CREATE TABLE IF NOT EXISTS public.putovanja_istorija (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    mesecni_putnik_id uuid,
    datum_putovanja date NOT NULL,
    vreme_polaska character varying,
    status character varying DEFAULT 'obavljeno'::character varying,
    vozac_id uuid,
    napomene text,
    obrisan boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    ruta_id uuid,
    vozilo_id uuid,
    adresa_id uuid,
    PRIMARY KEY (id)
);

-- 9. CREATE GPS_LOKACIJE TABLE
CREATE TABLE IF NOT EXISTS public.gps_lokacije (
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

-- 10. ADD FOREIGN KEY CONSTRAINTS
-- Mesecni_putnici foreign keys
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mesecni_putnici_vozac') THEN
        ALTER TABLE public.mesecni_putnici 
            ADD CONSTRAINT fk_mesecni_putnici_vozac 
            FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mesecni_putnici_ruta') THEN
        ALTER TABLE public.mesecni_putnici 
            ADD CONSTRAINT fk_mesecni_putnici_ruta 
            FOREIGN KEY (ruta_id) REFERENCES public.rute(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mesecni_putnici_vozilo') THEN
        ALTER TABLE public.mesecni_putnici 
            ADD CONSTRAINT fk_mesecni_putnici_vozilo 
            FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mesecni_putnici_adresa_polaska') THEN
        ALTER TABLE public.mesecni_putnici 
            ADD CONSTRAINT fk_mesecni_putnici_adresa_polaska 
            FOREIGN KEY (adresa_polaska_id) REFERENCES public.adrese(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mesecni_putnici_adresa_dolaska') THEN
        ALTER TABLE public.mesecni_putnici 
            ADD CONSTRAINT fk_mesecni_putnici_adresa_dolaska 
            FOREIGN KEY (adresa_dolaska_id) REFERENCES public.adrese(id);
    END IF;
END $$;

-- Dnevni_putnici foreign keys
ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_naplatio_vozac 
    FOREIGN KEY (naplatio_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_pokupio_vozac 
    FOREIGN KEY (pokupio_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_dodao_vozac 
    FOREIGN KEY (dodao_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_otkazao_vozac 
    FOREIGN KEY (otkazao_vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);

ALTER TABLE public.dnevni_putnici 
    ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_adresa 
    FOREIGN KEY (adresa_id) REFERENCES public.adrese(id);

-- Putovanja_istorija foreign keys
ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_mesecni_putnik 
    FOREIGN KEY (mesecni_putnik_id) REFERENCES public.mesecni_putnici(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);

ALTER TABLE public.putovanja_istorija 
    ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_adresa 
    FOREIGN KEY (adresa_id) REFERENCES public.adrese(id);

-- GPS_lokacije foreign keys
ALTER TABLE public.gps_lokacije 
    ADD CONSTRAINT IF NOT EXISTS fk_gps_lokacije_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);

ALTER TABLE public.gps_lokacije 
    ADD CONSTRAINT IF NOT EXISTS fk_gps_lokacije_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);

-- 11. CREATE INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_vozac_id ON public.mesecni_putnici(vozac_id);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_aktivan ON public.mesecni_putnici(aktivan);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_obrisan ON public.mesecni_putnici(obrisan);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_tip ON public.mesecni_putnici(tip);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_datum_pocetka ON public.mesecni_putnici(datum_pocetka_meseca);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_vreme_placanja ON public.mesecni_putnici(vreme_placanja);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_placeni_mesec ON public.mesecni_putnici(placeni_mesec);

CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_vozac_id ON public.dnevni_putnici(vozac_id);
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_datum ON public.dnevni_putnici(datum_putovanja);
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_grad ON public.dnevni_putnici(grad);
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_obrisan ON public.dnevni_putnici(obrisan);

CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_mesecni_putnik ON public.putovanja_istorija(mesecni_putnik_id);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_vozac ON public.putovanja_istorija(vozac_id);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_datum ON public.putovanja_istorija(datum_putovanja);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_obrisan ON public.putovanja_istorija(obrisan);

CREATE INDEX IF NOT EXISTS idx_gps_lokacije_vozac ON public.gps_lokacije(vozac_id);
CREATE INDEX IF NOT EXISTS idx_gps_lokacije_vozilo ON public.gps_lokacije(vozilo_id);
CREATE INDEX IF NOT EXISTS idx_gps_lokacije_vreme ON public.gps_lokacije(vreme);

-- 12. ENABLE RLS (Row Level Security) BUT WITH PERMISSIVE POLICIES
ALTER TABLE public.mesecni_putnici ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnevni_putnici ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.putovanja_istorija ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vozaci ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rute ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vozila ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adrese ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gps_lokacije ENABLE ROW LEVEL SECURITY;

-- 13. CREATE PERMISSIVE RLS POLICIES (for development - tighten in production)
-- Allow all operations for anon and authenticated users (DEVELOPMENT ONLY)
CREATE POLICY "Allow all for anon" ON public.vozaci FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.vozaci FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for anon" ON public.mesecni_putnici FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.mesecni_putnici FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for anon" ON public.dnevni_putnici FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.dnevni_putnici FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for anon" ON public.putovanja_istorija FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.putovanja_istorija FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for anon" ON public.rute FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.rute FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for anon" ON public.vozila FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.vozila FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for anon" ON public.adrese FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.adrese FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for anon" ON public.gps_lokacije FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON public.gps_lokacije FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 14. VERIFICATION QUERIES
-- Verify vozaci data was inserted correctly
SELECT 'VOZACI VERIFICATION:' as check_type, id, ime FROM public.vozaci ORDER BY ime;

-- Comments for documentation
COMMENT ON TABLE public.vozaci IS 'Vozači aplikacije sa UUID-ovima iz VozacMappingService';
COMMENT ON TABLE public.mesecni_putnici IS 'Mesečni putnici sa foreign key na vozaci tabelu';
COMMENT ON COLUMN public.mesecni_putnici.vozac_id IS 'UUID vozača iz vozaci tabele';