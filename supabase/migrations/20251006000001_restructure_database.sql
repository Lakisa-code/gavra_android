-- Migration: Restructure database tables
-- Date: 2025-10-06
-- Purpose: Align database schema with code expectations

-- 1. Update putovanja_istorija table structure
ALTER TABLE public.putovanja_istorija 
ADD COLUMN IF NOT EXISTS tip_putnika character varying DEFAULT 'dnevni',
ADD COLUMN IF NOT EXISTS putnik_ime character varying,
ADD COLUMN IF NOT EXISTS cena numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS placeni_mesec integer,
ADD COLUMN IF NOT EXISTS placena_godina integer;

-- 2. Create dnevni_putnici table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.dnevni_putnici (
  id uuid not null default gen_random_uuid (),
  putnik_ime character varying not null,
  telefon character varying null,
  grad character varying not null,
  broj_mesta integer null,
  datum_putovanja date not null,
  vreme_polaska character varying null,
  cena numeric null,
  status character varying null default 'aktivno'::character varying,
  naplatio_vozac_id uuid null,
  pokupio_vozac_id uuid null,
  dodao_vozac_id uuid null,
  otkazao_vozac_id uuid null,
  vozac_id uuid null,
  obrisan boolean null default false,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  ruta_id uuid null,
  vozilo_id uuid null,
  adresa_id uuid null,
  constraint dnevni_putnici_pkey primary key (id)
);

-- 3. Create vozaci table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.vozaci (
  id uuid not null default gen_random_uuid (),
  ime character varying not null,
  email character varying null,
  telefon character varying null,
  aktivan boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint vozaci_pkey primary key (id),
  constraint vozaci_ime_key unique (ime)
);

-- 4. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_tip_putnika ON public.putovanja_istorija USING btree (tip_putnika);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_putnik_ime ON public.putovanja_istorija USING btree (putnik_ime);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_cena ON public.putovanja_istorija USING btree (cena);
CREATE INDEX IF NOT EXISTS idx_putovanja_istorija_mesec_godina ON public.putovanja_istorija USING btree (placeni_mesec, placena_godina);

-- 5. Add foreign key constraints for new tables
DO $$
BEGIN
  -- Add foreign keys for dnevni_putnici if they don't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'dnevni_putnici_naplatio_vozac_id_fkey') THEN
    ALTER TABLE public.dnevni_putnici ADD CONSTRAINT dnevni_putnici_naplatio_vozac_id_fkey FOREIGN KEY (naplatio_vozac_id) REFERENCES vozaci (id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'dnevni_putnici_pokupio_vozac_id_fkey') THEN
    ALTER TABLE public.dnevni_putnici ADD CONSTRAINT dnevni_putnici_pokupio_vozac_id_fkey FOREIGN KEY (pokupio_vozac_id) REFERENCES vozaci (id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'dnevni_putnici_dodao_vozac_id_fkey') THEN
    ALTER TABLE public.dnevni_putnici ADD CONSTRAINT dnevni_putnici_dodao_vozac_id_fkey FOREIGN KEY (dodao_vozac_id) REFERENCES vozaci (id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'dnevni_putnici_otkazao_vozac_id_fkey') THEN
    ALTER TABLE public.dnevni_putnici ADD CONSTRAINT dnevni_putnici_otkazao_vozac_id_fkey FOREIGN KEY (otkazao_vozac_id) REFERENCES vozaci (id);
  END IF;
END $$;

-- 6. Grant permissions
GRANT ALL ON public.dnevni_putnici TO anon, authenticated;
GRANT ALL ON public.vozaci TO anon, authenticated;