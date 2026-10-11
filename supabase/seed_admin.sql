-- ============================================================================
-- MCQ Pro: Complete Main Admin Setup & Password Reset Script
-- Version: seed_admin.sql
-- Description: Creates or resets the Main Admin user in Supabase Auth & public.users.
--
-- Instructions:
-- 1. Open your Supabase Project Dashboard -> SQL Editor.
-- 2. Paste this entire script and click "Run".
-- 3. You can change the email and password below if desired.
-- 4. Default Credentials created by this script:
--      Email:    admin@mcqpro.com
--      Password: Admin@1234
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
DECLARE
    v_admin_email    TEXT := 'admin@mcqpro.com';  -- Change email here if desired
    v_admin_password TEXT := 'Admin@1234';        -- Change password here if desired
    v_admin_name     TEXT := 'Main Admin';
    v_user_id        UUID;
    v_encrypted_pw   TEXT;
BEGIN
    -- Encrypt the password using bcrypt
    v_encrypted_pw := crypt(v_admin_password, gen_salt('bf', 10));

    -- Check if user already exists in auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_admin_email;

    IF v_user_id IS NULL THEN
        -- Generate fresh UUID
        v_user_id := gen_random_uuid();

        -- 1. Insert directly into Supabase auth.users with pre-confirmed email
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
            email_change,
            email_change_token_new,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_admin_email,
            v_encrypted_pw,
            now(), -- Email confirmed immediately (no email verification needed!)
            now(),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            json_build_object('role', 'admin', 'name', v_admin_name)::jsonb,
            now(),
            now(),
            '',
            '',
            '',
            ''
        );

        -- 2. Insert into auth.identities if the table is available
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
                json_build_object('sub', v_user_id::text, 'email', v_admin_email)::jsonb,
                'email',
                v_user_id::text,
                now(),
                now(),
                now()
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Skipping auth.identities insert: %', SQLERRM;
        END;

        RAISE NOTICE 'Created new user % in auth.users (ID: %)', v_admin_email, v_user_id;
    ELSE
        -- User exists: reset password, verify email, update metadata
        UPDATE auth.users SET
            encrypted_password = v_encrypted_pw,
            email_confirmed_at = COALESCE(email_confirmed_at, now()),
            raw_user_meta_data = raw_user_meta_data || json_build_object('role', 'admin', 'name', v_admin_name)::jsonb,
            updated_at = now()
        WHERE id = v_user_id;

        RAISE NOTICE 'Updated existing user % password and confirmed email', v_admin_email;
    END IF;

    -- 3. Upsert into public.users with role = 'admin'
    INSERT INTO public.users (
        id,
        email,
        name,
        role,
        is_active,
        must_change_password,
        institution,
        academic_year
    ) VALUES (
        v_user_id,
        v_admin_email,
        v_admin_name,
        'admin',
        true,
        false,
        'Sharda Mandir',
        '2026-2027'
    )
    ON CONFLICT (id) DO UPDATE SET 
        role = 'admin',
        name = EXCLUDED.name,
        email = EXCLUDED.email,
        is_active = true,
        must_change_password = false;

    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'SUCCESS: Main Admin setup complete!';
    RAISE NOTICE 'Email:    %', v_admin_email;
    RAISE NOTICE 'Password: %', v_admin_password;
    RAISE NOTICE 'Role:     admin';
    RAISE NOTICE '=======================================================';
END $$;
