-- Migration: create push_tokens table used by register-push-token function
-- Run this in your Supabase SQL editor or include in your migration pipeline

CREATE TABLE IF NOT EXISTS public.push_tokens (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider text NOT NULL,
  token text NOT NULL,
  user_id text NULL,
  created_at timestamptz DEFAULT now()
);

-- Optional index for lookups by user
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON public.push_tokens (user_id);
