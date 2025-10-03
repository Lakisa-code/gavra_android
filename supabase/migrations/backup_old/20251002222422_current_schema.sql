-- ================================================
-- GAVRA ANDROID - CURRENT DATABASE SCHEMA
-- Migration: 20251002222422
-- This migration adds new fields to existing tables
-- ================================================

-- Add new fields to mesecni_putnici table
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS vreme_placanja timestamp with time zone;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS placeni_mesec integer;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS placena_godina integer;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS vozac_id uuid;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS pokupljen boolean DEFAULT false;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS vreme_pokupljenja timestamp with time zone;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS statistics jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS ruta_id uuid;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS vozilo_id uuid;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS adresa_polaska_id uuid;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS adresa_dolaska_id uuid;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS broj_telefona_oca character varying;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS broj_telefona_majke character varying;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS adresa_bela_crkva text;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS adresa_vrsac text;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS ime character varying;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS prezime character varying;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS datum_pocetka date;
ALTER TABLE public.mesecni_putnici ADD COLUMN IF NOT EXISTS datum_kraja date;

-- Add new fields to dnevni_putnici table
ALTER TABLE public.dnevni_putnici ADD COLUMN IF NOT EXISTS ruta_id uuid;
ALTER TABLE public.dnevni_putnici ADD COLUMN IF NOT EXISTS vozilo_id uuid;
ALTER TABLE public.dnevni_putnici ADD COLUMN IF NOT EXISTS adresa_id uuid;
ALTER TABLE public.dnevni_putnici ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now();
ALTER TABLE public.dnevni_putnici ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

-- Add new fields to putovanja_istorija table
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS ruta_id uuid;
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS vozilo_id uuid;
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS adresa_id uuid;
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now();
ALTER TABLE public.putovanja_istorija ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

-- Add foreign key constraints
ALTER TABLE public.mesecni_putnici ADD CONSTRAINT IF NOT EXISTS fk_mesecni_putnici_vozac 
    FOREIGN KEY (vozac_id) REFERENCES public.vozaci(id);
ALTER TABLE public.mesecni_putnici ADD CONSTRAINT IF NOT EXISTS fk_mesecni_putnici_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);
ALTER TABLE public.mesecni_putnici ADD CONSTRAINT IF NOT EXISTS fk_mesecni_putnici_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);
ALTER TABLE public.mesecni_putnici ADD CONSTRAINT IF NOT EXISTS fk_mesecni_putnici_adresa_polaska 
    FOREIGN KEY (adresa_polaska_id) REFERENCES public.adrese(id);
ALTER TABLE public.mesecni_putnici ADD CONSTRAINT IF NOT EXISTS fk_mesecni_putnici_adresa_dolaska 
    FOREIGN KEY (adresa_dolaska_id) REFERENCES public.adrese(id);

ALTER TABLE public.dnevni_putnici ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);
ALTER TABLE public.dnevni_putnici ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);
ALTER TABLE public.dnevni_putnici ADD CONSTRAINT IF NOT EXISTS fk_dnevni_putnici_adresa 
    FOREIGN KEY (adresa_id) REFERENCES public.adrese(id);

ALTER TABLE public.putovanja_istorija ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_ruta 
    FOREIGN KEY (ruta_id) REFERENCES public.rute(id);
ALTER TABLE public.putovanja_istorija ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_vozilo 
    FOREIGN KEY (vozilo_id) REFERENCES public.vozila(id);
ALTER TABLE public.putovanja_istorija ADD CONSTRAINT IF NOT EXISTS fk_putovanja_istorija_adresa 
    FOREIGN KEY (adresa_id) REFERENCES public.adrese(id);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_vozac_id ON public.mesecni_putnici(vozac_id);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_ruta_id ON public.mesecni_putnici(ruta_id);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_vozilo_id ON public.mesecni_putnici(vozilo_id);
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_vreme_placanja ON public.mesecni_putnici(vreme_placanja);

CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_ruta_id ON public.dnevni_putnici(ruta_id);
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_adresa_id ON public.dnevni_putnici(adresa_id);

CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_ruta_id ON public.putovanja_istorija(ruta_id);

-- Migration completed successfully