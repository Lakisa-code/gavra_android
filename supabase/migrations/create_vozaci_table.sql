-- 🔥 KREIRANJE TABELE VOZACI ZA FLUTTER APP
-- Pokreni ovu skriptu u Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.vozaci (
  id uuid not null default gen_random_uuid (),
  ime character varying not null,
  email character varying null,
  telefon character varying null,
  aktivan boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  kusur numeric null default 0.0,
  constraint vozaci_pkey primary key (id),
  constraint vozaci_ime_key unique (ime),
  constraint vozaci_kusur_check check ((kusur >= (0)::numeric))
) TABLESPACE pg_default;

-- Indeksi za bolje performanse
CREATE INDEX IF NOT EXISTS idx_vozaci_ime ON vozaci(ime);
CREATE INDEX IF NOT EXISTS idx_vozaci_aktivan ON vozaci(aktivan);

-- RLS (Row Level Security) politike
ALTER TABLE vozaci ENABLE ROW LEVEL SECURITY;

-- Politika: Svi mogu da čitaju aktivne vozače
CREATE POLICY "Čitanje aktivnih vozača" ON vozaci
    FOR SELECT USING (aktivan = true);

-- Funkcija za automatsko ažuriranje updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger za automatsko ažuriranje updated_at
CREATE TRIGGER update_vozaci_updated_at
    BEFORE UPDATE ON vozaci
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Komentari za dokumentaciju
COMMENT ON TABLE vozaci IS 'Tabela vozača sa podrškom za kusur tracking';
COMMENT ON COLUMN vozaci.ime IS 'Ime vozača (jedinstveno)';
COMMENT ON COLUMN vozaci.kusur IS 'Trenutni kusur vozača (pozitivna vrednost)';