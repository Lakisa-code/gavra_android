-- GAVRA SAMPION SQL WEATHER_ALERTS_LOG 2026
-- Kreiranje tabele weather_alerts_log (#26/30)
-- Datum: 31.01.2026

-- Kreiranje tabele weather_alerts_log
CREATE TABLE weather_alerts_log (
    id SERIAL PRIMARY KEY,
    alert_date DATE NOT NULL,
    alert_types TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dodavanje komentara na tabelu
COMMENT ON TABLE weather_alerts_log IS 'Log vremenskih upozorenja i alert-a';

-- Dodavanje komentara na kolone
COMMENT ON COLUMN weather_alerts_log.id IS 'Jedinstveni identifikator';
COMMENT ON COLUMN weather_alerts_log.alert_date IS 'Datum upozorenja';
COMMENT ON COLUMN weather_alerts_log.alert_types IS 'Tipovi upozorenja (kiša, sneg, vetar, itd.)';
COMMENT ON COLUMN weather_alerts_log.created_at IS 'Datum i vreme kreiranja';

-- Kreiranje indeksa za performanse
CREATE INDEX idx_weather_alerts_log_alert_date ON weather_alerts_log(alert_date);
CREATE INDEX idx_weather_alerts_log_created_at ON weather_alerts_log(created_at);

-- Dodavanje u realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE weather_alerts_log;

-- Test insert da proverimo da li tabela radi
INSERT INTO weather_alerts_log (alert_date, alert_types) VALUES
('2026-01-31', 'kiša, vetar'),
('2026-02-01', 'sneg, hladnoća');

-- Provera da li su podaci uneti
SELECT * FROM weather_alerts_log LIMIT 5;

-- Brisanje test podataka
DELETE FROM weather_alerts_log WHERE alert_types IN ('kiša, vetar', 'sneg, hladnoća');

-- Tabela weather_alerts_log je KREIRANA i SPREMNA za upotrebu!