-- GAVRA SAMPION SQL VREME_VOZAC 2026
-- Kreiranje tabele vreme_vozac (#25/30)
-- Datum: 31.01.2026

-- Kreiranje tabele vreme_vozac
CREATE TABLE vreme_vozac (
    id SERIAL PRIMARY KEY,
    grad VARCHAR(100) NOT NULL,
    vreme TIME NOT NULL,
    dan VARCHAR(20) NOT NULL,
    vozac_ime VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dodavanje komentara na tabelu
COMMENT ON TABLE vreme_vozac IS 'Vremena polazaka vozača po gradovima i danima';

-- Dodavanje komentara na kolone
COMMENT ON COLUMN vreme_vozac.id IS 'Jedinstveni identifikator';
COMMENT ON COLUMN vreme_vozac.grad IS 'Grad polaska';
COMMENT ON COLUMN vreme_vozac.vreme IS 'Vreme polaska';
COMMENT ON COLUMN vreme_vozac.dan IS 'Dan u nedelji';
COMMENT ON COLUMN vreme_vozac.vozac_ime IS 'Ime vozača';
COMMENT ON COLUMN vreme_vozac.created_at IS 'Datum i vreme kreiranja';
COMMENT ON COLUMN vreme_vozac.updated_at IS 'Datum i vreme poslednje izmene';

-- Kreiranje indeksa za performanse
CREATE INDEX idx_vreme_vozac_grad ON vreme_vozac(grad);
CREATE INDEX idx_vreme_vozac_dan ON vreme_vozac(dan);
CREATE INDEX idx_vreme_vozac_vozac_ime ON vreme_vozac(vozac_ime);
CREATE INDEX idx_vreme_vozac_grad_dan ON vreme_vozac(grad, dan);

-- Dodavanje u realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE vreme_vozac;

-- Test insert da proverimo da li tabela radi
INSERT INTO vreme_vozac (grad, vreme, dan, vozac_ime) VALUES
('Beograd', '07:00:00', 'Ponedeljak', 'Marko Marković'),
('Novi Sad', '08:30:00', 'Utorak', 'Petar Petrović');

-- Provera da li su podaci uneti
SELECT * FROM vreme_vozac LIMIT 5;

-- Brisanje test podataka
DELETE FROM vreme_vozac WHERE vozac_ime IN ('Marko Marković', 'Petar Petrović');

-- Tabela vreme_vozac je KREIRANA i SPREMNA za upotrebu!