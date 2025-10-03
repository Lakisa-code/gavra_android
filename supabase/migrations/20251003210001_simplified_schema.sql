-- ================================================
-- GAVRA ANDROID - SIMPLIFIED COMPLETE SCHEMA
-- Migration: 20251003210001
-- Creates all tables with correct vozaci UUIDs
-- ================================================

-- 1. CREATE VOZACI TABLE AND INSERT DATA
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

-- Insert vozaci with exact UUIDs from VozacMappingService
INSERT INTO public.vozaci (id, ime, aktivan) VALUES 
    ('8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f', 'Bilevski', true),
    ('7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f', 'Bruda', true),
    ('6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e', 'Bojan', true),
    ('5b379394-084e-1c7d-76bf-fc193a5b6c7d', 'Svetlana', true)
ON CONFLICT (id) DO NOTHING;

-- 2. CREATE OTHER HELPER TABLES
CREATE TABLE IF NOT EXISTS public.rute (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    naziv character varying NOT NULL,
    opis text,
    aktivan boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

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

-- 3. CREATE MAIN TABLES WITH FOREIGN KEYS
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
    vreme_placanja timestamp with time zone,
    placeni_mesec integer,
    placena_godina integer,
    vozac_id uuid REFERENCES public.vozaci(id),
    pokupljen boolean DEFAULT false,
    vreme_pokupljenja timestamp with time zone,
    statistics jsonb DEFAULT '{}'::jsonb,
    obrisan boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    ruta_id uuid REFERENCES public.rute(id),
    vozilo_id uuid REFERENCES public.vozila(id),
    adresa_polaska_id uuid REFERENCES public.adrese(id),
    adresa_dolaska_id uuid REFERENCES public.adrese(id),
    ime character varying,
    prezime character varying,
    datum_pocetka date,
    datum_kraja date,
    PRIMARY KEY (id)
);

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
    naplatio_vozac_id uuid REFERENCES public.vozaci(id),
    pokupio_vozac_id uuid REFERENCES public.vozaci(id),
    dodao_vozac_id uuid REFERENCES public.vozaci(id),
    otkazao_vozac_id uuid REFERENCES public.vozaci(id),
    vozac_id uuid REFERENCES public.vozaci(id),
    obrisan boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    ruta_id uuid REFERENCES public.rute(id),
    vozilo_id uuid REFERENCES public.vozila(id),
    adresa_id uuid REFERENCES public.adrese(id),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.putovanja_istorija (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    mesecni_putnik_id uuid REFERENCES public.mesecni_putnici(id),
    datum_putovanja date NOT NULL,
    vreme_polaska character varying,
    status character varying DEFAULT 'obavljeno'::character varying,
    vozac_id uuid REFERENCES public.vozaci(id),
    napomene text,
    obrisan boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    ruta_id uuid REFERENCES public.rute(id),
    vozilo_id uuid REFERENCES public.vozila(id),
    adresa_id uuid REFERENCES public.adrese(id),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.gps_lokacije (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    vozac_id uuid REFERENCES public.vozaci(id),
    vozilo_id uuid REFERENCES public.vozila(id),
    latitude numeric NOT NULL,
    longitude numeric NOT NULL,
    brzina numeric,
    pravac numeric,
    tacnost numeric,
    vreme timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- 4. CREATE INDEXES
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_vozac_id ON public.mesecni_putnici(vozac_id);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_aktivan ON public.mesecni_putnici(aktivan);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_obrisan ON public.mesecni_putnici(obrisan);

-- 5. ENABLE RLS WITH PERMISSIVE POLICIES FOR DEVELOPMENT
ALTER TABLE public.vozaci ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesecni_putnici ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnevni_putnici ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.putovanja_istorija ENABLE ROW LEVEL SECURITY;

-- Allow all operations for development
CREATE POLICY "dev_allow_all_vozaci" ON public.vozaci FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "dev_allow_all_mesecni" ON public.mesecni_putnici FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "dev_allow_all_dnevni" ON public.dnevni_putnici FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "dev_allow_all_istorija" ON public.putovanja_istorija FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- 6. VERIFICATION
SELECT 'VOZACI INSERTED:' as status, count(*) as count FROM public.vozaci;
SELECT 'VOZACI DATA:' as status, id, ime FROM public.vozaci ORDER BY ime;