-- =====================================================
-- SKRIPTA ZA KREIRANJE SVIH 30 TABELA
-- Generisano iz check_all_30_tables.py - 2026-01-31
-- =====================================================

-- 1. admin_audit_logs
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    admin_name TEXT NOT NULL,
    action_type TEXT NOT NULL,
    details TEXT,
    metadata JSONB
);

-- 2. adrese
CREATE TABLE IF NOT EXISTS adrese (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    naziv TEXT,
    grad TEXT NOT NULL,
    ulica TEXT,
    broj TEXT,
    koordinate TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. app_config
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. app_settings
CREATE TABLE IF NOT EXISTS app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by TEXT,
    nav_bar_type TEXT,
    dnevni_zakazivanje_aktivno BOOLEAN DEFAULT false,
    min_version TEXT,
    latest_version TEXT,
    store_url_android TEXT,
    store_url_huawei TEXT
);

-- 5. daily_reports
CREATE TABLE IF NOT EXISTS daily_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vozac TEXT,
    datum DATE NOT NULL,
    ukupan_pazar DECIMAL(10,2),
    sitan_novac DECIMAL(10,2),
    checkin_vreme TIME,
    otkazani_putnici INTEGER DEFAULT 0,
    naplaceni_putnici INTEGER DEFAULT 0,
    pokupljeni_putnici INTEGER DEFAULT 0,
    dugovi_putnici INTEGER DEFAULT 0,
    mesecne_karte INTEGER DEFAULT 0,
    kilometraza INTEGER,
    automatski_generisan BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    vozac_id UUID
);

-- 6. finansije_licno
CREATE TABLE IF NOT EXISTS finansije_licno (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    tip TEXT,
    naziv TEXT,
    iznos DECIMAL(10,2)
);

-- 7. finansije_troskovi
CREATE TABLE IF NOT EXISTS finansije_troskovi (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    naziv TEXT,
    tip TEXT,
    iznos DECIMAL(10,2),
    mesecno BOOLEAN DEFAULT false,
    aktivan BOOLEAN DEFAULT true,
    vozac_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    mesec INTEGER,
    godina INTEGER
);

-- 8. fuel_logs
CREATE TABLE IF NOT EXISTS fuel_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    type TEXT,
    liters DECIMAL(10,2),
    price DECIMAL(10,2),
    amount DECIMAL(10,2),
    vozilo_uuid UUID,
    km INTEGER,
    pump_meter TEXT,
    metadata JSONB
);

-- 9. kapacitet_polazaka
CREATE TABLE IF NOT EXISTS kapacitet_polazaka (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grad TEXT NOT NULL,
    vreme TIME NOT NULL,
    max_mesta INTEGER NOT NULL,
    aktivan BOOLEAN DEFAULT true,
    napomena TEXT
);

-- 10. ml_config
CREATE TABLE IF NOT EXISTS ml_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    data JSONB,
    config JSONB,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 11. payment_reminders_log
CREATE TABLE IF NOT EXISTS payment_reminders_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reminder_date DATE NOT NULL,
    reminder_type TEXT NOT NULL,
    triggered_by TEXT,
    total_unpaid_passengers INTEGER DEFAULT 0,
    total_notifications_sent INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 12. pin_zahtevi
CREATE TABLE IF NOT EXISTS pin_zahtevi (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    email TEXT,
    telefon TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 13. promene_vremena_log
CREATE TABLE IF NOT EXISTS promene_vremena_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    datum DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ciljni_dan TEXT,
    datum_polaska DATE,
    sati_unapred INTEGER
);

-- 14. push_tokens
CREATE TABLE IF NOT EXISTS push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT,
    token TEXT NOT NULL,
    user_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_type TEXT,
    putnik_id UUID,
    vozac_id UUID
);

