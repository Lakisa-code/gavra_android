-- Add missing columns to putovanja_istorija table
DO $$ 
BEGIN
    -- Add cena column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'putovanja_istorija' 
                   AND column_name = 'cena') THEN
        ALTER TABLE public.putovanja_istorija 
        ADD COLUMN cena numeric DEFAULT 0.0;
    END IF;
    
    -- Add tip_putnika column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'putovanja_istorija' 
                   AND column_name = 'tip_putnika') THEN
        ALTER TABLE public.putovanja_istorija 
        ADD COLUMN tip_putnika character varying DEFAULT 'dnevni'::character varying;
    END IF;
    
    -- Add putnik_ime column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'putovanja_istorija' 
                   AND column_name = 'putnik_ime') THEN
        ALTER TABLE public.putovanja_istorija 
        ADD COLUMN putnik_ime character varying;
    END IF;
END $$;