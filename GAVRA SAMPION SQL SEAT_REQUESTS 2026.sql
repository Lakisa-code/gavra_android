-- GAVRA SAMPION SQL SEAT_REQUESTS 2026
-- Kreiranje tabele seat_requests sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
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

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN seat_requests.putnik_id IS 'ID putnika koji traži sedište';
COMMENT ON COLUMN seat_requests.grad IS 'Grad polaska';
COMMENT ON COLUMN seat_requests.datum IS 'Datum putovanja';
COMMENT ON COLUMN seat_requests.zeljeno_vreme IS 'Željeno vreme polaska';
COMMENT ON COLUMN seat_requests.dodeljeno_vreme IS 'Dodeljeno vreme polaska';
COMMENT ON COLUMN seat_requests.status IS 'Status zahteva: pending, approved, rejected, cancelled';
COMMENT ON COLUMN seat_requests.priority IS 'Prioritet zahteva (1-10)';
COMMENT ON COLUMN seat_requests.alternatives IS 'Alternativni termini u JSON formatu';
COMMENT ON COLUMN seat_requests.changes_count IS 'Broj promena zahteva';
COMMENT ON COLUMN seat_requests.broj_mesta IS 'Broj traženih mesta';

-- ===========================================
-- 3. CONSTRAINTS
-- ===========================================
ALTER TABLE seat_requests ADD CONSTRAINT check_status
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

ALTER TABLE seat_requests ADD CONSTRAINT check_priority
    CHECK (priority >= 1 AND priority <= 10);

-- ===========================================
-- 4. INDEXI
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_seat_requests_putnik_id ON seat_requests(putnik_id);
CREATE INDEX IF NOT EXISTS idx_seat_requests_grad_datum ON seat_requests(grad, datum);
CREATE INDEX IF NOT EXISTS idx_seat_requests_status ON seat_requests(status);
CREATE INDEX IF NOT EXISTS idx_seat_requests_priority ON seat_requests(priority DESC);
CREATE INDEX IF NOT EXISTS idx_seat_requests_batch_id ON seat_requests(batch_id);

-- ===========================================
-- 5. RLS (Row Level Security)
-- ===========================================
ALTER TABLE seat_requests ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON seat_requests FOR SELECT USING (true);

-- Politika za insert - samo autentifikovani korisnici
CREATE POLICY "Enable insert for authenticated users" ON seat_requests FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Politika za update - samo vlasnik zahteva ili admin
CREATE POLICY "Enable update for request owner or admin" ON seat_requests FOR UPDATE
USING (auth.uid()::text = putnik_id::text OR auth.role() = 'admin');

-- ===========================================
-- 6. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE seat_requests;