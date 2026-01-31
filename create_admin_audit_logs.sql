-- Kreiranje admin_audit_logs tabele
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    admin_name TEXT NOT NULL,
    action_type TEXT NOT NULL,
    details TEXT,
    metadata JSONB
);

-- Kreiraj indeks
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs(created_at);

-- Omogući Row Level Security
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Kreiraj politiku za čitanje
CREATE POLICY "Enable read access for all users" ON admin_audit_logs FOR SELECT USING (true);

-- Omogući realtime
ALTER PUBLICATION supabase_realtime ADD TABLE admin_audit_logs;