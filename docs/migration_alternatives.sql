-- Dodaj alternatives kolonu u seat_requests tabelu
ALTER TABLE seat_requests ADD COLUMN IF NOT EXISTS alternatives text[];
