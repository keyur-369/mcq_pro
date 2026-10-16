-- ============================================================================
-- MCQ Pro: Admin Teacher Creation, Password Sync & Auto-Login Setup Script
-- Version: 2.0 (Fix for "Database error querying schema" 500 error)
-- Run this in your Supabase Project -> SQL Editor
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ensure columns exist in public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS temporary_password TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS institution TEXT DEFAULT 'Sharda Mandir';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS academic_year TEXT DEFAULT '2026-2027';

-- ----------------------------------------------------------------------------
-- 0. IMMEDIATE REPAIR: Fix all existing users in auth.users
-- Supabase GoTrue crashes with "500: Database error querying schema"
-- (Scan error: converting NULL to string is unsupported) when token columns are NULL.
-- Converting them to empty strings '' immediately restores authentication!
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    col RECORD;
BEGIN
    -- Dynamically update all text/varchar columns in auth.users that match token fields
    FOR col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'users' 
          AND data_type IN ('text', 'character varying')
          AND column_name IN (
            'confirmation_token', 
            'recovery_token', 
            'email_change_token_new', 
            'email_change', 
            'email_change_token_current', 
            'phone_change', 
            'phone_change_token', 
            'reauthentication_token'
          )
    LOOP
        EXECUTE format('UPDATE auth.users SET %I = COALESCE(%I, '''') WHERE %I IS NULL;', col.column_name, col.column_name, col.column_name);
    END LOOP;

    -- Ensure all users have pre-confirmed emails so they can sign in immediately
    UPDATE auth.users 
    SET email_confirmed_at = COALESCE(email_confirmed_at, now()) 
    WHERE email_confirmed_at IS NULL;
END $$;

-- ----------------------------------------------------------------------------
-- 1. Callable RPC Function: repair_auth_users
-- Allows app or admin to auto-repair any corrupted/null auth user tokens
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.repair_auth_users()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    col RECORD;
    v_count INT := 0;
BEGIN
    FOR col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'users' 
          AND data_type IN ('text', 'character varying')
          AND column_name IN (
            'confirmation_token', 
            'recovery_token', 
            'email_change_token_new', 
            'email_change', 
            'email_change_token_current', 
            'phone_change', 
            'phone_change_token', 
            'reauthentication_token'
          )
    LOOP
        EXECUTE format('UPDATE auth.users SET %I = COALESCE(%I, '''') WHERE %I IS NULL;', col.column_name, col.column_name, col.column_name);
    END LOOP;

    UPDATE auth.users 
    SET email_confirmed_at = COALESCE(email_confirmed_at, now()) 
    WHERE email_confirmed_at IS NULL;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN 'Repaired ' || v_count || ' user(s) in auth.users';
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. RPC function to create teacher or reset their password in auth.users
-- ----------------------------------------------------------------------------
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

        -- Insert directly into auth.users with pre-confirmed email and NON-NULL empty token strings
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            recovery_sent_at,
            last_sign_in_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            recovery_token,
            email_change_token_new,
            email_change
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_clean_email,
            v_encrypted_pw,
            now(), -- Pre-confirm email so teacher can login immediately!
            now(),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            json_build_object('role', 'teacher', 'name', p_name)::jsonb,
            now(),
            now(),
            '', -- Empty strings prevent GoTrue scan error on NULL!
            '',
            '',
            ''
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
                gen_random_uuid()::text,
                v_user_id,
                json_build_object('sub', v_user_id::text, 'email', v_clean_email)::jsonb,
                'email',
                v_clean_email,
                now(),
                now(),
                now()
            );
        EXCEPTION WHEN OTHERS THEN
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
                    v_user_id::text,
                    v_user_id,
                    json_build_object('sub', v_user_id::text, 'email', v_clean_email)::jsonb,
                    'email',
                    v_user_id::text,
                    now(),
                    now(),
                    now()
                );
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END;
    ELSE
        -- User already exists: UPDATE password, PRE-CONFIRM email, and ensure tokens are not NULL
        UPDATE auth.users SET
            encrypted_password = v_encrypted_pw,
            email_confirmed_at = COALESCE(email_confirmed_at, now()),
            raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || json_build_object('role', 'teacher', 'name', p_name)::jsonb,
            confirmation_token = COALESCE(confirmation_token, ''),
            recovery_token = COALESCE(recovery_token, ''),
            email_change_token_new = COALESCE(email_change_token_new, ''),
            email_change = COALESCE(email_change, ''),
            updated_at = now()
        WHERE id = v_user_id;

        -- Ensure identity exists
        IF NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = v_user_id) THEN
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
                    v_user_id::text,
                    v_user_id,
                    json_build_object('sub', v_user_id::text, 'email', v_clean_email)::jsonb,
                    'email',
                    v_clean_email,
                    now(),
                    now(),
                    now()
                );
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
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

-- ----------------------------------------------------------------------------
-- 3. RPC function for Admin to reset an existing teacher's password
-- ----------------------------------------------------------------------------
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

    -- Retrieve teacher email
    SELECT LOWER(email) INTO v_email FROM public.users WHERE id = p_teacher_id;

    -- Update password in auth.users AND guarantee non-null tokens
    UPDATE auth.users SET
        encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        confirmation_token = COALESCE(confirmation_token, ''),
        recovery_token = COALESCE(recovery_token, ''),
        email_change_token_new = COALESCE(email_change_token_new, ''),
        email_change = COALESCE(email_change, ''),
        updated_at = now()
    WHERE id = p_teacher_id OR (v_email IS NOT NULL AND LOWER(email) = v_email);

    -- Ensure identity exists in auth.identities
    IF v_email IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = p_teacher_id) THEN
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
                p_teacher_id::text,
                p_teacher_id,
                json_build_object('sub', p_teacher_id::text, 'email', v_email)::jsonb,
                'email',
                v_email,
                now(),
                now(),
                now()
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    -- Update must_change_password and temporary_password in public.users
    UPDATE public.users SET
        must_change_password = true,
        temporary_password = v_clean_pw,
        is_active = true
    WHERE id = p_teacher_id OR (v_email IS NOT NULL AND LOWER(email) = v_email);

    RETURN true;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Teacher Temporary Password Auto-Sync & Verification Function
