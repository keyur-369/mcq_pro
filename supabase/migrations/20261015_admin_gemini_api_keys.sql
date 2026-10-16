-- ============================================================================
-- MCQ Pro: Gemini API Keys Schema, RLS, and Security Configuration
-- Version: 20261015_admin_gemini_api_keys.sql
--
-- STRICT RESTRICTION COMPLIANCE:
-- This script DOES NOT modify, touch, alter, migrate, truncate, or drop public.keep_alive.
-- ============================================================================

-- 1. Ensure table exists with correct schema
CREATE TABLE IF NOT EXISTS public.gemini_api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    api_key TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    tokens_used BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure indexes for performance
CREATE INDEX IF NOT EXISTS idx_gemini_api_keys_active ON public.gemini_api_keys (is_active);
CREATE INDEX IF NOT EXISTS idx_gemini_api_keys_created_at ON public.gemini_api_keys (created_at DESC);

-- 2. Enable Row-Level Security
ALTER TABLE public.gemini_api_keys ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Admins have full access to gemini_api_keys" ON public.gemini_api_keys;
DROP POLICY IF EXISTS "Teachers can read active gemini_api_keys" ON public.gemini_api_keys;
DROP POLICY IF EXISTS "Teachers can increment token usage" ON public.gemini_api_keys;

-- Policy 1: Admins can do everything (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Admins have full access to gemini_api_keys"
ON public.gemini_api_keys
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Policy 2: Teachers can SELECT active keys only (so they can pick from dropdown)
CREATE POLICY "Teachers can read active gemini_api_keys"
ON public.gemini_api_keys
FOR SELECT
TO authenticated
USING (public.is_teacher() AND is_active = true);

-- Policy 3: Allow teachers to update token usage on active keys
CREATE POLICY "Teachers can increment token usage"
ON public.gemini_api_keys
FOR UPDATE
TO authenticated
USING (public.is_teacher() AND is_active = true)
WITH CHECK (public.is_teacher() AND is_active = true);

-- 3. Security Definer RPC function for safely incrementing token usage
CREATE OR REPLACE FUNCTION public.increment_gemini_token_usage(
    p_key_id UUID,
    p_tokens INT
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_updated_tokens BIGINT;
BEGIN
    UPDATE public.gemini_api_keys
    SET 
        tokens_used = tokens_used + COALESCE(p_tokens, 0),
        updated_at = now()
    WHERE id = p_key_id
    RETURNING tokens_used INTO v_updated_tokens;

    RETURN COALESCE(v_updated_tokens, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_gemini_token_usage(UUID, INT) TO authenticated;
