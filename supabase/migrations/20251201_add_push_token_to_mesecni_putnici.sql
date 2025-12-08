-- ============================================
-- MIGRACIJA: Dodaj push_token kolone u mesecni_putnici
-- Za slanje notifikacija putnicima kada prevoz krene
-- ============================================

-- Dodaj kolone za push notifikacije
ALTER TABLE mesecni_putnici 
ADD COLUMN IF NOT EXISTS push_token TEXT,
ADD COLUMN IF NOT EXISTS push_provider TEXT; -- 'fcm' ili 'huawei'

-- Komentari
COMMENT ON COLUMN mesecni_putnici.push_token IS 'FCM ili Huawei push token za slanje notifikacija';
COMMENT ON COLUMN mesecni_putnici.push_provider IS 'Provider: fcm ili huawei';

-- Index za brže pretraživanje po tokenu
CREATE INDEX IF NOT EXISTS idx_mesecni_putnici_push_token ON mesecni_putnici(push_token) WHERE push_token IS NOT NULL;
