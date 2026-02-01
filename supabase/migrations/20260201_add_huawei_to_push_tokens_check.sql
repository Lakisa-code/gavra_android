-- Add Huawei to allowed providers in push_tokens table
ALTER TABLE push_tokens 
DROP CONSTRAINT IF EXISTS check_provider;

ALTER TABLE push_tokens 
ADD CONSTRAINT check_provider 
CHECK (provider IN ('fcm', 'apns', 'huawei'));