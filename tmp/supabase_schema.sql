-- SQL skripta za kreiranje nove Supabase baze podataka za Gavra Android aplikaciju
-- Datum: 30. septembar 2025.
-- Ova skripta kreira normalizovanu strukturu sa više tabela

-- Omogući RLS (Row Level Security) ako je potrebno
-- ALTER TABLE ... ENABLE ROW LEVEL SECURITY;

-- ===========================================
-- 1. Tabela: vozaci (Drivers)
-- ===========================================
CREATE TABLE vozaci (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ime VARCHAR(100) NOT NULL UNIQUE,
  broj_telefona VARCHAR(20),
  email VARCHAR(100),
  aktivan BOOLEAN DEFAULT true,
  boja VARCHAR(7), -- hex boja za UI, npr. '#7C4DFF'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za vozaci
ALTER TABLE vozaci ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON vozaci
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- 2. Tabela: vozila (Vehicles)
-- ===========================================
CREATE TABLE vozila (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registarski_broj VARCHAR(20) NOT NULL UNIQUE,
  marka VARCHAR(50),
  model VARCHAR(50),
  broj_sedista INTEGER CHECK (broj_sedista > 0),
  aktivan BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za vozila
ALTER TABLE vozila ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON vozila
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- 3. Tabela: rute (Routes)
-- ===========================================
CREATE TABLE rute (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naziv VARCHAR(100) NOT NULL,
  polazak VARCHAR(100) NOT NULL, -- npr. 'Bela Crkva'
  dolazak VARCHAR(100) NOT NULL, -- npr. 'Vrsac'
  udaljenost_km DECIMAL(5,2),
  prosecno_vreme_min INTEGER,
  aktivan BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za rute
ALTER TABLE rute ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON rute
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- 4. Tabela: adrese (Addresses)
-- ===========================================
CREATE TABLE adrese (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ulica VARCHAR(200) NOT NULL,
  broj VARCHAR(10),
  grad VARCHAR(100) NOT NULL,
  postanski_broj VARCHAR(10),
  koordinate POINT, -- Za PostGIS GPS koordinate (x=lon, y=lat)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za adrese
ALTER TABLE adrese ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON adrese
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- 5. Tabela: dnevni_putnici (Daily Passengers)
-- ===========================================
CREATE TABLE dnevni_putnici (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ime VARCHAR(100) NOT NULL,
  polazak VARCHAR(100) NOT NULL,
  pokupljen BOOLEAN DEFAULT false,
  vreme_dodavanja TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  mesecna_karta BOOLEAN DEFAULT false,
  dan VARCHAR(10) NOT NULL, -- 'pon', 'uto', 'sre', itd.
  status VARCHAR(50), -- 'otkazano', 'pokupljen', 'bolovanje', 'godisnji'
  status_vreme TIMESTAMP WITH TIME ZONE,
  vreme_pokupljenja TIMESTAMP WITH TIME ZONE,
  vreme_placanja TIMESTAMP WITH TIME ZONE,
  placeno BOOLEAN DEFAULT false,
  iznos_placanja DECIMAL(10,2),
  naplatio_vozac_id UUID REFERENCES vozaci(id),
  pokupio_vozac_id UUID REFERENCES vozaci(id),
  dodao_vozac_id UUID REFERENCES vozaci(id),
  vozac_id UUID REFERENCES vozaci(id),
  grad VARCHAR(50) NOT NULL, -- 'Bela Crkva' ili 'Vrsac'
  otkazao_vozac_id UUID REFERENCES vozaci(id),
  vreme_otkazivanja TIMESTAMP WITH TIME ZONE,
  adresa TEXT,
  obrisan BOOLEAN DEFAULT false,
  priority INTEGER CHECK (priority >= 1 AND priority <= 5),
  broj_telefona VARCHAR(20),
  datum DATE NOT NULL,
  ruta_id UUID REFERENCES rute(id),
  vozilo_id UUID REFERENCES vozila(id),
  adresa_id UUID REFERENCES adrese(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za dnevni_putnici
ALTER TABLE dnevni_putnici ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON dnevni_putnici
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- 6. Tabela: mesecni_putnici (Monthly Passengers)
-- ===========================================
CREATE TABLE mesecni_putnici (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  putnik_ime VARCHAR(100) NOT NULL,
  tip VARCHAR(50) NOT NULL, -- 'osnovna', 'srednja', 'fakultet', itd.
  tip_skole VARCHAR(100),
  broj_telefona VARCHAR(20),
  polasci_po_danu JSONB NOT NULL, -- {"pon": ["6 VS", "13 BC"], "uto": ["7 VS"]}
  tip_prikazivanja VARCHAR(50) DEFAULT 'standard',
  radni_dani VARCHAR(50), -- "pon,uto,sre,cet,pet"
  aktivan BOOLEAN DEFAULT true,
  status VARCHAR(50) DEFAULT 'aktivan',
  datum_pocetka_meseca DATE NOT NULL,
  datum_kraja_meseca DATE NOT NULL,
  ukupna_cena_meseca DECIMAL(10,2),
  cena DECIMAL(10,2), -- cena mesečne karte
  broj_putovanja INTEGER DEFAULT 0,
  broj_otkazivanja INTEGER DEFAULT 0,
  poslednji_putovanje TIMESTAMP WITH TIME ZONE,
  vreme_placanja TIMESTAMP WITH TIME ZONE,
  placeni_mesec INTEGER CHECK (placeni_mesec >= 1 AND placeni_mesec <= 12),
  placena_godina INTEGER CHECK (placena_godina >= 2020),
  vozac_id UUID REFERENCES vozaci(id),
  pokupljen BOOLEAN DEFAULT false,
  vreme_pokupljenja TIMESTAMP WITH TIME ZONE,
  statistics JSONB DEFAULT '{}', -- fleksibilne metrike
  ruta_id UUID REFERENCES rute(id),
  vozilo_id UUID REFERENCES vozila(id),
  adresa_polaska_id UUID REFERENCES adrese(id),
  adresa_dolaska_id UUID REFERENCES adrese(id),
  obrisan BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za mesecni_putnici
ALTER TABLE mesecni_putnici ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON mesecni_putnici
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- 7. Tabela: putovanja_istorija (Travel History)
-- ===========================================
CREATE TABLE putovanja_istorija (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mesecni_putnik_id UUID REFERENCES mesecni_putnici(id),
  tip_putnika VARCHAR(20) NOT NULL CHECK (tip_putnika IN ('mesecni', 'dnevni')),
  datum DATE NOT NULL,
  vreme_polaska TIME NOT NULL,
  vreme_akcije TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL DEFAULT 'nije_se_pojavio',
  putnik_ime VARCHAR(100) NOT NULL,
  broj_telefona VARCHAR(20),
  cena DECIMAL(10,2) DEFAULT 0.0,
  dan VARCHAR(10), -- 'pon', 'uto', itd.
  grad VARCHAR(50), -- 'Bela Crkva' ili 'Vrsac'
  obrisan BOOLEAN DEFAULT false,
  pokupljen BOOLEAN DEFAULT false,
  vozac_id UUID REFERENCES vozaci(id),
  vreme_placanja TIMESTAMP WITH TIME ZONE,
  vreme_pokupljenja TIMESTAMP WITH TIME ZONE,
  ruta_id UUID REFERENCES rute(id),
  vozilo_id UUID REFERENCES vozila(id),
  adresa_id UUID REFERENCES adrese(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za putovanja_istorija
ALTER TABLE putovanja_istorija ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON putovanja_istorija
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- 8. Tabela: gps_lokacije (GPS Locations)
-- ===========================================
CREATE TABLE gps_lokacije (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vozac_id UUID REFERENCES vozaci(id),
  vozilo_id UUID REFERENCES vozila(id),
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  brzina DECIMAL(5,2), -- km/h
  pravac DECIMAL(5,2), -- stepeni
  tacnost DECIMAL(5,2), -- metri
  vreme TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS politika za gps_lokacije
ALTER TABLE gps_lokacije ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable all operations for authenticated users" ON gps_lokacije
FOR ALL USING (auth.role() = 'authenticated');

-- ===========================================
-- INDEKSI ZA PERFORMANSE
-- ===========================================

-- Indeksi za dnevni_putnici
CREATE INDEX idx_dnevni_putnici_datum ON dnevni_putnici(datum);
CREATE INDEX idx_dnevni_putnici_vozac ON dnevni_putnici(vozac_id);
CREATE INDEX idx_dnevni_putnici_grad ON dnevni_putnici(grad);
CREATE INDEX idx_dnevni_putnici_obrisan ON dnevni_putnici(obrisan);
CREATE INDEX idx_dnevni_putnici_ruta ON dnevni_putnici(ruta_id);

-- Indeksi za mesecni_putnici
CREATE INDEX idx_mesecni_putnici_vozac ON mesecni_putnici(vozac_id);
CREATE INDEX idx_mesecni_putnici_aktivan ON mesecni_putnici(aktivan);
CREATE INDEX idx_mesecni_putnici_obrisan ON mesecni_putnici(obrisan);
CREATE INDEX idx_mesecni_putnici_ruta ON mesecni_putnici(ruta_id);
CREATE INDEX idx_mesecni_putnici_placeni_mesec ON mesecni_putnici(placeni_mesec, placena_godina);

-- Indeksi za putovanja_istorija
CREATE INDEX idx_putovanja_istorija_datum ON putovanja_istorija(datum);
CREATE INDEX idx_putovanja_istorija_vozac ON putovanja_istorija(vozac_id);
CREATE INDEX idx_putovanja_istorija_mesecni_putnik ON putovanja_istorija(mesecni_putnik_id);
CREATE INDEX idx_putovanja_istorija_obrisan ON putovanja_istorija(obrisan);

-- Indeksi za gps_lokacije
CREATE INDEX idx_gps_lokacije_vozac ON gps_lokacije(vozaC_id);
CREATE INDEX idx_gps_lokacije_vozilo ON gps_lokacije(vozilo_id);
CREATE INDEX idx_gps_lokacije_vreme ON gps_lokacije(vreme);

-- ===========================================
-- TRIGGERI ZA AUTOMATSKO AŽURIRANJE updated_at
-- ===========================================

-- Funkcija za ažuriranje updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Dodavanje trigera na sve tabele
CREATE TRIGGER update_vozaci_updated_at BEFORE UPDATE ON vozaci FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vozila_updated_at BEFORE UPDATE ON vozila FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_rute_updated_at BEFORE UPDATE ON rute FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_dnevni_putnici_updated_at BEFORE UPDATE ON dnevni_putnici FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_mesecni_putnici_updated_at BEFORE UPDATE ON mesecni_putnici FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_putovanja_istorija_updated_at BEFORE UPDATE ON putovanja_istorija FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- INICIJALNI PODACI
-- ===========================================

-- Dodavanje početnih vozača
INSERT INTO vozaci (ime, broj_telefona, boja) VALUES
('Bruda', NULL, '#7C4DFF'),
('Bilevski', NULL, '#FF9800'),
('Bojan', NULL, '#00E5FF'),
('Svetlana', NULL, '#FF1493');

-- Dodavanje početnih ruta
INSERT INTO rute (naziv, polazak, dolazak, udaljenost_km, prosecno_vreme_min) VALUES
('Bela Crkva - Vrsac', 'Bela Crkva', 'Vrsac', 45.5, 60),
('Vrsac - Bela Crkva', 'Vrsac', 'Bela Crkva', 45.5, 60);

-- Dodavanje početnih vozila (primeri)
INSERT INTO vozila (registarski_broj, marka, model, broj_sedista) VALUES
('BG-123-AB', 'Mercedes', 'Sprinter', 20),
('BG-456-CD', 'Volkswagen', 'Crafter', 18);

-- ===========================================
-- KOMENTARI I NAPOMENE
-- ===========================================
/*
NAPOMENE ZA IMPLEMENTACIJU:

1. PostGIS ekstenzija: Ako želite da koristite GPS koordinate u tabeli adrese,
   omogućite PostGIS ekstenziju:
   CREATE EXTENSION IF NOT EXISTS postgis;

2. RLS Politike: Prilagodite RLS politike prema vašim potrebama za sigurnost.

3. Backup: Uvek napravite backup pre izvršavanja ove skripte.

4. Testiranje: Testirajte na staging bazi pre produkcije.

5. Migracija: Ako imate postojeće podatke, biće potrebna migraciona skripta.

ZA POKRETANJE:
- Kopirajte ovu skriptu u Supabase SQL Editor
- Izvršite je u delovima ili celu odjednom
- Proverite da li su sve tabele kreirane
*/