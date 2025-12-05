-- ⚔️ BINARYBITCH MIGRATION: Zakazane Vožnje
-- Self-booking sistem za mesečne putnike
-- Champione, izvrši ovo u Supabase SQL Editor!

-- 1. Kreiraj tabelu zakazane_voznje
CREATE TABLE IF NOT EXISTS zakazane_voznje (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  putnik_id UUID NOT NULL REFERENCES mesecni_putnici(id) ON DELETE CASCADE,
  datum DATE NOT NULL,
  smena TEXT CHECK (smena IN ('prva', 'druga', 'treca', 'slobodan', 'custom')),
  vreme_bc TEXT,          -- Vreme polaska iz BC (npr. '06:00')
  vreme_vs TEXT,          -- Vreme polaska iz VS (npr. '14:00')
  status TEXT DEFAULT 'zakazano' CHECK (status IN ('zakazano', 'otkazano', 'zavrseno')),
  napomena TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Jedan putnik može imati samo jedno zakazivanje po datumu
  UNIQUE(putnik_id, datum)
);

-- 2. Indeksi za brže pretrage
CREATE INDEX IF NOT EXISTS idx_zakazane_voznje_datum ON zakazane_voznje(datum);
CREATE INDEX IF NOT EXISTS idx_zakazane_voznje_putnik ON zakazane_voznje(putnik_id);
CREATE INDEX IF NOT EXISTS idx_zakazane_voznje_status ON zakazane_voznje(status);
CREATE INDEX IF NOT EXISTS idx_zakazane_voznje_datum_status ON zakazane_voznje(datum, status);

-- 3. Komentar na tabelu
COMMENT ON TABLE zakazane_voznje IS 'Nedeljno zakazivanje vožnji od strane mesečnih putnika - Self Booking';
COMMENT ON COLUMN zakazane_voznje.smena IS 'Tip smene: prva (jutarnja), druga (popodnevna), treca (nocna), slobodan, custom';
COMMENT ON COLUMN zakazane_voznje.vreme_bc IS 'Vreme polaska iz Bele Crkve';
COMMENT ON COLUMN zakazane_voznje.vreme_vs IS 'Vreme polaska iz Vršca';

-- 4. Trigger za automatski updated_at
CREATE OR REPLACE FUNCTION update_zakazane_voznje_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_zakazane_voznje_updated_at ON zakazane_voznje;
CREATE TRIGGER trigger_zakazane_voznje_updated_at
  BEFORE UPDATE ON zakazane_voznje
  FOR EACH ROW
  EXECUTE FUNCTION update_zakazane_voznje_updated_at();

-- 5. RLS (Row Level Security) - opciono, za sada disable
ALTER TABLE zakazane_voznje ENABLE ROW LEVEL SECURITY;

-- Dozvoli sve operacije za authenticated i service_role
CREATE POLICY "Allow all for authenticated" ON zakazane_voznje
  FOR ALL USING (true) WITH CHECK (true);

-- 6. View za lakše pregledanje zakazanih vožnji po datumu
CREATE OR REPLACE VIEW zakazane_voznje_pregled AS
SELECT 
  zv.id,
  zv.datum,
  zv.smena,
  zv.vreme_bc,
  zv.vreme_vs,
  zv.status,
  zv.napomena,
  mp.putnik_ime,
  mp.tip,
  mp.broj_telefona,
  zv.created_at,
  zv.updated_at
FROM zakazane_voznje zv
JOIN mesecni_putnici mp ON mp.id = zv.putnik_id
WHERE zv.status = 'zakazano'
ORDER BY zv.datum, zv.vreme_bc;

COMMENT ON VIEW zakazane_voznje_pregled IS 'Pregled zakazanih vožnji sa podacima o putniku';

-- ✅ DONE! Tabela zakazane_voznje je spremna!
