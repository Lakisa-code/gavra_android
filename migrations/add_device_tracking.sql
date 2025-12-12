-- Dodaj kolonu za praćenje uređaja na kojem je putnik prijavljen
ALTER TABLE registrovani_putnici 
ADD COLUMN IF NOT EXISTS prijavljen_device_id TEXT;

-- Opciono: dodaj kolonu za vreme poslednje prijave
ALTER TABLE registrovani_putnici 
ADD COLUMN IF NOT EXISTS poslednja_prijava TIMESTAMPTZ;
