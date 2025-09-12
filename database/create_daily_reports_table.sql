-- Kreiraj tabelu za automatske dnevne popise
CREATE TABLE IF NOT EXISTS daily_reports (
    id SERIAL PRIMARY KEY,
    vozac VARCHAR(50) NOT NULL,
    datum DATE NOT NULL,
    ukupan_pazar DECIMAL(10,2) DEFAULT 0.00,
    sitan_novac DECIMAL(10,2) DEFAULT 0.00,
    broj_putnika INTEGER DEFAULT 0,
    broj_naplacenih INTEGER DEFAULT 0,
    broj_dugova INTEGER DEFAULT 0,
    kilometraza DECIMAL(8,2) DEFAULT 0.00,
    pazar_obicni DECIMAL(10,2) DEFAULT 0.00,
    pazar_mesecne DECIMAL(10,2) DEFAULT 0.00,
    dodati_putnici INTEGER DEFAULT 0,
    otkazani_putnici INTEGER DEFAULT 0,
    pokupljeni_putnici INTEGER DEFAULT 0,
    mesecne_karte INTEGER DEFAULT 0,
    automatski_generisan BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint - jedan popis po vozaču po danu
    UNIQUE(vozac, datum)
);

-- Index za brže pretrage
CREATE INDEX IF NOT EXISTS idx_daily_reports_vozac_datum ON daily_reports (vozac, datum);
CREATE INDEX IF NOT EXISTS idx_daily_reports_datum ON daily_reports (datum);

-- Komentar tabele
COMMENT ON TABLE daily_reports IS 'Automatski generisani dnevni popisi vozača na osnovu realnih GPS i putničkih podataka';
