-- ============================================
-- MIGRACIJA: Kapacitet polazaka
-- Datum: 2024-12-07
-- Opis: Tabela za max mesta po polasku
-- ============================================

-- 1. Kreiranje tabele
CREATE TABLE IF NOT EXISTS kapacitet_polazaka (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grad TEXT NOT NULL,           -- 'BC' ili 'VS'
  vreme TEXT NOT NULL,          -- '5:00', '6:00', itd.
  max_mesta INT DEFAULT 8,      -- Maksimalan broj mesta
  aktivan BOOLEAN DEFAULT true, -- Da li je polazak aktivan
  napomena TEXT,                -- Opciona napomena (npr. "Mali kombi")
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(grad, vreme)
);

-- 2. Omogući Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE kapacitet_polazaka;

-- 3. RLS
ALTER TABLE kapacitet_polazaka ENABLE ROW LEVEL SECURITY;

-- Svi mogu čitati
CREATE POLICY "kapacitet_select_all"
ON kapacitet_polazaka FOR SELECT USING (true);

-- Samo admin može menjati (auth.role = 'service_role' ili authenticated admin)
CREATE POLICY "kapacitet_all_admin"
ON kapacitet_polazaka FOR ALL USING (true);

-- 4. Inicijalni podaci - Bela Crkva polasci (zimski)
INSERT INTO kapacitet_polazaka (grad, vreme, max_mesta) VALUES
('BC', '5:00', 8),
('BC', '6:00', 8),
('BC', '7:00', 8),
('BC', '8:00', 8),
('BC', '9:00', 8),
('BC', '11:00', 8),
('BC', '12:00', 8),
('BC', '13:00', 8),
('BC', '14:00', 8),
('BC', '15:30', 8),
('BC', '18:00', 8)
ON CONFLICT (grad, vreme) DO NOTHING;

-- 5. Inicijalni podaci - Vršac polasci (zimski)
INSERT INTO kapacitet_polazaka (grad, vreme, max_mesta) VALUES
('VS', '6:00', 8),
('VS', '7:00', 8),
('VS', '8:00', 8),
('VS', '10:00', 8),
('VS', '11:00', 8),
('VS', '12:00', 8),
('VS', '13:00', 8),
('VS', '14:00', 8),
('VS', '15:30', 8),
('VS', '17:00', 8),
('VS', '19:00', 8)
ON CONFLICT (grad, vreme) DO NOTHING;

-- 6. Trigger za updated_at
CREATE OR REPLACE FUNCTION update_kapacitet_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER kapacitet_updated_at_trigger
BEFORE UPDATE ON kapacitet_polazaka
FOR EACH ROW EXECUTE FUNCTION update_kapacitet_updated_at();

-- ============================================
-- TABELA: promene_vremena_log
-- Prati ko je kada menjao vreme (za ograničenje jednom dnevno)
-- ============================================

CREATE TABLE IF NOT EXISTS promene_vremena_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  putnik_id TEXT NOT NULL,       -- ID putnika (UUID ili int kao string)
  datum DATE NOT NULL,           -- Datum promene (za ograničenje jednom dnevno)
  staro_vreme TEXT,              -- Prethodno vreme
  novo_vreme TEXT,               -- Novo vreme
  grad TEXT,                     -- 'BC' ili 'VS'
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(putnik_id, datum)       -- Samo jedna promena po danu
);

-- RLS za promene_vremena_log
ALTER TABLE promene_vremena_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "promene_vremena_select_all"
ON promene_vremena_log FOR SELECT USING (true);

CREATE POLICY "promene_vremena_insert_all"
ON promene_vremena_log FOR INSERT WITH CHECK (true);

-- ============================================
-- KRAJ MIGRACIJE
-- ============================================
