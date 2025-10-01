-- Update RLS for gps_lokacije
DROP POLICY \
Enable
all
operations
for
authenticated
users\ ON gps_lokacije;
CREATE POLICY \Allow
anon
insert\ ON gps_lokacije FOR INSERT WITH CHECK (true);
