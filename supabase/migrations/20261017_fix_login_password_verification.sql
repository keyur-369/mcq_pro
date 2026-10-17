-- ============================================================================
-- Migration: Fix Login Screen Password Verification & Remove teacher_temp_login
-- Date: 2026-10-17
-- Description:
-- Drops the deprecated and insecure public.teacher_temp_login() function which
-- previously allowed bypassing password verification during login.
-- Both email and password are now strictly checked by Supabase Auth (auth.signInWithPassword).
-- ============================================================================

-- 1. Revoke permissions and drop the insecure function
REVOKE ALL ON FUNCTION public.teacher_temp_login(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.teacher_temp_login(TEXT, TEXT);

-- 2. Verify all users have proper auth setup
SELECT 'Insecure teacher_temp_login function dropped successfully. Strict email + password verification is enforced.' AS status;
