-- Completely disable RLS for daily_checkins table
ALTER TABLE daily_checkins DISABLE ROW LEVEL SECURITY;

-- OR if you want to keep RLS but allow public access:
-- CREATE POLICY "Enable all operations for public" ON daily_checkins FOR ALL TO public USING (true) WITH CHECK (true);