-- 15. putnik_pickup_lokacije
CREATE TABLE IF NOT EXISTS putnik_pickup_lokacije (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    putnik_ime TEXT,
    lat DECIMAL(10,8),
    lng DECIMAL(11,8),
    vozac_id UUID,
    datum DATE,
    vreme TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 16. racun_sequence
CREATE TABLE IF NOT EXISTS racun_sequence (
    godina INTEGER PRIMARY KEY,
    poslednji_broj INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 17. registrovani_putnici
CREATE TABLE IF NOT EXISTS registrovani_putnici (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_ime TEXT NOT NULL,
    tip TEXT,
    tip_skole TEXT,
    broj_telefona TEXT,
    broj_telefona_oca TEXT,
    broj_telefona_majke TEXT,
    polasci_po_danu JSONB DEFAULT '{}',
    aktivan BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'radi',
    datum_pocetka_meseca DATE,
    datum_kraja_meseca DATE,
    vozac_id TEXT,
    obrisan BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    adresa_bela_crkva_id UUID,
    adresa_vrsac_id UUID,
    pin TEXT,
    cena_po_danu DECIMAL(10,2),
    broj_telefona_2 TEXT,
    email TEXT,
    uklonjeni_termini JSONB DEFAULT '[]',
    firma_naziv TEXT,
    firma_pib TEXT,
    firma_mb TEXT,
    firma_ziro TEXT,
    firma_adresa TEXT,
    treba_racun BOOLEAN DEFAULT false,
    tip_prikazivanja TEXT,
    broj_mesta INTEGER DEFAULT 1,
    merged_into_id UUID,
    is_duplicate BOOLEAN DEFAULT false,
    radni_dani TEXT
);

-- 18. seat_requests
CREATE TABLE IF NOT EXISTS seat_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    grad TEXT,
    datum DATE,
    zeljeno_vreme TIME,
    dodeljeno_vreme TIME,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    priority INTEGER DEFAULT 1,
    batch_id TEXT,
    alternatives JSONB,
    changes_count INTEGER DEFAULT 0,
    broj_mesta INTEGER DEFAULT 1
);

-- 19. troskovi_unosi
CREATE TABLE IF NOT EXISTS troskovi_unosi (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    datum DATE NOT NULL,
    tip TEXT NOT NULL,
    iznos DECIMAL(10,2) NOT NULL,
    opis TEXT,
    vozilo_id UUID,
    vozac_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 20. user_daily_changes
CREATE TABLE IF NOT EXISTS user_daily_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    datum DATE,
    changes_count INTEGER DEFAULT 0,
    last_change_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 21. vozac_lokacije
CREATE TABLE IF NOT EXISTS vozac_lokacije (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vozac_id UUID,
    vozac_ime TEXT,
    lat DECIMAL(10,8),
    lng DECIMAL(11,8),
    grad TEXT,
    vreme_polaska TIME,
    smer TEXT,
    putnici_eta JSONB,
    aktivan BOOLEAN DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 22. vozaci
CREATE TABLE IF NOT EXISTS vozaci (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ime TEXT NOT NULL,
    email TEXT,
    telefon TEXT,
    sifra TEXT,
    boja TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 23. vozila
CREATE TABLE IF NOT EXISTS vozila (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registarski_broj TEXT,
    marka TEXT,
    model TEXT,
    godina_proizvodnje INTEGER,
    broj_mesta INTEGER,
    naziv TEXT,
    broj_sasije TEXT,
    registracija_vazi_do DATE,
    mali_servis_datum DATE,
    mali_servis_km INTEGER,
    veliki_servis_datum DATE,
    veliki_servis_km INTEGER,
    alternator_datum DATE,
    alternator_km INTEGER,
    gume_datum DATE,
    gume_opis TEXT,
    napomena TEXT,
    akumulator_datum DATE,
    akumulator_km INTEGER,
    plocice_datum DATE,
    plocice_km INTEGER,
    trap_datum DATE,
    trap_km INTEGER,
    radio TEXT,
    gume_prednje_datum DATE,
    gume_prednje_opis TEXT,
    gume_zadnje_datum DATE,
    gume_zadnje_opis TEXT,
    kilometraza INTEGER,
    plocice_prednje_datum DATE,
    plocice_prednje_km INTEGER,
    plocice_zadnje_datum DATE,
    plocice_zadnje_km INTEGER,
    gume_prednje_km INTEGER,
    gume_zadnje_km INTEGER
);

-- 24. vozila_istorija
CREATE TABLE IF NOT EXISTS vozila_istorija (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vozilo_id UUID,
    tip TEXT,
    datum DATE,
    km INTEGER,
    opis TEXT,
    cena DECIMAL(10,2),
    pozicija TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 25. voznje_log
CREATE TABLE IF NOT EXISTS voznje_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    datum DATE,
    tip TEXT,
    iznos DECIMAL(10,2),
    vozac_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    placeni_mesec INTEGER,
    placena_godina INTEGER,
    sati_pre_polaska INTEGER,
    broj_mesta INTEGER DEFAULT 1,
    detalji TEXT,
    meta JSONB
);

-- 26. vreme_vozac (sa ispravljenim vozac_id)
CREATE TABLE IF NOT EXISTS vreme_vozac (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grad TEXT NOT NULL,
    vreme TIME NOT NULL,
    dan TEXT NOT NULL,
    vozac_ime TEXT, -- legacy polje
    vozac_id UUID REFERENCES vozaci(id) ON DELETE CASCADE, -- NOVO: foreign key
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(grad, vreme, dan, vozac_id) -- jedan vozač može imati samo jedno vreme po danu i gradu
);

-- 27. weather_alerts_log
CREATE TABLE IF NOT EXISTS weather_alerts_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_date DATE NOT NULL,
    alert_types JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Kreiraj indekse za performanse
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_registrovani_putnici_ime ON registrovani_putnici(putnik_ime);
CREATE INDEX IF NOT EXISTS idx_vreme_vozac_vozac_id ON vreme_vozac(vozac_id);
CREATE INDEX IF NOT EXISTS idx_voznje_log_vozac_id ON voznje_log(vozac_id);
CREATE INDEX IF NOT EXISTS idx_daily_reports_vozac_id ON daily_reports(vozac_id);

-- Omogući Row Level Security za sve tabele
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE adrese ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE finansije_licno ENABLE ROW LEVEL SECURITY;
ALTER TABLE finansije_troskovi ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE kapacitet_polazaka ENABLE ROW LEVEL SECURITY;
ALTER TABLE ml_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_reminders_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE pin_zahtevi ENABLE ROW LEVEL SECURITY;
ALTER TABLE promene_vremena_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE putnik_pickup_lokacije ENABLE ROW LEVEL SECURITY;
ALTER TABLE racun_sequence ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrovani_putnici ENABLE ROW LEVEL SECURITY;
ALTER TABLE seat_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE troskovi_unosi ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_daily_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE vozac_lokacije ENABLE ROW LEVEL SECURITY;
ALTER TABLE vozaci ENABLE ROW LEVEL SECURITY;
ALTER TABLE vozila ENABLE ROW LEVEL SECURITY;
ALTER TABLE vozila_istorija ENABLE ROW LEVEL SECURITY;
ALTER TABLE voznje_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE vreme_vozac ENABLE ROW LEVEL SECURITY;
ALTER TABLE weather_alerts_log ENABLE ROW LEVEL SECURITY;

-- Kreiraj osnovne politike za čitanje
CREATE POLICY "Enable read access for all users" ON admin_audit_logs FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON adrese FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON app_config FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON app_settings FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON daily_reports FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON finansije_licno FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON finansije_troskovi FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON fuel_logs FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON kapacitet_polazaka FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON ml_config FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON payment_reminders_log FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON pin_zahtevi FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON promene_vremena_log FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON push_tokens FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON putnik_pickup_lokacije FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON racun_sequence FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON registrovani_putnici FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON seat_requests FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON troskovi_unosi FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON user_daily_changes FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON vozac_lokacije FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON vozaci FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON vozila FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON vozila_istorija FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON voznje_log FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON vreme_vozac FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON weather_alerts_log FOR SELECT USING (true);

-- Omogući realtime subscriptions za ključne tabele
ALTER PUBLICATION supabase_realtime ADD TABLE vozaci;
ALTER PUBLICATION supabase_realtime ADD TABLE registrovani_putnici;
ALTER PUBLICATION supabase_realtime ADD TABLE vreme_vozac;
ALTER PUBLICATION supabase_realtime ADD TABLE voznje_log;
ALTER PUBLICATION supabase_realtime ADD TABLE seat_requests;