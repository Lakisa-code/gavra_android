-- Create mesecni_putnici table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.mesecni_putnici (
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
    
    -- ADDITIONAL CONTACT FIELDS
    broj_telefona_oca character varying,
    broj_telefona_majke character varying,
    
    -- ADDRESS FIELDS (legacy support)
    adresa_bela_crkva text,
    adresa_vrsac text,
    
    PRIMARY KEY (id)
);

-- Enable RLS
ALTER TABLE public.mesecni_putnici ENABLE ROW LEVEL SECURITY;

-- Create basic RLS policies
CREATE POLICY "Allow all operations for authenticated users" ON public.mesecni_putnici
    FOR ALL USING (auth.role() = 'authenticated');

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_aktivan ON public.mesecni_putnici(aktivan);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_obrisan ON public.mesecni_putnici(obrisan);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_tip ON public.mesecni_putnici(tip);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_datum_pocetka ON public.mesecni_putnici(datum_pocetka_meseca);