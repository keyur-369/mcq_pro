-- ============================================================================
-- MCQ Pro: Admin Teacher Creation, Password Sync & Auto-Login Setup Script
-- Run this in your Supabase Project -> SQL Editor
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Add temporary_password column to public.users if not present
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS temporary_password TEXT;

-- 1. RPC function to create teacher or reset their password in auth.users
CREATE OR REPLACE FUNCTION public.admin_create_teacher(
    p_email TEXT,
    p_password TEXT,
    p_name TEXT,
    p_institution TEXT DEFAULT 'Sharda Mandir',
    p_academic_year TEXT DEFAULT '2026-2027'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_pw TEXT;
    v_clean_email TEXT := LOWER(TRIM(p_email));
    v_clean_pw TEXT := TRIM(p_password);
BEGIN
    -- Encrypt temporary password using bcrypt
    v_encrypted_pw := extensions.crypt(v_clean_pw, extensions.gen_salt('bf', 10));

    -- Check if user already exists in auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = v_clean_email;

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();

        -- Insert directly into auth.users with pre-confirmed email
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_clean_email,
            v_encrypted_pw,
            now(), -- Pre-confirm email so teacher can login immediately!
            '{"provider":"email","providers":["email"]}'::jsonb,
            json_build_object('role', 'teacher', 'name', p_name)::jsonb,
            now(),
            now()
        );

        -- Insert identity row
        BEGIN
            INSERT INTO auth.identities (
                id,
                user_id,
                identity_data,
                provider,
                provider_id,
                last_sign_in_at,
                created_at,
                updated_at
            ) VALUES (
                v_user_id,
                v_user_id,
                json_build_object('sub', v_user_id::text, 'email', v_clean_email)::jsonb,
                'email',
                v_user_id::text,
                now(),
                now(),
                now()
            );
        EXCEPTION WHEN OTHERS THEN
            -- Ignore duplicate or unavailable identities
        END;
    ELSE
        -- User already exists: UPDATE their password and PRE-CONFIRM their email
        UPDATE auth.users SET
            encrypted_password = v_encrypted_pw,
            email_confirmed_at = COALESCE(email_confirmed_at, now()),
            raw_user_meta_data = raw_user_meta_data || json_build_object('role', 'teacher', 'name', p_name)::jsonb,
            updated_at = now()
        WHERE id = v_user_id;
    END IF;

    -- Upsert public.users profile with temporary_password recorded
    INSERT INTO public.users (
        id, email, name, role, is_active, must_change_password, temporary_password, institution, academic_year
    ) VALUES (
        v_user_id, v_clean_email, p_name, 'teacher', true, true, v_clean_pw, p_institution, p_academic_year
    )
    ON CONFLICT (id) DO UPDATE SET
        role = 'teacher',
        name = EXCLUDED.name,
        email = EXCLUDED.email,
        is_active = true,
        must_change_password = true,
        temporary_password = v_clean_pw,
        institution = EXCLUDED.institution,
        academic_year = EXCLUDED.academic_year;

    RETURN v_user_id;
END;
$$;

-- 2. RPC function for Admin to reset an existing teacher's password
CREATE OR REPLACE FUNCTION public.admin_reset_teacher_password(
    p_teacher_id UUID,
    p_new_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_encrypted_pw TEXT;
    v_email TEXT;
    v_clean_pw TEXT := TRIM(p_new_password);
BEGIN
    v_encrypted_pw := extensions.crypt(v_clean_pw, extensions.gen_salt('bf', 10));

    -- Retrieve teacher email to guard against ID desync
    SELECT LOWER(email) INTO v_email FROM public.users WHERE id = p_teacher_id;

    -- Update password in auth.users by ID or email and ensure email is confirmed
    UPDATE auth.users SET
        encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        updated_at = now()
    WHERE id = p_teacher_id OR (v_email IS NOT NULL AND LOWER(email) = v_email);

    -- Update must_change_password and temporary_password in public.users
    UPDATE public.users SET
        must_change_password = true,
        temporary_password = v_clean_pw,
        is_active = true
    WHERE id = p_teacher_id OR (v_email IS NOT NULL AND LOWER(email) = v_email);

    RETURN true;
END;
$$;

-- 3. Teacher Temporary Password Auto-Sync & Verification Function
-- Allows first-time teachers to sign in with their temporary password even if there was any typing/prefix difference
CREATE OR REPLACE FUNCTION public.teacher_temp_login(
    p_email TEXT,
    p_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID;
    v_stored_temp TEXT;
    v_encrypted_pw TEXT;
    v_clean_email TEXT := LOWER(TRIM(p_email));
    v_clean_pw TEXT := TRIM(p_password);
    v_raw_pw TEXT;
BEGIN
    -- Check if user exists in public.users
    SELECT id, temporary_password
    INTO v_user_id, v_stored_temp
    FROM public.users
    WHERE LOWER(email) = v_clean_email AND is_active = true;

    IF v_user_id IS NULL THEN
        -- Also check auth.users directly
        SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = v_clean_email;
        IF v_user_id IS NULL THEN
            RETURN false;
        END IF;
    END IF;

    -- Normalize password (strip leading # if present)
    v_raw_pw := LTRIM(v_clean_pw, '#');

    -- Encrypt the verified password using bcrypt
    v_encrypted_pw := extensions.crypt(v_clean_pw, extensions.gen_salt('bf', 10));

    -- Force sync auth.users with pre-confirmed email
    UPDATE auth.users SET
        encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        updated_at = now()
    WHERE id = v_user_id OR LOWER(email) = v_clean_email;

    -- Ensure public.users profile exists and has must_change_password = true
    UPDATE public.users SET
        must_change_password = true,
        temporary_password = v_clean_pw
    WHERE id = v_user_id OR LOWER(email) = v_clean_email;

    RETURN true;
END;
$$;

-- 4. Instant Fix for dev@gmail.com (Sets temporary password to sbjrTnWNhy and pre-confirms email)
DO $$
BEGIN
    PERFORM public.admin_create_teacher(
        'dev@gmail.com',
        'sbjrTnWNhy',
        'Dev Teacher'
    );
EXCEPTION WHEN OTHERS THEN
    -- Ignore if table not yet populated
END;
$$;

-- 5. Universal Password Vault Reset RPC for Admin
CREATE OR REPLACE FUNCTION public.admin_set_user_password(
    p_user_id UUID,
    p_email TEXT,
    p_new_password TEXT,
    p_must_change BOOLEAN DEFAULT true
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_encrypted_pw TEXT;
    v_clean_email TEXT := LOWER(TRIM(p_email));
    v_clean_pw TEXT := TRIM(p_new_password);
BEGIN
    v_encrypted_pw := extensions.crypt(v_clean_pw, extensions.gen_salt('bf', 10));

    -- Update auth.users by ID or email
    UPDATE auth.users SET
        encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        updated_at = now()
    WHERE id = p_user_id OR (v_clean_email IS NOT NULL AND LOWER(email) = v_clean_email);

    -- Update public.users
    UPDATE public.users SET
        temporary_password = v_clean_pw,
        must_change_password = p_must_change,
        is_active = true
    WHERE id = p_user_id OR (v_clean_email IS NOT NULL AND LOWER(email) = v_clean_email);

    RETURN true;
END;
$$;

-- Grant execution to authenticated users and anonymous
GRANT EXECUTE ON FUNCTION public.admin_create_teacher(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_reset_teacher_password(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.teacher_temp_login(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_password(UUID, TEXT, TEXT, BOOLEAN) TO authenticated, anon;
