-- Kreiranje tabele za registrovane dnevne putnike
-- Izvršiti u Supabase SQL Editor: https://supabase.com/dashboard/project/gjtabtwudbrmfeyjiicu/sql

CREATE TABLE IF NOT EXISTS dnevni_putnici_registrovani (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ime TEXT NOT NULL,
  prezime TEXT NOT NULL,
  telefon TEXT NOT NULL UNIQUE,
  adresa TEXT,
  grad TEXT NOT NULL,
  status TEXT DEFAULT 'aktivan' CHECK (status IN ('aktivan', 'neaktivan', 'blokiran')),
  zahtev_id INTEGER REFERENCES zahtevi_pristupa(id),
  pin TEXT,
  push_token TEXT,
  push_provider TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indeks za brže pretraživanje po telefonu
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_registrovani_telefon ON dnevni_putnici_registrovani(telefon);

-- RLS policy
ALTER TABLE dnevni_putnici_registrovani ENABLE ROW LEVEL SECURITY;

-- Dozvoli pristup za sve (anon i authenticated)
CREATE POLICY "Allow select for all" ON dnevni_putnici_registrovani
  FOR SELECT USING (true);

CREATE POLICY "Allow insert for all" ON dnevni_putnici_registrovani
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update for all" ON dnevni_putnici_registrovani
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete for all" ON dnevni_putnici_registrovani
  FOR DELETE USING (true);

-- Komentar
COMMENT ON TABLE dnevni_putnici_registrovani IS 'Registrovani dnevni putnici koji su prošli odobrenje admina';
