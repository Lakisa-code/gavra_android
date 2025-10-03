-- Privremeno isključi RLS za mesecni_putnici da rešimo UUID problem
-- Created: 2025-10-03 10:45

-- VAŽNO: Ovo je privremeno rešenje za development
-- U produkciji RLS treba da bude uključen sa ispravnom autentifikacijom

-- Isključi RLS za mesecni_putnici tabelu
ALTER TABLE public.mesecni_putnici DISABLE ROW LEVEL SECURITY;

-- Ostaviti komentar za buduće reference
COMMENT ON TABLE public.mesecni_putnici IS 'RLS privremeno isključen za development - treba vratiti u produkciji';