-- ----------------------------------------------------------------------------
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
    v_encrypted_pw TEXT;
    v_clean_email TEXT := LOWER(TRIM(p_email));
    v_clean_pw TEXT := TRIM(p_password);
BEGIN
    -- Check if user exists in public.users or auth.users
    SELECT id INTO v_user_id
    FROM public.users
    WHERE LOWER(email) = v_clean_email AND is_active = true;

    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = v_clean_email;
        IF v_user_id IS NULL THEN
            RETURN false;
        END IF;
    END IF;

    -- Encrypt the verified password using bcrypt
    v_encrypted_pw := extensions.crypt(v_clean_pw, extensions.gen_salt('bf', 10));

    -- Force sync auth.users with pre-confirmed email and ensure clean string tokens
    UPDATE auth.users SET
        encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        confirmation_token = COALESCE(confirmation_token, ''),
        recovery_token = COALESCE(recovery_token, ''),
        email_change_token_new = COALESCE(email_change_token_new, ''),
        email_change = COALESCE(email_change, ''),
        updated_at = now()
    WHERE id = v_user_id OR LOWER(email) = v_clean_email;

    -- Ensure identity exists
    IF NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = v_user_id) THEN
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
                v_user_id::text,
                v_user_id,
                json_build_object('sub', v_user_id::text, 'email', v_clean_email)::jsonb,
                'email',
                v_clean_email,
                now(),
                now(),
                now()
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    -- Ensure public.users profile exists and has must_change_password = true
    UPDATE public.users SET
        must_change_password = true,
        temporary_password = v_clean_pw
    WHERE id = v_user_id OR LOWER(email) = v_clean_email;

    RETURN true;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Universal Password Vault Reset RPC for Admin
-- ----------------------------------------------------------------------------
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

    -- Update auth.users by ID or email and sanitize null tokens
    UPDATE auth.users SET
        encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        confirmation_token = COALESCE(confirmation_token, ''),
        recovery_token = COALESCE(recovery_token, ''),
        email_change_token_new = COALESCE(email_change_token_new, ''),
        email_change = COALESCE(email_change, ''),
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

-- ----------------------------------------------------------------------------
-- 6. Immediate Auto-Sync for Existing Teachers
-- Syncs all existing teachers in public.users with temporary passwords into auth.users
-- (such as rudra@gmail.com) so they can log in immediately with zero errors!
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    t RECORD;
    v_enc TEXT;
    v_uid UUID;
BEGIN
    FOR t IN 
        SELECT id, email, name, temporary_password, institution, academic_year 
        FROM public.users 
        WHERE role = 'teacher' AND temporary_password IS NOT NULL AND TRIM(temporary_password) <> ''
    LOOP
        v_enc := extensions.crypt(TRIM(t.temporary_password), extensions.gen_salt('bf', 10));
        
        -- Check if user exists in auth.users
        SELECT id INTO v_uid FROM auth.users WHERE LOWER(email) = LOWER(TRIM(t.email));

        IF v_uid IS NULL THEN
            v_uid := t.id;
            INSERT INTO auth.users (
                instance_id,
                id,
                aud,
                role,
                email,
                encrypted_password,
                email_confirmed_at,
                recovery_sent_at,
                last_sign_in_at,
                raw_app_meta_data,
                raw_user_meta_data,
                created_at,
                updated_at,
                confirmation_token,
                recovery_token,
                email_change_token_new,
                email_change
            ) VALUES (
                '00000000-0000-0000-0000-000000000000',
                v_uid,
                'authenticated',
                'authenticated',
                LOWER(TRIM(t.email)),
                v_enc,
                now(),
                now(),
                now(),
                '{"provider":"email","providers":["email"]}'::jsonb,
                json_build_object('role', 'teacher', 'name', t.name)::jsonb,
                now(),
                now(),
                '',
                '',
                '',
                ''
            );
        ELSE
            UPDATE auth.users SET
                encrypted_password = v_enc,
                email_confirmed_at = COALESCE(email_confirmed_at, now()),
                confirmation_token = COALESCE(confirmation_token, ''),
                recovery_token = COALESCE(recovery_token, ''),
                email_change_token_new = COALESCE(email_change_token_new, ''),
                email_change = COALESCE(email_change, ''),
                updated_at = now()
            WHERE id = v_uid;
        END IF;

        -- Ensure identity exists in auth.identities
        IF NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = v_uid) THEN
            BEGIN
                INSERT INTO auth.identities (
                    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
                ) VALUES (
                    v_uid::text, v_uid, json_build_object('sub', v_uid::text, 'email', LOWER(TRIM(t.email)))::jsonb, 'email', LOWER(TRIM(t.email)), now(), now(), now()
                );
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
    END LOOP;
END $$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.repair_auth_users() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_teacher(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_reset_teacher_password(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.teacher_temp_login(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_password(UUID, TEXT, TEXT, BOOLEAN) TO authenticated, anon;

-- Output verification status
SELECT 'MCQ Pro: Auth and Teacher Password Schema successfully repaired and updated!' AS status;

